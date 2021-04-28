

get_draw_predictions(b::Gtk.GtkBuilder)=get_gtk_property(b["dl_show_predictions"],:active,Bool)

function draw_predictions(han::Tracker_Handles)
    (preds,confidences) = predict_single_frame(han)
    _draw_predicted_whisker(preds[:,1] ./ 64 .* han.w,preds[:,2] ./ 64 .* han.h,confidences,han.c,han.nn.confidence_thres)
end

function draw_predicted_whisker(han::Tracker_Handles)
    d=han.displayed_frame
    x=han.nn.predicted[:,1,d]; y=han.nn.predicted[:,2,d]; conf=han.nn.predicted[:,3,d]
    _draw_predicted_whisker(x,y,conf,han.c,han.nn.confidence_thres)
end

function _draw_predicted_whisker(x,y,c,canvas,thres)

    circ_rad=5.0

    ctx=Gtk.getgc(canvas)
    num_points = length(x)

    for i=1:num_points
        if c[i] > thres
            Cairo.set_source_rgba(ctx,0,1,0,1-0.025*i)
            Cairo.arc(ctx, x[i],y[i], circ_rad, 0, 2*pi);
            Cairo.stroke(ctx);
        end
    end
    reveal(canvas)
end
#=
function calculate_whisker_fit(pred_1::AbstractArray{T,2},img::AbstractArray{N,2}) where {T,N}

    conf_thres = 0.5

    yscale = size(img,2) / size(pred_1,2)
    xscale = size(img,1) / size(pred_1,1)

    points_1 = findall(pred_1.>conf_thres)
    x = [points_1[i][1] for i=1:length(points_1)] .* xscale
    y = [points_1[i][2] for i=1:length(points_1)] .* yscale
    conf = [pred_1[points_1[i][1],points_1[i][2]] for i=1:length(points_1)]

    calculate_whisker_fit(x,y,conf)
end
=#

function calculate_whisker_fit(pred_1::AbstractArray{T,2},img::AbstractArray{N,2}) where {T,N}

    upsampled = StackedHourglass.upsample_pyramid(pred_1,size(img))

    (x,y,conf) = get_points(upsampled)

    calculate_whisker_fit(x,y,conf)
end

function get_points(input::AbstractArray{T,2},conf_thres=0.5) where T
    input_s = input./maximum(input)
    points_1 = findall(input_s .> conf_thres)
    x = [points_1[i][1] for i=1:length(points_1)]
    y = [points_1[i][2] for i=1:length(points_1)]
    conf = [input_s[points_1[i][1],points_1[i][2]] for i=1:length(points_1)]
    (x,y,conf)
end

function calculate_whisker_fit(x::AbstractArray{T,1},y::AbstractArray{T,1},conf::AbstractArray{N,1}) where {T,N}
    (my_in, rot_mat) = rotate_cov_eigen(x,y)
    (new_x, new_y) = center_of_mass(my_in[:,1],my_in[:,2],conf)
    [new_x new_y] * rot_mat'
end

function center_of_mass(x::AbstractArray{T,1},y::AbstractArray{T,1},conf::AbstractArray{N,1}) where {T,N}
    x_sort=sortperm(x)
    sorted_x=sort(x)
    sorted_y = y[x_sort]
    sorted_conf = conf[x_sort]

    myedges = range(sorted_x[1],stop=sorted_x[end],length=round(Int64,sorted_x[end]-sorted_x[1]))

    out_x = zeros(Float64,length(myedges))
    out_y = zeros(Float64,length(myedges))
    out_weights = zeros(Float64,length(myedges))

    start_ind = 1

    for i=1:(length(myedges)-1)
        a = myedges[i]
        b = myedges[i+1]
       for j=start_ind:length(x)
            this_x = sorted_x[j]
            if (a <= this_x < b)
                out_y[i] = out_y[i] + sorted_y[j] * sorted_conf[j]
                out_weights[i] = out_weights[i] + sorted_conf[j]
            elseif (this_x >= b)
                start_ind = j
                break
            end
        end
    end
    out_x[:] = myedges
    (out_x, out_y ./ out_weights)
end

#=
function calculate_whisker_fit(x::Array{T,1},y::Array{T,1},conf,suppress=true) where T

    quality_flag = true

    (poly,loss) = poly_and_loss(x,y,conf)

    xloss = 100.0

    if (loss>50.0)

        #retry with stricker cutoff
        #(poly,loss) = poly_and_loss(x[],y,conf)

        for rot = [pi/2, pi/4, -pi/4]
            (x_new,y_new) = rotate_mat(x,y,rot)
            (xpoly,xloss) = poly_and_loss(x_new,y_new,conf)

            if xloss < 50.0
                x_order = sortperm(x_new)
                y_out = [xpoly(i) for i in x_new[x_order]]
                x_out = x_new[x_order]

                (x_prime,y_prime) = rotate_mat(x_out,y_out,-1*rot)

                return (y_prime, x_prime,xloss)
            end
        end
        if !suppress
            println("WARNING: Poor Fit")
        end
    end

    x_order=sortperm(x)
    return ([poly(i) for i in x[x_order]],x[x_order],loss)
end
=#
function calculate_whisker_predictions(han::Tracker_Handles,hg)
    pred=StackedHourglass.predict_single_frame(hg,han.current_frame./255)
end

function poly_and_loss(x,y,conf)

    x_order=sortperm(x)
    mypoly=Polynomials.fit(x[x_order],y[x_order],5,weights=conf[x_order])

    loss = sum(abs.([(y[i]-mypoly(x[i]))*conf[i] for i=1:length(x)]))
    (mypoly,loss,x[x_order],[mypoly(i) for i in x[x_order]])
end

function rotate_mat(x,y,theta)
    x_prime = x .* cos(theta) .- y .* sin(theta)
    y_prime = y .* cos(theta) .+ x .* sin(theta)
    (x_prime,y_prime)
end

function poly_loss_rotation(x,y,rot,conf)
    (x_new,y_new) = rotate_mat(x,y,rot)
    (poly,loss) = poly_and_loss(x_new,y_new,conf)
    (x_new, y_new, poly,loss)
end

function draw_prediction2(han::Tracker_Handles,hg,conf)

    colors=((1,0,0),(0,1,0),(0,1,1),(1,0,1))
    pred = calculate_whisker_predictions(han,hg)
    for i = 1:size(pred,3)
        new_xy = calculate_whisker_fit(pred[:,:,i,1],han.current_frame)
        draw_points_2(han,new_xy[:,2],new_xy[:,1],colors[i])
    end

    reveal(han.c)
end

function draw_points_2(han::Tracker_Handles,x::Array{T,1},y::Array{T,1},cc) where T
    ctx=Gtk.getgc(han.c)

    set_source_rgb(ctx,cc...)

    set_line_width(ctx, 1.0);
    for i=1:length(x)
        arc(ctx, x[i],y[i], 1.0, 0, 2*pi);
        stroke(ctx);
    end
end
