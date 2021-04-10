

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

function calculate_whisker_fit(pred_1::Array{T,2},img) where T

    conf_thres = 0.5

    points_1 = findall(pred_1.>conf_thres)
    x = [points_1[i][1] for i=1:length(points_1)]
    y = [points_1[i][2] for i=1:length(points_1)]
    conf = [pred_1[points_1[i][1],points_1[i][2]] for i=1:length(points_1)]
    yscale = size(img,1) / size(pred_1,1)
    xscale = size(img,2) / size(pred_1,2)

    calculate_whisker_fit(x,y,conf,xscale,yscale)
end

function calculate_whisker_fit(x::Array{T,1},y::Array{T,1},conf,xscale,yscale,suppress=true) where T

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

                return (y_prime .* xscale, x_prime .* yscale,xloss)
            end
        end
        if !suppress
            println("WARNING: Poor Fit")
        end
    end

    x_order=sortperm(x)
    return ([poly(i) for i in x[x_order]] * xscale,x[x_order] * yscale,loss)
end

function calculate_whisker_predictions(han,hg)
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

    colors=((1,0,0),(0,1,0),(0,1,1))
    pred = calculate_whisker_predictions(han,hg)
    for i = 1:size(pred,3)
        (x,y,loss) = calculate_whisker_fit(pred[:,:,i,1],han.current_frame)
        draw_points_2(han,x,y,colors[i])
    end

    reveal(han.c)
end

function draw_points_2(han::Tracker_Handles,x::Array{T,1},y::Array{T,1},cc) where T
    ctx=Gtk.getgc(han.c)

    set_source_rgb(ctx,cc...)

    set_line_width(ctx, 1.0);
    for i=1:length(x)
        arc(ctx, x[i],y[i], 5.0, 0, 2*pi);
        stroke(ctx);
    end
end
