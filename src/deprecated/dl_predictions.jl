
#=
Discrete point prediction with subpixel location estimation 
=#

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
