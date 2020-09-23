
function add_deeplearning_callbacks(b::Gtk.GtkBuilder,handles::Tracker_Handles)

    signal_connect(load_weights_cb,b["dl_load_weights"],"clicked",Void,(),false,(handles,))
    signal_connect(load_labels_cb,b["dl_load_labels"],"clicked",Void,(),false,(handles,))
    signal_connect(dl_save_weights_cb,b["dl_save_weights"],"clicked",Void,(),false,(handles,))
    signal_connect(dl_save_labels_cb,b["dl_save_labels"],"clicked",Void,(),false,(handles,))

    signal_connect(create_training_cb,b["dl_create_model_button"],"clicked",Void,(),false,(handles,))

    signal_connect(training_button_cb,b["dl_train_button"],"clicked",Void,(),false,(handles,))
    signal_connect(epochs_sb_cb,b["dl_epoch_button"],"value-changed",Void,(),false,(handles,))
    signal_connect(confidence_sb_cb,b["dl_confidence_sb"],"value-changed",Void,(),false,(handles,))

    signal_connect(predict_frames_cb,b["dl_predict_button"],"clicked",Void,(),false,(handles,))

    signal_connect(create_config_cb,b["dl_export_training"],"clicked",Void,(),false,(handles,true))

    nothing
end

function load_weights_cb(w::Ptr,user_data::Tuple{Tracker_Handles})

    han, = user_data

    config_path = open_dialog("Load Previous Weights",han.b["win"])

    if config_path != ""

        try
            load_hourglass_to_nn(han.nn,config_path)
            setproperty!(han.b["dl_weights_label"],:label,config_path)
        catch
            println("Could not load weights")
        end
    end

    nothing
end

function load_hourglass_to_nn(nn,config_path)
    nn.weight_path = config_path
    hg=HG2(64,1,4); #Dummy Numbers
    load_hourglass(nn.weight_path,hg)
    nn.hg = hg
    nn.use_existing_weights = true
    nn.features=features(hg)

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

function dl_save_labels_cb(w::Ptr,user_data::Tuple{Tracker_Handles})

    han, = user_data

    save_path = save_dialog("Save Labels",han.b["win"])

    if save_path != ""
        save_training(han,save_path)
    end

end

function create_training_cb(w::Ptr,user_data::Tuple{Tracker_Handles})

    han, = user_data

    try
        if !han.nn.use_existing_labels
            set_up_training(han) #heatmaps, labels, normalize, augment
            save_training(han)
            han.nn.use_existing_labels=true
        else
            set_up_training(han,false)
            save_training(han)
        end

        if !han.nn.use_existing_weights
            create_new_weights(han.nn)
        end

        set_gtk_property!(han.b["create_model_label"],:label,string("model created at ", Dates.Time(Dates.now())))
    catch
        println("Could not create new training model")
    end

    nothing
end

function create_new_weights(nn)
    hg=HG2(size(nn.labels,1),size(nn.labels,3),4);
    load_hourglass(nn.weight_path,hg)
    change_hourglass(hg,size(nn.labels,1),1,size(nn.labels,3))
    nn.features=features(hg)
    nn.hg = hg
    nn.use_existing_weights=true
    nothing
end

function save_training(han,mypath=string(han.paths.backup,"/labels.jld"))
    save_training(mypath,han.frame_list,han.woi,han.nn)
end

function save_training(mypath,frame_list,woi,nn)

    file = jldopen(mypath, "w")
    write(file, "frame_list",frame_list)
    write(file, "woi",woi)
    write(file, "mean_img",nn.norm.mean_img)
    write(file, "std_img",nn.norm.std_img)

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

    #Check if the number of features in your training data set matches your number of features
    #in the model. If they do not, remove the features at the end of the loaded model,
    #and replace with blanks
    if size(han.nn.labels,3) != features(han.nn.hg)
        change_hourglass_output(han.nn.hg,size(han.nn.labels,1),size(han.nn.labels,3))
        han.nn.features = features(han.nn.hg)
    end

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

    kernel_pad = create_padded_kernel(size(nn.labels,1),size(nn.labels,2),1)
    k_fft = fft(kernel_pad)

    if prog_bar != nothing
        set_gtk_property!(prog_bar,:fraction,0.0)
    end
    WhiskerTracking.set_testing(nn.hg,false)

    frame_num = 1

    while (frame_num < div(total_frames,loading_size)*loading_size)

        @ffmpeg_env run(WhiskerTracking.ffmpeg_cmd(frame_num/fps,vid_name,loading_size,"test5.yuv"))
        read!("test5.yuv",temp_frames)

        temp_frames_cu[:]=convert(CuArray,temp_frames)
        CUDA_preprocess(temp_frames_cu,input_images_cu_r)
        CUDA_normalize_images(input_images_cu_r,k_mean)

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

        calculate_subpixel(preds,frame_num-1,input_fft,k_fft)

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

    WhiskerTracking.set_testing(nn.hg,true)

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

    @ffmpeg_env run(WhiskerTracking.ffmpeg_cmd(0,vid_name,loading_size,"test5.yuv"))
    read!("test5.yuv",temp_frames)

    temp_frames2[:]=convert(KnetArray{Float32,3},temp_frames)
    running_mean_i[:,:,1] = mean(temp_frames2,dims=3) ./ max_intensity

    for i=1:load_number
        @ffmpeg_env run(WhiskerTracking.ffmpeg_cmd(i*loading_size / 25,vid_name,loading_size,"test5.yuv"))
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
    set_up_training(han.nn,han.wt.vid_name,han.max_frames,han.woi,han.wt.pad_pos,han.frame_list,get_mean)
end

function set_up_training(nn,vid_name,max_frames,woi,pad_pos,frame_list,get_mean=true)

    if get_mean
        (mean_img,std_img)=mean_std_video_gpu(vid_name,max_frames)
        nn.norm.min_ref = 0
        nn.norm.max_ref = 255
        nn.norm.mean_img = mean_img
        nn.norm.std_img = std_img

        #Rotate and Reshape to 256 256
        nn.norm.mean_img = reshape(imresize(nn.norm.mean_img[:,:,1]',(256,256)),(256,256,1))
    end

    WT_reorder_whisker(woi,pad_pos)

    nn.labels=make_heatmap_labels(woi,pad_pos)
    nn.imgs=get_labeled_frames(vid_name,frame_list);

    #Normalize
    nn.imgs=normalize_new_images(nn.imgs,nn.norm.mean_img);

    (nn.imgs,nn.labels)=augment_images(nn.imgs,nn.labels);
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

function run_training_no_gui(hg,trn::Knet.Data,this_opt,epochs=100,ls=Array{Float64,1}())

    total_length=length(trn) * epochs
    minimizer = Knet.minimize(hg,ncycle(trn,epochs),this_opt)

    for x in takenth(minimizer,1)
        push!(ls,x)
        sleep(0.0001)
    end

    ls
end

function predict_single_frame(han)

    k_mean = han.nn.norm.mean_img

    temp_frame = temp_frame = convert(Array{Float32,2},han.current_frame)
    temp_frame = imresize(temp_frame,(256,256))

    temp_frame = WhiskerTracking.normalize_new_images(temp_frame,k_mean)

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

    kernel_pad = create_padded_kernel(size(myout,1),size(myout,2),1)

    k_fft = fft(kernel_pad)
    input=fft(convert(Array,myout),(1:2))

    for i=1:size(myout,3)
        preds[:,i]=subpixel(input[:,:,i,1],k_fft,4) .+ 32.0
    end

    (preds', confidences)
end

function draw_predictions(han)
    h = 480
    w = 640
    (preds,confidences) = predict_single_frame(han)
    _draw_predicted_whisker(preds[:,1] ./ 64 .* w,preds[:,2] ./ 64 .* h,confidences,han.c,han.nn.confidence_thres)
end

function draw_predicted_whisker(han)
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

function create_config_cb(w::Ptr,user_data::Tuple{Tracker_Handles,Bool})

    han, training = user_data

    create_config(han,training)

    nothing
end

function training_from_config(filepath)

    (vid_name,frame_list,woi,pad_pos,training_path,epochs,data_path,nn,max_frames) = load_config(filepath)

    set_up_training(nn,vid_name,max_frames,woi,pad_pos,frame_list) #heatmaps, labels, normalize, augment
    save_training(training_path,frame_list,woi,nn)

    if !nn.use_existing_weights
        create_new_weights(han.nn)
    end

    if size(nn.labels,3) != features(nn.hg)
        change_hourglass_output(nn.hg,size(nn.labels,1),size(nn.labels,3))
        nn.features = features(nn.hg)
    end

    dtrn=make_training_batch(nn.imgs,nn.labels);

    myadam=Adam(lr=1e-3)
    run_training_no_gui(nn.hg,dtrn,myadam,nn.epochs,nn.losses)

    save_hourglass(string(data_path,"/weights.jld"),nn.hg)

end

function create_config(han::Tracker_Handles,training::Bool)

    filepath=string(han.wt.data_path,"/predict_config.jld")
    file=jldopen(filepath,"w")

    write(file,"Video_Name",han.wt.vid_name)
    write(file,"Tracking_Frames",han.frame_list)
    write(file, "WOI",han.woi)
    write(file,"Pad_Pos",han.wt.pad_pos)
    write(file,"Training_Path",string(han.wt.data_path,"/labels.jld"))
    write(file,"Data_Path",string(han.wt.data_path))
    write(file,"Epochs",han.nn.epochs)
    write(file,"Training",training)

    close(file)

    nothing
end

function read_training_config(filepath)
    file=jldopen(filepath,"r")
    training = read(file,"Training")
    close(file)
    training
end

function load_config(filepath)

    file=jldopen(filepath,"r")
    vid_name = read(file,"Video_Name")
    frame_list = read(file,"Tracking_Frames")
    woi=read(file,"WOI")
    pad_pos=read(file,"Pad_Pos")
    training_path=read(file,"Training_Path")
    epochs=read(file,"Epochs")
    data_path=read(file,"Data_Path")
    close(file)

    nn=NeuralNetwork()
    nn.epochs=epochs
    max_frames = get_max_frames(vid_name)

    (vid_name,frame_list,woi,pad_pos,training_path,epochs,data_path,nn,max_frames)
end

function prediction_from_config(filepath)

    (vid_name,frame_list,woi,pad_pos,training_path,epochs,data_path,nn,max_frames) = load_config(filepath)

    config_path = string(data_path,"/weights.jld")
    load_hourglass_to_nn(nn,config_path)

    set_up_training(nn,vid_name,max_frames,woi,pad_pos,frame_list) #heatmaps, labels, normalize, augment
    save_training(training_path,frame_list,woi,nn)

    nn.predicted = ncalculate_whiskers(nn,vid_name,total_frames)

    #Save?
end
