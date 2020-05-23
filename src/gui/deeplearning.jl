
function add_deeplearning_callbacks(b::Gtk.GtkBuilder,handles::Tracker_Handles)

    signal_connect(load_weights_cb,b["dl_load_weights"],"clicked",Void,(),false,(handles,))
    signal_connect(load_labels_cb,b["dl_load_labels"],"clicked",Void,(),false,(handles,))
    signal_connect(dl_save_weights_cb,b["dl_save_weights"],"clicked",Void,(),false,(handles,))

    signal_connect(create_training_cb,b["dl_create_model_button"],"clicked",Void,(),false,(handles,))

    signal_connect(training_button_cb,b["dl_train_button"],"clicked",Void,(),false,(handles,))
    signal_connect(epochs_sb_cb,b["dl_epoch_button"],"value-changed",Void,(),false,(handles,))
    signal_connect(confidence_sb_cb,b["dl_confidence_sb"],"value-changed",Void,(),false,(handles,))

    signal_connect(predict_frames_cb,b["dl_predict_button"],"clicked",Void,(),false,(handles,))

    nothing
end

function load_weights_cb(w::Ptr,user_data::Tuple{Tracker_Handles})

    han, = user_data

    config_path = open_dialog("Load Previous Weights",han.b["win"])

    if config_path != ""

        try
            han.nn.weight_path = config_path
            hg=HG2(64,1,4); #Dummy Numbers
            load_hourglass(han.nn.weight_path,hg)
            han.nn.hg = hg
            setproperty!(han.b["dl_weights_label"],:label,config_path)
            han.nn.use_existing_weights = true
            han.nn.features=features(hg)
        catch
            println("Could not load weights")
        end
    end

    nothing
end

function load_labels_cb(w::Ptr,user_data::Tuple{Tracker_Handles})

    han, = user_data

    config_path = open_dialog("Load Previous Labels",han.b["win"])

    if config_path != ""

        try
            load_training(han,config_path)
            setproperty!(han.b["dl_labels_label"],:label,config_path)
            han.nn.use_existing_labels = true
        catch
            println("Could not load labeled data")
        end

        println("Previous Session Loaded")
    end

    nothing
end

function create_training_cb(w::Ptr,user_data::Tuple{Tracker_Handles})

    han, = user_data

    if !han.nn.use_existing_labels
        set_up_training(han) #heatmaps, labels, normalize, augment
        save_training(han)
        han.nn.use_existing_labels=true
    else
        set_up_training(han,false)
        save_training(han)
    end

    if !han.nn.use_existing_weights
        hg=HG2(size(han.nn.labels,1),size(han.nn.labels,3),4);
        load_hourglass(han.nn.weight_path,hg)
        change_hourglass(hg,size(han.nn.labels,1),1,size(han.nn.labels,3))
        han.nn.features=features(hg)
        han.nn.hg = hg
        han.nn.use_existing_weights=true
    end

    set_gtk_property!(han.b["create_model_label"],:label,string("model created at ", Dates.Time(Dates.now())))

    nothing
end

function save_training(han)

    file = jldopen(string(han.paths.backup,"/labels.jld"), "w")
    write(file, "frame_list",han.frame_list)
    write(file, "woi",han.woi)
    write(file, "mean_img",han.nn.norm.mean_img)
    write(file, "std_img",han.nn.norm.std_img)

    close(file)

    nothing
end

function load_training(han,path)

    file = jldopen(path, "r")
    han.frame_list = read(file, "frame_list")
    han.woi = read(file, "woi")
    han.nn.norm.mean_img = read(file, "mean_img")
    han.nn.norm.std_img = read(file, "std_img")

    set_gtk_property!(han.b["labeled_frame_adj"],:upper,length(han.frame_list))
    han.tracked=trues(length(han.frame_list))

    han.pole_present=falses(length(han.frame_list))
    han.pole_loc=zeros(Float32,length(han.frame_list),2)

    close(file)

end

function training_button_cb(w::Ptr,user_data::Tuple{Tracker_Handles})

    han, = user_data

    dtrn=make_training_batch(han.nn.imgs,han.nn.labels);

    myadam=Adam(lr=1e-3)
    @async begin
        run_training(han.nn.hg,dtrn,myadam,han.b["dl_prog"],han.nn.epochs,han.nn.losses)
    end
    #save_hourglass(string(han.paths.backup,"weights.jld"),han.nn.hg)

    nothing
end

function epochs_sb_cb(w::Ptr,user_data::Tuple{Tracker_Handles})

    han, = user_data

    han.nn.epochs=getproperty(han.b["dl_epochs_adjustment"],:value,Int)

    nothing
end

function confidence_sb_cb(w::Ptr,user_data::Tuple{Tracker_Handles})

    han, = user_data

    han.nn.confidence_thres=getproperty(han.b["dl_confidence_adjustment"],:value,Float64)

    nothing
end

get_draw_predictions(b)=get_gtk_property(b["dl_show_predictions"],:active,Bool)

function dl_save_weights_cb(w::Ptr,user_data::Tuple{Tracker_Handles})

    han, = user_data

    save_path = save_dialog("Save Weights",han.b["win"])

    if save_path != ""
        save_hourglass(save_path,han.nn.hg)
    end

    nothing
end

function predict_frames_cb(w::Ptr,user_data::Tuple{Tracker_Handles})

    han, = user_data

    @async begin
        han.nn.predicted=calculate_whiskers(han)
    end

    nothing
end

function calculate_whiskers(han,total_frames=han.max_frames,batch_size=4,loading_size=128)

    @assert rem(loading_size,batch_size) == 0

    w=size(han.nn.imgs,1)
    h=size(han.nn.imgs,2)

    batch_per_load = div(loading_size,batch_size)

    k_mean = convert(CuArray,han.nn.norm.mean_img)

    temp_frames=zeros(UInt8,640,480,1,loading_size)
    temp_frames_p=zeros(UInt8,480,640,1,loading_size)
    temp_frames2_f = zeros(Float32,480,640,1,loading_size)

    input_images_cu = convert(CuArray,zeros(Float32,480,640,1,loading_size))
    input_images_cu_r = convert(CuArray,zeros(Float32,w,h,1,loading_size))

    sub_input_images=convert(KnetArray{Float32,4},zeros(Float32,w,h,1,batch_size))

    input_f=convert(KnetArray{Float32,4},zeros(Float32,64,64,han.nn.features,loading_size))
    input=zeros(Float32,64,64,han.nn.features,loading_size)
    input_fft=zeros(Complex{Float32},64,64,han.nn.features,loading_size)
    input_fft=convert(SharedArray,input_fft)

    preds=zeros(Float32,han.nn.features,3,total_frames)
    preds=convert(SharedArray,preds)

    kernel_pad = WhiskerTracking.create_padded_kernel(size(han.nn.labels,1),size(han.nn.labels,2),1)
    k_fft = fft(kernel_pad)

    set_gtk_property!(han.b["dl_predict_prog"],:fraction,0.0)
    WhiskerTracking.set_testing(han.nn.hg,false)

    frame_num = 1

    while (frame_num < div(total_frames,loading_size)*loading_size)

        run(WhiskerTracking.ffmpeg_cmd(frame_num/25,han.wt.vid_name,loading_size,"test5.yuv"))
        read!("test5.yuv",temp_frames)
        permutedims!(temp_frames_p,temp_frames,[2,1,3,4])
        @inbounds for i=1:length(temp_frames_p)
            temp_frames2_f[i] = temp_frames_p[i] ./ 1.0f0
        end
        input_images_cu[:] = convert(CuArray{Float32,4},temp_frames2_f)
        CUDA_resize4(input_images_cu,input_images_cu_r)

        CUDA_normalize_images(input_images_cu_r,k_mean)

        input_images = convert(KnetArray,input_images_cu_r)
        for k=0:(batch_per_load-1)

            copyto!(sub_input_images,1,input_images,k*w*h*batch_size+1,w*h*batch_size)
            myout=han.nn.hg(sub_input_images)
            copyto!(input_f,k*64*64*han.nn.features*batch_size+1,myout[4],1,length(myout[4]))
            for kk=1:length(myout)
                Knet.freeKnetPtr(myout[kk].ptr)
            end
        end
        Knet.freeKnetPtr(input_images.ptr)

        input[:]=convert(Array,input_f)
        @inbounds for i=1:length(input)
            input_fft[i] = convert(Complex{Float32},input[i])
        end
        fft!(input_fft,(1,2))

        hi=argmax(input,dims=(1,2))
        for jj=1:size(hi,4)
            for kk=1:size(hi,3)
                preds[kk,3,jj + frame_num-1] = input[hi[1,1,kk,jj][1],hi[1,1,kk,jj][2],kk,jj]
            end
        end

        calculate_subpixel(preds,frame_num-1,input_fft,k_fft)

        frame_num += loading_size
        set_gtk_property!(han.b["dl_predict_prog"],:fraction,frame_num/total_frames)
        sleep(0.0001)
        Knet.gc()
    end

    preds[:,1,:] = preds[:,1,:] ./ 64 .* 640
    preds[:,2,:] = preds[:,2,:] ./ 64 .* 480

    set_gtk_property!(han.b["dl_predict_prog"],:fraction,1.0)

    WhiskerTracking.set_testing(han.nn.hg,true)

    convert(Array,preds)
end

function mean_std_video_gpu(han::Tracker_Handles,total_frame_num)
    mean_std_video_gpu(han.wt.vid_name,total_frame_num)
end

function mean_std_video_gpu(vid_name::String,total_frame_num,w=640,h=480,max_intensity=255,loading_size=500)
    load_number = div(total_frame_num, loading_size)-1

    temp_frames=zeros(UInt8,w,h,loading_size)

    temp_frames2 = convert(KnetArray,zeros(Float32,w,h,loading_size))

    running_mean = convert(KnetArray,zeros(Float32,w,h,1))
    running_mean_i = convert(KnetArray,zeros(Float32,w,h,1))

    running_std = convert(KnetArray,zeros(Float32,w,h,1))
    running_std_i = convert(KnetArray,zeros(Float32,w,h,1))

    run(WhiskerTracking.ffmpeg_cmd(0,vid_name,loading_size,"test5.yuv"))
    read!("test5.yuv",temp_frames)

    temp_frames2[:]=convert(KnetArray{Float32,3},temp_frames)
    running_mean_i[:,:,1] = mean(temp_frames2,dims=3) ./ max_intensity

    for i=1:load_number
        run(WhiskerTracking.ffmpeg_cmd(i*loading_size / 25,vid_name,loading_size,"test5.yuv"))
        read!("test5.yuv",temp_frames)
        temp_frames2[:]=convert(KnetArray{Float32,3},temp_frames)

        x_k = mean(temp_frames2,dims=3) ./ max_intensity

        running_mean = running_mean_i .+ (x_k .- running_mean_i) ./ (i+1)

        running_std = running_std_i .+ (x_k .- running_mean_i).*(x_k - running_mean)

        running_mean_i = running_mean
        running_std_i = running_std
    end

    rm("test5.yuv")

    (convert(Array,running_mean), convert(Array,running_std))
end

function set_up_training(han,get_mean=true)

    if get_mean
        (mean_img,std_img)=mean_std_video_gpu(han,han.max_frames)
        han.nn.norm.min_ref = 0
        han.nn.norm.max_ref = 255
        han.nn.norm.mean_img = mean_img
        han.nn.norm.std_img = std_img

        #Rotate and Reshape to 256 256
        han.nn.norm.mean_img = reshape(imresize(han.nn.norm.mean_img[:,:,1]',(256,256)),(256,256,1))
    end

    han.nn.labels=make_heatmap_labels(han)
    han.nn.imgs=get_labeled_frames(han);

    #Normalize
    han.nn.imgs=normalize_new_images(han.nn.imgs,han.nn.norm.mean_img);

    (han.nn.imgs,han.nn.labels)=WhiskerTracking.augment_images(han.nn.imgs,han.nn.labels);
end

function make_training_batch(img,ll,batch_size=8)
    dtrn=minibatch(img,ll,batch_size,xtype=KnetArray,ytype=KnetArray)
end

function run_training(hg,trn::Knet.Data,this_opt,p,epochs=100,ls=Array{Float64,1}())

    total_length=length(trn) * epochs
    minimizer = Knet.minimize(hg,ncycle(trn,epochs),this_opt)
    last_update = 0.0
    count=0
    Gtk.set_gtk_property!(p, :fraction, 0)
    sleep(0.0001)

        for x in takenth(minimizer,1)
            push!(ls,x)
            count+=1
            complete=round(count/total_length,digits=2)
            if complete > last_update
                Gtk.set_gtk_property!(p, :fraction, complete)
                last_update = complete
                reveal(p,true)
            end
            sleep(0.0001)
        end

    ls
end

function predict_single_frame(han)

    k_mean = convert(KnetArray,han.nn.norm.mean_img)
    k_std = convert(KnetArray,han.nn.norm.std_img)
    temp_frame = convert(KnetArray{Float32,4},reshape(han.current_frame,(size(han.current_frame,1),size(han.current_frame,2),1,1)))
    temp_frame = my_imresize(temp_frame,256,256)

    temp_frame = normalize_new_images(temp_frame,k_mean)

    set_testing(han.nn.hg,false) #Turn off batch normalization for prediction
    myout=han.nn.hg(temp_frame)[4]
    set_testing(han.nn.hg,true) #Turn back on

    hi=argmax(myout,dims=(1,2))
    preds=zeros(Float32,2,han.nn.features)
    confidences=zeros(Float32,han.nn.features)

    for kk=1:size(hi,3)
        confidences[kk] = myout[hi[1,1,kk,1][1],hi[1,1,kk,1][2],kk,1]
    end

    kernel_pad = create_padded_kernel(size(myout,1),size(myout,2),1)

    k_fft = fft(kernel_pad)
    input=fft(convert(Array,myout),(1:2))

    for i=1:size(myout,3)

        preds[:,i]=subpixel(input[:,:,i,1],k_fft,4) .+ 32.0
    end

    (preds', confidences)
end

function draw_predictions(han)

    (preds,confidences) = predict_single_frame(han)

    circ_rad=5.0

    ctx=Gtk.getgc(han.c)
    Cairo.set_source_rgb(ctx,0,1,0)
    num_points = size(preds,1)

    for i=1:num_points
        if confidences[i] > han.nn.confidence_thres
            Cairo.arc(ctx, preds[i,1] / 64 * 640,preds[i,2] / 64 * 480, circ_rad, 0, 2*pi);
            Cairo.stroke(ctx);
        end
    end
    reveal(han.c)
end

function draw_predicted_whisker(han)

    circ_rad=5.0

    ctx=Gtk.getgc(han.c)
    Cairo.set_source_rgb(ctx,0,1,0)
    num_points = size(han.nn.predicted,1)

    d=han.displayed_frame
    for i=1:num_points
        if han.nn.predicted[i,3,d] > han.nn.confidence_thres
            Cairo.arc(ctx, han.nn.predicted[i,1,d],han.nn.predicted[i,2,d], circ_rad, 0, 2*pi);
            Cairo.stroke(ctx);
        end
    end
    reveal(han.c)
end
