
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
        if (!han.nn.use_existing_labels)|(han.nn.norm.mean_img == zeros(Float32,0,0,0))
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

    try
        dtrn=make_training_batch(han.nn.imgs,han.nn.labels);

        myadam=Adam(lr=1e-3)
        @async begin
            run_training(han.nn.hg,dtrn,myadam,han.b["dl_prog"],han.nn.epochs,han.nn.losses)
        end

    catch

        println("Failed to start training. Will use half the batch size and try again")
        dtrn=make_training_batch(han.nn.imgs,han.nn.labels,4);

        myadam=Adam(lr=1e-3)
        @async begin
            run_training(han.nn.hg,dtrn,myadam,han.b["dl_prog"],han.nn.epochs,han.nn.losses)
        end
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

function create_config_cb(w::Ptr,user_data::Tuple{Tracker_Handles,Bool})

    han, training = user_data

    create_config(han,training)

    nothing
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

function get_labeled_frames(han::Tracker_Handles,out_hw=256)
    get_labeled_frames(han.wt.vid_name,han.frame_list,out_hw=256)
end

function make_heatmap_labels(han::Tracker_Handles,real_w=640,real_h=480,label_img_size=64)
    make_heatmap_labels(han.woi,han.wt.pad_pos,real_w,real_h,label_img_size)
end

function draw_prediction2(han::Tracker_Handles,hg::StackedHourglass.NN,conf)

    colors=((1,0,0),(0,1,0),(0,1,1),(1,0,1))
    atype = []
    if CUDA.has_cuda_gpu()
        atype = KnetArray
    else
        atype = Array
    end
    pred = calculate_whisker_predictions(han,hg,atype)
    for i = 1:size(pred,3)
        (x,y) = calculate_whisker_fit(pred[:,:,i,1],han.current_frame)
        draw_points_2(han,y,x,colors[i])

        if (han.show_contact) & (i == han.class.w_id)
            draw_touch_prediction(han,y,x)
        end
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

function calculate_whisker_predictions(han::Tracker_Handles,hg::StackedHourglass.NN,atype=KnetArray)

    output = han.current_frame ./ 255

    if han.nn.flip_x
        reverse!(output,dims=1)
    end
    if han.nn.flip_y
        reverse!(output,dims=2)
    end

    pred=StackedHourglass.predict_single_frame(hg,output,atype)

    if han.nn.flip_x
        reverse!(pred,dims=1)
    end
    if han.nn.flip_y
        reverse!(pred,dims=2)
    end
    pred
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

function save_training(han,mypath=string(han.paths.backup,"/labels.jld"))
    save_training(mypath,han.frame_list,han.woi,han.nn)

end

function load_training(han::Tracker_Handles,path::String)

    file = jldopen(path, "r")
    frame_list = read(file, "frame_list")
    woi = read(file, "woi")
    if typeof(woi) <: Array
        for i=1:length(frame_list)
            han.woi[frame_list[i]]=woi[i]
        end
    else # New Version
        han.woi = woi
    end

    han.frame_list = frame_list
    set_gtk_property!(han.b["labeled_frame_adj"],:upper,length(han.frame_list))

    tracked = [true for i=1:length(han.frame_list)]
    han.tracked = Dict{Int64,Bool}(zip(frame_list,tracked))

    pole_present = [false for i=1:length(han.frame_list)]
    han.pole_present=Dict{Int64,Bool}(zip(frame_list,pole_present))

    pole_loc = [zeros(Float32,2) for i=1:length(han.frame_list)]
    han.pole_loc=Dict{Int64,Array{Float32,1}}(zip(frame_list,pole_loc))

    han.nn.norm.mean_img = read(file, "mean_img")
    han.nn.norm.std_img = read(file, "std_img")

    close(file)

end

function set_up_training(han::Tracker_Handles,get_mean=true)
    woi=get_woi_array(han)
    set_up_training(han,han.nn,han.wt.vid_name,han.end_frame,woi,han.wt.pad_pos,han.frame_list,get_mean)
end

function set_up_training(han,nn,vid_name,max_frames,woi,pad_pos,frame_list,get_mean=false)

    (w,h,fps)=get_vid_dims(vid_name)

    #=
    if get_mean
        (mean_img,std_img)=mean_std_video_gpu(vid_name,max_frames)
        nn.norm.min_ref = 0
        nn.norm.max_ref = 255
        nn.norm.mean_img = mean_img
        nn.norm.std_img = std_img

        #Rotate and Reshape to 256 256
        nn.norm.mean_img = reshape(imresize(nn.norm.mean_img[:,:,1]',(256,256)),(256,256,1))
    end
    =#

    (new_woi, new_frame_list) = check_whiskers(woi,frame_list,max_frames)

    WT_reorder_whisker(new_woi,pad_pos)

    #nn.labels = make_heatmap_labels(new_woi,pad_pos)
    nn.labels = create_label_images(han)
    nn.imgs = get_labeled_frames(vid_name,new_frame_list);

    #Normalize
    #=
    nn.imgs = StackedHourglass.normalize_new_images(nn.imgs,nn.norm.mean_img);
    =#
    (nn.imgs,nn.labels)=augment_images(nn.imgs,nn.labels);
end