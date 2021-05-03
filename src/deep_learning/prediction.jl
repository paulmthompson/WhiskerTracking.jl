

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

function calculate_whisker_fit(pred_1::AbstractArray{T,2},img::AbstractArray{N,2}) where {T,N}

    calculate_whisker_fit(pred_1,size(img))
end

function calculate_whisker_fit(pred_1::AbstractArray{T,2},sz::Tuple,n_points_max=100) where T
    upsampled = StackedHourglass.upsample_pyramid(pred_1,sz)

    (x,y,conf) = get_points(upsampled)

    calculate_whisker_fit(x,y,conf,n_points_max)
end

function get_points(input::AbstractArray{T,2},conf_thres=0.5) where T
    input_s = input./maximum(input)
    points_1 = findall(input_s .> conf_thres)
    x = [points_1[i][1] for i=1:length(points_1)]
    y = [points_1[i][2] for i=1:length(points_1)]
    conf = [input_s[points_1[i][1],points_1[i][2]] for i=1:length(points_1)]
    (x,y,conf)
end

function calculate_whisker_fit(x::AbstractArray{T,1},y::AbstractArray{T,1},conf::AbstractArray{N,1},
    n_points_max=100) where {T,N}
    (my_in, rot_mat) = rotate_cov_eigen(x,y)
    (new_x, new_y) = center_of_mass(my_in[:,1],my_in[:,2],conf,n_points_max)
    [new_x new_y] * rot_mat'
end

#=

=#
function center_of_mass(x::AbstractArray{T,1},y::AbstractArray{T,1},conf::AbstractArray{N,1},n_points_max=100) where {T,N}
    x_sort=sortperm(x)
    sorted_x=sort(x)
    sorted_y = y[x_sort]
    sorted_conf = conf[x_sort]

    out_length = round(Int64,sorted_x[end] - sorted_x[1])

    if out_length > n_points_max
        out_length = n_points_max
    end

    myedges = range(sorted_x[1],stop=sorted_x[end],length=out_length)

    out_x = zeros(Float64,length(myedges)-1)
    out_y = zeros(Float64,length(myedges)-1)
    out_weights = zeros(Float64,length(myedges)-1)

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
        out_x[i] = (a+b) / 2
    end

    out_y = out_y ./ out_weights

    nan_vals = isnan.(out_x) .| isnan.(out_y)
    deleteat!(out_x,nan_vals)
    deleteat!(out_y,nan_vals)

    (out_x, out_y)
end

function calculate_whisker_predictions(han::Tracker_Handles,hg)
    pred=StackedHourglass.predict_single_frame(hg,han.current_frame./255)
end

function rotate_mat(x,y,theta)
    x_prime = x .* cos(theta) .- y .* sin(theta)
    y_prime = y .* cos(theta) .+ x .* sin(theta)
    (x_prime,y_prime)
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
