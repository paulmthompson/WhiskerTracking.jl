
function _make_dlc_gui()

    dlc_grid=Grid()
    new_frame = Frame("Create New Network")
    dlc_grid[1,1]=new_frame
    new_grid=Grid()

    push!(new_frame,new_grid)

    dlc_create_button=Button("Initialize")
    new_grid[1,1] = dlc_create_button

    dlc_export_button=Button("Export")
    new_grid[1,2] = dlc_export_button

    dlc_with_pole_button=CheckButton("With Pole")
    new_grid[2,2] = dlc_with_pole_button

    create_training_button=Button("Create Training Data")
    new_grid[1,3]=create_training_button

    dlc_train_button=Button("Train")
    new_grid[1,4] = dlc_train_button

    weights_frame = Frame("Starting Network Weights")
    weights_grid=Grid()
    push!(weights_frame,weights_grid)
    new_grid[2,4]=weights_frame

    dlc_weights_label=Label("Default Resnet from DLC")
    weights_grid[1,1]=dlc_weights_label

    update_weights_button = Button("Load")
    weights_grid[2,1] = update_weights_button

    dlc_grid[2,1] = Label("Use labeled data currently in GUI to train a new neural network specifically \n for this dataset")


    analyze_frame = Frame("Analyze Data")
    analyze_grid = Grid()
    push!(analyze_frame,analyze_grid)
    dlc_grid[1,2]=analyze_frame

    select_network_button=Button("Select Network")
    analyze_grid[1,1]=select_network_button

    dlc_analyze_button=Button("Analyze")
    analyze_grid[1,2] = dlc_analyze_button

    dlc_grid[2,2] = Label("Use a neural network to find the whisker of interest in the currently loaded video")

    dlc_win=Window(dlc_grid)
    Gtk.showall(dlc_win)
    visible(dlc_win,false)

    deep_widgets=dlc_widgets(dlc_win,dlc_create_button,dlc_export_button,dlc_with_pole_button,dlc_train_button,dlc_analyze_button,
    dlc_weights_label,update_weights_button,create_training_button,select_network_button)
end

function add_dlc_callbacks(w::dlc_widgets,handles::Tracker_Handles)

    signal_connect(dlc_init_cb,w.create_button,"clicked",Void,(),false,(handles,))
    signal_connect(dlc_export_cb,w.export_button,"clicked",Void,(),false,(handles,))
    signal_connect(dlc_with_pole_cb,w.with_pole_button,"clicked",Void,(),false,(handles,))
    signal_connect(dlc_create_training_cb,w.create_training_button,"clicked",Void,(),false,(handles,))
    signal_connect(dlc_load_weights_cb,w.load_weights_button,"clicked",Void,(),false,(handles,))
    signal_connect(dlc_train_network_cb,w.train_button,"clicked",Void,(),false,(handles,))


    signal_connect(dlc_select_network_cb,w.select_network_button,"clicked",Void,(),false,(handles,))
    signal_connect(dlc_analyze_cb,w.analyze_button,"clicked",Void,(),false,(handles,))


end


function dlc_init_cb(w::Ptr,user_data::Tuple{Tracker_Handles})

    han, = user_data
    my_wd=pwd()
    cd(han.paths.DLC)
    dlc_init(han.dlc,"WT",han.wt.vid_name)
    cd(my_wd)

    nothing
end

function dlc_export_cb(w::Ptr,user_data::Tuple{Tracker_Handles})

    han, = user_data

    my_working=pwd()

    #Copy images to folder
    #list of images
    vid_folder_path=copy_images_to_dlc(han)

    #Modify configuration file with right number of discrete points
    num_segments=div(size(han.wt.w_p,1),2)
    dlc_change_num_segments(han.dlc,num_segments,han.dlc.export_pole)

    #Create h5 label_file
    dlc_create_label_file(han.dlc,vid_folder_path)

    #Put in new data values
    if han.dlc.export_pole
        out_val_x = zeros(Float64,num_segments+1,length(han.frame_list))
        out_val_y = zeros(Float64,num_segments+1,length(han.frame_list))
    else
        out_val_x = zeros(Float64,num_segments,length(han.frame_list))
        out_val_y = zeros(Float64,num_segments,length(han.frame_list))
    end

    ind=1
    for i=1:num_segments
        out_val_x[i,:] = han.wt.w_p[ind,:]
        out_val_y[i,:] = han.wt.w_p[ind+1,:]
        ind+=2
    end

    if han.dlc.export_pole
        out_val_x[end,:] = han.pole_loc[:,1]
        out_val_y[end,:] = han.pole_loc[:,2]
    end

    out_val_x[out_val_x .== 0] .= NaN
    out_val_y[out_val_y .== 0] .= NaN

    dlc_replace_discrete_points(han.dlc,vid_folder_path,num_segments,han.dlc.export_pole,out_val_x,out_val_y)

    nothing
end

function copy_images_to_dlc(han::Tracker_Handles)

    #Copy images to folder
    #list of images
    image_paths=readdir(han.paths.images)

    dlc_path = readdir(han.paths.DLC)[1]
    labeled_data_path=string(han.paths.DLC,"/",dlc_path,"/labeled-data")
    vid_folder_path=string(labeled_data_path,"/",readdir(labeled_data_path)[1])

    for img in image_paths
        cp(string(han.paths.images,"/",img),string(vid_folder_path,"/",img),force=true)
    end

    vid_folder_path
end

function dlc_with_pole_cb(w::Ptr,user_data::Tuple{Tracker_Handles})

    han, = user_data

    han.dlc.export_pole=getproperty(han.dlc_widgets.with_pole_button,:active,Bool)

    nothing
end

function dlc_create_training_cb(w::Ptr,user_data::Tuple{Tracker_Handles})

    han, = user_data

    #Call deeplabcut to create training dataset
    dlc_create_training(han.dlc)

    nothing
end

function dlc_train_network_cb(w::Ptr,user_data::Tuple{Tracker_Handles})

    han, = user_data

    setproperty!(han.dlc_widgets.train_button,:label,"Training Underway...")
    dlc_start_training(han.dlc)
    setproperty!(han.dlc_widgets.train_button,:label,"Train")

    nothing
end

function dlc_select_network_cb(w::Ptr,user_data::Tuple{Tracker_Handles})

    han, = user_data

    #Change the configuration file to use.
    filepath = open_dialog("Load Configuration File",han.win)
    han.dlc.config_path = filepath

    nothing
end

function dlc_analyze_cb(w::Ptr,user_data::Tuple{Tracker_Handles})

    han, = user_data

    setproperty!(han.dlc_widgets.analyze_button,:label,"Analyzing Video...")
    dlc_analyze(han.dlc,han.wt.vid_name)
    setproperty!(han.dlc_widgets.analyze_button,:label,"Analyze")

    nothing
end

function dlc_load_weights_cb(w::Ptr,user_data::Tuple{Tracker_Handles})

    han, = user_data

    filepath = open_dialog("Load Weights",han.win)

    try
        #Remove .index
        filepath = filepath[1:(end-6)]

        setproperty!(han.dlc_widgets.weights_label,:label,filepath[(end-20):end])

        han.dlc.starting_weights = filepath
        model_path=string(han.dlc.config_path[1:(end-11)],"dlc-models")
        iter_path=readdir(model_path)[1]
        training_dir=readdir(string(model_path,"/",iter_path))[1]
        pose_cfg_path=string(model_path,"/",iter_path,"/",training_dir,"/train/pose_cfg.yaml")

        f = open(pose_cfg_path)
        out=readlines(f)
        close(f)

        for i=1:length(out)
            if out[i][1:5] == "init_"
                println(i)
                out[i] = string("init_weights: ",filepath)
            end
        end

        ff=open(pose_cfg_path,"w")
        writedlm(ff,out)
        close(ff)
    catch
        println("Could not update weights")
    end

    nothing
end
