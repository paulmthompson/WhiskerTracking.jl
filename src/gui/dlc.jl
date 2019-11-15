
function _make_dlc_gui()

    dlc_grid=Grid()
    dlc_grid[1,1]=Label("DeepLabCut")

    dlc_create_button=Button("Initialize")
    dlc_grid[1,2] = dlc_create_button

    dlc_export_button=Button("Export")
    dlc_grid[1,3] = dlc_export_button

    dlc_with_pole_button=CheckButton("With Pole")
    dlc_grid[2,3] = dlc_with_pole_button

    dlc_train_button=Button("Train")
    dlc_grid[1,4] = dlc_train_button

    dlc_analyze_button=Button("Analyze")
    dlc_grid[1,5] = dlc_analyze_button

    dlc_win=Window(dlc_grid)
    Gtk.showall(dlc_win)
    visible(dlc_win,false)

    deep_widgets=dlc_widgets(dlc_win,dlc_create_button,dlc_export_button,dlc_with_pole_button,dlc_train_button,dlc_analyze_button)
end

function add_dlc_callbacks(w::dlc_widgets,handles::Tracker_Handles)

    signal_connect(dlc_init_cb,w.create_button,"clicked",Void,(),false,(handles,))
    signal_connect(dlc_export_cb,w.export_button,"clicked",Void,(),false,(handles,))
    signal_connect(dlc_with_pole_cb,w.with_pole_button,"clicked",Void,(),false,(handles,))
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
