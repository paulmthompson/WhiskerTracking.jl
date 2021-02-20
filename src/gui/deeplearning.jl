
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
