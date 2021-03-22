

function calculate_whiskers(han::Tracker_Handles,total_frames=han.max_frames,batch_size=32,loading_size=128)

    calculate_whiskers(han.nn,han.wt.vid_name,total_frames,batch_size,loading_size,prog_bar=han.b["dl_predict_prog"])
end

function calculate_whiskers(nn,vid_name,total_frames,batch_size=32,loading_size=128; prog_bar=nothing)

    vid_w=640
    vid_h=480
    fps=25

    Knet.knetgcinit(Knet._tape)
    Knet.gc()
    @assert rem(loading_size,batch_size) == 0

    w=size(nn.imgs,1)
    h=size(nn.imgs,2)

    batch_per_load = div(loading_size,batch_size)

    k_mean = convert(CuArray,nn.norm.mean_img)

    temp_frames=zeros(UInt8,vid_w,vid_h,1,loading_size)
    temp_frames_cu=convert(CuArray,zeros(UInt8,vid_w,vid_h,1,loading_size))
    input_images_cu_r = convert(CuArray,zeros(Float32,w,h,1,loading_size))

    sub_input_images=convert(KnetArray{Float32,4},zeros(Float32,w,h,1,batch_size))

    input_f=convert(KnetArray{Float32,4},zeros(Float32,64,64,nn.features,loading_size))
    input=zeros(Float32,64,64,nn.features,loading_size)
    input_fft=zeros(Complex{Float32},64,64,nn.features,loading_size)
    input_fft=convert(SharedArray,input_fft)

    input_cu = convert(CuArray,zeros(Float32,64,64,nn.features,loading_size))
    input_cu_com = convert(CuArray,zeros(Complex{Float32},64,64,nn.features,loading_size))

    preds=zeros(Float32,nn.features,3,total_frames)
    preds=convert(SharedArray,preds)

    kernel_pad = StackedHourglass.create_padded_kernel(size(nn.labels,1),size(nn.labels,2),1)
    k_fft = fft(kernel_pad)

    if prog_bar != nothing
        set_gtk_property!(prog_bar,:fraction,0.0)
    end
    set_testing(nn.hg,false)

    frame_num = 1

    while (frame_num < div(total_frames,loading_size)*loading_size)

        @ffmpeg_env run(WhiskerTracking.ffmpeg_cmd(frame_num/fps,vid_name,loading_size,"test5.yuv"))
        read!("test5.yuv",temp_frames)

        temp_frames_cu[:]=convert(CuArray,temp_frames)
        StackedHourglass.CUDA_preprocess(temp_frames_cu,input_images_cu_r)
        StackedHourglass.CUDA_normalize_images(input_images_cu_r,k_mean)

        input_images = convert(KnetArray,input_images_cu_r)

        for k=0:(batch_per_load-1)

            copyto!(sub_input_images,1,input_images,k*w*h*batch_size+1,w*h*batch_size)
            myout=nn.hg(sub_input_images)
            copyto!(input_f,k*64*64*nn.features*batch_size+1,myout[4],1,length(myout[4]))
            for kk=1:length(myout)
                Knet.freeKnetPtr(myout[kk].ptr)
            end
        end
        Knet.freeKnetPtr(input_images.ptr)

        input_cu[:]=(CuArray(input_f))
        input_cu_com[:]=fft(input_cu,(1,2))
        input_fft[:] = convert(Array{Complex{Float32},4},input_cu_com)

        input[:]=convert(Array,input_f)
        hi=argmax(input,dims=(1,2))
        for jj=1:size(hi,4)
            for kk=1:size(hi,3)
                preds[kk,3,jj + frame_num-1] = input[hi[1,1,kk,jj][1],hi[1,1,kk,jj][2],kk,jj]
            end
        end

        StackedHourglass.calculate_subpixel(preds,frame_num-1,input_fft,k_fft)

        if prog_bar != nothing
            set_gtk_property!(prog_bar,:fraction,frame_num/total_frames)
        end
        frame_num += loading_size
        sleep(0.0001)
    end

    preds[:,1,:] = preds[:,1,:] ./ 64 .* vid_w
    preds[:,2,:] = preds[:,2,:] ./ 64 .* vid_h

    if prog_bar != nothing
        set_gtk_property!(prog_bar,:fraction,1.0)
    end

    set_testing(nn.hg,true)

    convert(Array,preds)
end

function predict_single_frame(han::Tracker_Handles)

    k_mean = han.nn.norm.mean_img

    temp_frame = convert(Array{Float32,2},han.current_frame)
    temp_frame = imresize(temp_frame,(256,256))

    temp_frame = StackedHourglass.normalize_new_images(temp_frame,k_mean)

    temp_frame = convert(KnetArray,reshape(temp_frame,(256,256,1,1)))

    set_testing(han.nn.hg,false) #Turn off batch normalization for prediction
    myout=han.nn.hg(temp_frame)[4]
    set_testing(han.nn.hg,true) #Turn back on

    hi=argmax(myout,dims=(1,2))
    preds=zeros(Float32,2,han.nn.features)
    confidences=zeros(Float32,han.nn.features)

    for kk=1:size(hi,3)
        confidences[kk] = myout[hi[1,1,kk,1][1],hi[1,1,kk,1][2],kk,1]
    end

    kernel_pad = StackedHourglass.create_padded_kernel(size(myout,1),size(myout,2),1)

    k_fft = fft(kernel_pad)
    input=fft(convert(Array,myout),(1:2))

    for i=1:size(myout,3)
        preds[:,i]=StackedHourglass.subpixel(input[:,:,i,1],k_fft,4) .+ 32.0
    end

    (preds', confidences)
end

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

    points_1 = findall(pred_1.>0.5)
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

function draw_prediction2(han,hg,conf)

    colors=((1,0,0),(0,1,0))
    pred = calculate_whisker_predictions(han,hg)
    for i = 1:size(pred,3)
        (x,y,loss) = calculate_whisker_fit(pred[:,:,i,1],han.current_frame)
        draw_points_2(han,x,y,colors[i])
    end

    reveal(han.c)
end

function draw_points_2(han,x,y,cc)
    ctx=Gtk.getgc(han.c)

    set_source_rgb(ctx,cc...)

    set_line_width(ctx, 1.0);
    for i=1:length(x)
        arc(ctx, x[i],y[i], 5.0, 0, 2*pi);
        stroke(ctx);
    end
end
