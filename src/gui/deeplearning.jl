
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

function training_button_cb(w::Ptr,user_data::Tuple{Tracker_Handles})

    han, = user_data

    check_hg_features(han.nn)

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

function mean_std_video_gpu(han::Tracker_Handles,total_frame_num)
    mean_std_video_gpu(han.wt.vid_name,total_frame_num)
end

function mean_std_video_gpu(vid_name::String,total_frame_num,max_intensity=255,loading_size=500)

    (w,h,fps)=get_vid_dims(vid_name)
    start_frame = 0

    load_number = div(total_frame_num - start_frame, loading_size)-1

    temp_frames=zeros(UInt8,w,h,loading_size)

    temp_frames2 = convert(KnetArray,zeros(Float32,w,h,loading_size))

    running_mean = convert(KnetArray,zeros(Float32,w,h,1))
    running_mean_i = convert(KnetArray,zeros(Float32,w,h,1))

    running_std = convert(KnetArray,zeros(Float32,w,h,1))
    running_std_i = convert(KnetArray,zeros(Float32,w,h,1))

    @ffmpeg_env run(WhiskerTracking.ffmpeg_cmd(start_frame / fps,vid_name,loading_size,"test5.yuv"))
    read!("test5.yuv",temp_frames)

    temp_frames2[:]=convert(KnetArray{Float32,3},temp_frames)
    running_mean_i[:,:,1] = mean(temp_frames2,dims=3) ./ max_intensity

    for i=1:load_number
        @ffmpeg_env run(WhiskerTracking.ffmpeg_cmd((i*loading_size + start_frame)/ fps,vid_name,loading_size,"test5.yuv"))
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

function create_config_cb(w::Ptr,user_data::Tuple{Tracker_Handles,Bool})

    han, training = user_data

    create_config(han,training)

    nothing
end
