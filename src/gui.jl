
export make_gui

function make_gui(path,vid_title;frame_range = (false,0.0,0),image_stack=false,dynamic_load=true)
    make_gui(path,vid_title,""; frame_range = frame_range, image_stack=image_stack, dynamic_load=dynamic_load)
end

function make_gui(path,vid_title,name; frame_range = (false,0.0,0),image_stack=false,dynamic_load=true)

    vid_name = string(path,vid_title)
    whisk_path = string(path,name,".whiskers")
    meas_path = string(path,name,".measurements")

    if (dynamic_load)
        #load first frame
        vid=zeros(UInt8,480,640,1)
        temp=zeros(UInt8,640,480)
        frame_time = 1  /  25 #Number of frames in a second of video
        try
            load_single_frame(frame_time,temp,vid_name)
            vid[:,:,1] = temp'
        catch
        end
        vid_length = 1
        frame_list=[1]
        start_frame=1
    else
        if !image_stack
            (vid,start_frame,vid_length)=load_video(vid_name,frame_range)
            frame_list=Array{Int64,1}()
        else
            (vid,start_frame,vid_length,frame_list)=load_image_stack(string(path,name))
        end
    end

    yy=read(`$(ffprobe_path) -v error -select_streams v:0 -show_entries stream=nb_frames -of default=nokey=1:noprint_wrappers=1 $(vid_name)`)
    if is_windows()
        max_frames=parse(Int64,String(yy[1:(end-2)]))
    else
        max_frames=parse(Int64,String(yy[1:(end-1)]))
    end

    c=Canvas(640,480)

    grid=Grid()

    grid[1,2]=c

    frame_slider = Scale(false, 1,max_frames,1)
    adj_frame = Adjustment(frame_slider)
    setproperty!(adj_frame,:value,1)

    grid[1,3]=frame_slider

    ts_canvas = Canvas(640,50)
    grid[1,4] = ts_canvas

    frame_advance_sb = SpinButton(1:vid_length)
    grid[2,4] = frame_advance_sb

    control_grid=Grid()

    trace_button=Button("Trace")
    control_grid[1,4]=trace_button

    erase_button=ToggleButton("Erase Mode")
    control_grid[1,6]=erase_button

    draw_button=ToggleButton("Draw Mode")
    control_grid[1,7]=draw_button

    delete_button=Button("Delete Whisker")
    control_grid[1,8]=delete_button

    touch_override = Button("Mark Contact")
    control_grid[1,9] = touch_override

    touch_no_contact = Button("Mark No Contact")
    control_grid[1,10] = touch_no_contact

    add_frame_button = Button("Add Frame To Tracking")
    control_grid[1,11] = add_frame_button

    delete_frame_button = Button("Delete Frame From Tracking")
    control_grid[1,12] = delete_frame_button

    num_whiskers_sb = SpinButton(1:1:5)
    control_grid[1,13] = num_whiskers_sb
    control_grid[2,13] = Label("Number of Whiskers To Track")

    grid[2,2]=control_grid

    #Menus
    mb = MenuBar()
    sortopts = MenuItem("_File")
    sortmenu = Menu(sortopts)
    save_whisk_ = MenuItem("Save Whiskers")
    push!(sortmenu,save_whisk_)
    load_whisk_ = MenuItem("Load Whiskers")
    push!(sortmenu,load_whisk_)
    save_contact_ = MenuItem("Save Contact Detection")
    push!(sortmenu,save_contact_)
    load_contact_ = MenuItem("Load Contact Detection")
    push!(sortmenu,load_contact_)
    push!(mb,sortopts)

    extraopts = MenuItem("_Extra")
    extramenu = Menu(extraopts)
    discrete_menu_ = MenuItem("Discretization")
    push!(extramenu,discrete_menu_)

    mask_menu_ = MenuItem("Mask")
    push!(extramenu,mask_menu_)

    pad_menu_ = MenuItem("Whisker Pad")
    push!(extramenu,pad_menu_)

    roi_menu_ = MenuItem("Region of Interest")
    push!(extramenu,roi_menu_)

    pole_menu_ = MenuItem("Pole")
    push!(extramenu,pole_menu_)

    view_menu_ = MenuItem("Viewer")
    push!(extramenu,view_menu_)

    manual_menu_ = MenuItem("Tracing")
    push!(extramenu,manual_menu_)

    push!(mb,extraopts)

    imageopts = MenuItem("_Image")
    imagemenu = Menu(imageopts)
    crop_menu_ = MenuItem("Crop")
    push!(imagemenu,crop_menu_)

    image_adjust_menu_ = MenuItem("Image Adjustment")
    push!(imagemenu,image_adjust_menu_)

    push!(mb,imageopts)

    otheropts = MenuItem("_Other Programs")
    othermenu = Menu(otheropts)
    janelia_menu_ = MenuItem("Janelia Tracker")
    push!(othermenu,janelia_menu_)
    dlc_menu_ = MenuItem("DeepLabCut")
    push!(othermenu,dlc_menu_)

    push!(mb,otheropts)

    grid[1,1] = mb


    #=
    Menu for discrete points
    =#
    discrete_grid = Grid()
    discrete_space_button = SpinButton(2:100)
    discrete_grid[1,1] = discrete_space_button
    discrete_grid[2,1] = Label("Space Between Points")

    discrete_max_points_button = SpinButton(4:20)
    discrete_grid[1,2] = discrete_max_points_button
    discrete_grid[2,2] = Label("Max number of Points")

    discrete_auto_calc = CheckButton("Auto Calculate")
    discrete_grid[1,3] = discrete_auto_calc

    discrete_win=Window(discrete_grid)
    Gtk.showall(discrete_win)
    visible(discrete_win,false)

    d_widgets=discrete_widgets(discrete_win,discrete_space_button,discrete_max_points_button,discrete_auto_calc)

    #=
    Mask Menu Widgets
    =#

    mask_grid = Grid()
    mask_gen_button = CheckButton("Create Mask")
    mask_grid[1,1] = mask_gen_button
    mask_min_button = SpinButton(0:255)
    mask_grid[1,2] = mask_min_button
    mask_grid[2,2] = Label("Minimum Intensity")
    mask_max_button = SpinButton(0:255)
    mask_grid[1,3] = mask_max_button
    mask_grid[2,3] = Label("Maximum Intensity")

    mask_win=Window(mask_grid)
    Gtk.showall(mask_win)
    visible(mask_win,false)

    m_widgets=mask_widgets(mask_win,mask_gen_button,mask_min_button,mask_max_button)

    #=
    Pad Menu Widgets
    =#
    pad_grid=Grid()
    pad_gen_button = CheckButton("Select Whisker Pad")
    pad_grid[1,1] = pad_gen_button
    pad_grid[1,2] = Label("Select the location of the whisker pad when box is checked")
    pad_grid[1,3] = Label("Whiskers will be oriented so that the root is nearest the pad location")
    pad_win=Window(pad_grid)
    Gtk.showall(pad_win)
    visible(pad_win,false)
    p_widgets=pad_widgets(pad_win,pad_gen_button)

    #=
    ROI Menu Widgets
    =#
    roi_grid=Grid()
    roi_gen_button = CheckButton("Select ROI center")
    roi_grid[1,1] = roi_gen_button
    roi_height_button = SpinButton(20:150)
    roi_grid[1,2] = roi_height_button
    roi_grid[2,2] = Label("ROI Height")
    roi_width_button = SpinButton(20:150)
    roi_grid[1,3] = roi_width_button
    roi_grid[2,3] = Label("ROI Width")
    roi_tilt_button = SpinButton(-45:45)
    roi_grid[1,4] = roi_tilt_button
    roi_grid[2,4] = Label("ROI Tilt")

    roi_grid[1,7] = Label("When candidate whisker traces are detected in the image, \n only whiskers with bases inside the ROI are kept.")

    roi_win=Window(roi_grid)
    Gtk.showall(roi_win)
    visible(roi_win,false)
    r_widgets=roi_widgets(roi_win,roi_gen_button,roi_height_button,roi_width_button,roi_tilt_button)

    #=
    Pole Menu Widgets
    =#
    pole_grid=Grid()
    pole_mode_button = CheckButtonLeaf("Find Location in Tracking?")
    pole_grid[1,1] = pole_mode_button
    pole_gen_button = CheckButton("Select Pole Location")
    pole_grid[1,2] = pole_gen_button
    pole_auto_button = Button("Automatically Determine Pole Location")
    pole_grid[1,3] = pole_auto_button
    pole_touch_button = CheckButton("Show Touch Location")
    pole_grid[1,4] = pole_touch_button

    pole_delete_button = Button("Delete Pole in Frame")
    pole_grid[1,5] = pole_delete_button

    pole_grid[1,7] = Label("Check the top checkbox if you want the whisker tracker to \n also look for a pole in each frame")

    pole_win = Window(pole_grid)
    Gtk.showall(pole_win)
    visible(pole_win,false)
    pp_widgets=pole_widgets(pole_win,pole_mode_button,pole_gen_button,pole_auto_button,pole_touch_button,pole_delete_button)

    #=
    View Window
    =#

    view_grid=Grid()
    view_whisker_pad_button = CheckButtonLeaf("Whisker Pad")
    view_grid[1,1] = view_whisker_pad_button
    view_roi_button = CheckButtonLeaf("Region of Interest")
    view_grid[1,2] = view_roi_button
    view_discrete_button = CheckButtonLeaf("Discrete Points")
    view_grid[1,3] = view_discrete_button
    view_pole_button = CheckButtonLeaf("Pole")
    view_grid[1,4] = view_pole_button
    view_tracked_button = CheckButtonLeaf("Tracked Whiskers")
    view_grid[1,5] = view_tracked_button

    view_grid[1,7] = Label("Select which items are always displayed for each frame")

    view_win = Window(view_grid)
    Gtk.showall(view_win)
    visible(view_win,false)
    v_widgets=view_widgets(view_win,view_whisker_pad_button,view_roi_button,view_discrete_button,view_pole_button,view_tracked_button)

    #=
    Manual Tracing Menu
    =#

    manual_grid=Grid()

    connect_button=Button("Connect to Pad")
    manual_grid[1,1]=connect_button

    combine_button=ToggleButton("Combine Segments")
    manual_grid[1,2]=combine_button

    manual_win = Window(manual_grid)
    Gtk.showall(manual_win)
    visible(manual_win,false)
    man_widgets=manual_widgets(manual_win,connect_button,combine_button)


    #=
    Visual Display Widgets
    =#

    #=
    Image adjustment window
    =#
    image_adj_grid = Grid()
    hist_c = Canvas(200,200)
    image_adj_grid[1,1]=hist_c

    contrast_min_slider = Scale(false,0,255,1)
    adj_contrast_min=Adjustment(contrast_min_slider)
    setproperty!(adj_contrast_min,:value,0)
    image_adj_grid[1,2]=contrast_min_slider
    image_adj_grid[2,2]=Label("Minimum")

    contrast_max_slider = Scale(false,0,255,1)
    adj_contrast_max=Adjustment(contrast_max_slider)
    setproperty!(adj_contrast_max,:value,255)
    image_adj_grid[1,3]=contrast_max_slider
    image_adj_grid[2,3]=Label("Maximum")

    background_button = CheckButton("Subtract Background")
    image_adj_grid[1,4]=background_button

    sharpen_button = CheckButton("Sharpen Image")
    image_adj_grid[1,5]=sharpen_button

    aniso_button = CheckButton("Anisotropic Diffusion")
    image_adj_grid[1,6]=aniso_button

    local_contrast_button = CheckButton("Local Contrast Enhancement")
    image_adj_grid[1,7]=local_contrast_button

    image_adj_win = Window(image_adj_grid)
    Gtk.showall(image_adj_win)
    visible(image_adj_win,false)
    ia_widgets = image_adj_widgets(image_adj_win,hist_c,contrast_min_slider,adj_contrast_min,contrast_max_slider,adj_contrast_max,
    background_button,sharpen_button,aniso_button,local_contrast_button)

    #=
    Menu for Janelia Tracker Parameter Tweaking
    =#
    janelia_grid=Grid()
    janelia_label=Label("Janelia Parameters")
    janelia_grid[1,1]=janelia_label

    janelia_seed_thres=SpinButton(0.01:.01:1.0)
    setproperty!(janelia_seed_thres,:value,0.99)
    janelia_grid[1,2]=janelia_seed_thres
    janelia_grid[2,2]=Label("Seed Threshold")

    janelia_seed_iterations=SpinButton(1:1:10)
    setproperty!(janelia_seed_iterations,:value,1)
    janelia_grid[1,3]=janelia_seed_iterations
    janelia_grid[1,3]=Label("Seed Iterations")

    janelia_win=Window(janelia_grid)
    Gtk.showall(janelia_win)
    visible(janelia_win,false)
    j_widgets=janelia_widgets(janelia_win,janelia_seed_thres,janelia_seed_iterations)

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

    #=
    Quick Buttons
    =#

    win = Window(grid, "Whisker Tracker") |> Gtk.showall

    all_whiskers=[Array{Whisker1,1}() for i=1:vid_length]

    tracker_name = (vid_name)[1:(end-4)]

    wt=Tracker(vid,path,name,vid_name,whisk_path,meas_path,path,tracker_name,50,falses(480,640),Array{Whisker1,1}(),
    (0.0,0.0),255,0,all_whiskers,zeros(Float32,10,vid_length))

    sleep(5.0)

    if VERSION > v"0.7-"
        woi_array = Array{Whisker1,1}(undef,vid_length)
    else
        woi_array = Array{Whisker1,1}(vid_length)
    end

    t_folder=Dates.format(now(),"yyyy-mm-dd-HH-MM-SS")
    these_paths = Save_Paths(t_folder)

    handles = Tracker_Handles(1,vid_length,max_frames,win,c,frame_slider,adj_frame,trace_button,zeros(UInt32,640,480),
    vid[:,:,1],zeros(UInt8,640,480),0,woi_array,1,num_whiskers_sb,1,
    false,erase_button,false,0,falses(vid_length),
    delete_button,0,Whisker1(),false,
    start_frame,false,false,false,draw_button,false,false,touch_override,touch_no_contact,false,
    falses(0),Array{Int64,1}(),zeros(Float64,vid_length),zeros(Float64,vid_length),
    wt,5.0,false,false,false,2,ts_canvas,frame_list,frame_advance_sb,1,d_widgets,m_widgets,p_widgets,
    r_widgets,pp_widgets,v_widgets,man_widgets,ia_widgets,j_widgets,deep_widgets,
    falses(vid_length),zeros(Float32,vid_length,2),zeros(UInt8,640,480),false,false,false,1,
    false,zeros(Float64,1,1),zeros(Float64,1,1),falses(1,1),false,falses(1),zeros(Float64,1,1),DLC_Wrapper(),these_paths)

    signal_connect(frame_slider_cb, frame_slider, "value-changed", Void, (), false, (handles,))
    signal_connect(frame_select, frame_advance_sb, "value-changed", Void, (), false, (handles,))
    signal_connect(trace_cb,trace_button, "clicked", Void, (), false, (handles,))

    signal_connect(erase_cb,erase_button, "clicked",Void,(),false,(handles,))
    signal_connect(whisker_select_cb,c,"button-press-event",Void,(Ptr{Gtk.GdkEventButton},),false,(handles,))
    signal_connect(delete_cb,delete_button, "clicked",Void,(),false,(handles,))
    signal_connect(combine_cb,combine_button,"clicked",Void,(),false,(handles,))

    signal_connect(advance_slider_cb,win,"key-press-event",Void,(Ptr{Gtk.GdkEventKey},),false,(handles,))
    signal_connect(draw_cb,draw_button,"clicked",Void,(),false,(handles,))
    signal_connect(connect_cb,connect_button,"clicked",Void,(),false,(handles,))
    signal_connect(touch_override_cb,touch_override,"clicked",Void,(),false,(handles,1))
    signal_connect(touch_override_cb,touch_no_contact,"clicked",Void,(),false,(handles,0))

    signal_connect(add_frame_cb,add_frame_button,"clicked",Void,(),false,(handles,))
    signal_connect(delete_frame_cb,delete_frame_button,"clicked",Void,(),false,(handles,))

    signal_connect(num_whiskers_cb,num_whiskers_sb,"value-changed",Void,(),false,(handles,))

    #File Menus

    make_menu_callbacks(discrete_menu_,discrete_win)
    make_menu_callbacks(mask_menu_,mask_win)
    make_menu_callbacks(pad_menu_,pad_win)
    make_menu_callbacks(roi_menu_,roi_win)
    make_menu_callbacks(pole_menu_,pole_win)
    make_menu_callbacks(view_menu_,view_win)
    make_menu_callbacks(manual_menu_,manual_win)
    make_menu_callbacks(image_adjust_menu_,image_adj_win)
    make_menu_callbacks(janelia_menu_,janelia_win)
    make_menu_callbacks(dlc_menu_,dlc_win)

    #File Callbacks
    signal_connect(save_cb, save_whisk_, "activate",Void,(),false,(handles,))
    signal_connect(load_cb, load_whisk_, "activate",Void,(),false,(handles,))
    signal_connect(save_contact_cb,save_contact_,"activate",Void,(),false,(handles,))
    signal_connect(load_contact_cb,load_contact_,"activate",Void,(),false,(handles,))

    #Discrete Callbacks
    signal_connect(discrete_distance_cb,discrete_space_button,"value-changed",Void,(),false,(handles,))
    signal_connect(discrete_points_cb,discrete_max_points_button,"value-changed",Void,(),false,(handles,))
    signal_connect(discrete_auto_cb,discrete_auto_calc,"clicked",Void,(),false,(handles,))

    #Mask Callbacks
    signal_connect(mask_min_cb,mask_min_button,"value-changed",Void,(),false,(handles,))
    signal_connect(mask_max_cb,mask_max_button,"value-changed",Void,(),false,(handles,))
    signal_connect(mask_gen_cb,mask_gen_button,"clicked",Void,(),false,(handles,))

    #Pad Callbacks
    signal_connect(pad_gen_cb,pad_gen_button,"clicked",Void,(),false,(handles,))

    #Pole Callbacks
    signal_connect(pole_mode_cb,pole_mode_button,"clicked",Void,(),false,(handles,))
    signal_connect(pole_select_cb,pole_gen_button,"clicked",Void,(),false,(handles,))
    signal_connect(pole_auto_cb,pole_auto_button,"clicked",Void,(),false,(handles,))
    signal_connect(pole_delete_cb,pole_delete_button,"clicked",Void,(),false,(handles,))

    #View Callbacks
    signal_connect(view_whisker_pad_cb,view_whisker_pad_button,"clicked",Void,(),false,(handles,))
    signal_connect(view_roi_cb,view_roi_button,"clicked",Void,(),false,(handles,))
    signal_connect(view_pole_cb,view_pole_button,"clicked",Void,(),false,(handles,))
    signal_connect(view_discrete_cb,view_discrete_button,"clicked",Void,(),false,(handles,))
    signal_connect(view_whiskers_cb,view_tracked_button,"clicked",Void,(),false,(handles,))

    #Image Adjustment Callbacks
    signal_connect(adjust_contrast_cb,contrast_min_slider,"value-changed",Void,(),false,(handles,))
    signal_connect(adjust_contrast_cb,contrast_max_slider,"value-changed",Void,(),false,(handles,))
    signal_connect(background_cb,background_button,"clicked",Void,(),false,(handles,))
    signal_connect(sharpen_cb,sharpen_button,"clicked",Void,(),false,(handles,))
    signal_connect(aniso_cb,aniso_button,"clicked",Void,(),false,(handles,))
    signal_connect(local_contrast_cb,local_contrast_button,"clicked",Void,(),false,(handles,))

    #Janelia Tweaking Callbacks
    signal_connect(jt_seed_thres_cb,janelia_seed_thres,"value-changed",Void,(),false,(handles,))
    signal_connect(jt_seed_iterations_cb,janelia_seed_iterations,"value-changed",Void,(),false,(handles,))

    #DLC Callbacks
    signal_connect(dlc_init_cb,dlc_create_button,"clicked",Void,(),false,(handles,))
    signal_connect(dlc_export_cb,dlc_export_button,"clicked",Void,(),false,(handles,))
    signal_connect(dlc_with_pole_cb,dlc_with_pole_button,"clicked",Void,(),false,(handles,))

    save_single_image(handles,vid[:,:,1],1)

    handles
end

#=
Menu Buttons
=#

function make_menu_callbacks(menu,win)

    signal_connect((widget,w)->visible(w[1],true),menu,"activate",Void,(),false,(win,))
    signal_connect(win, :delete_event) do widget, event
        visible(win, false)
        true
    end
end

#=
Janelia Callbacks
=#
function jt_seed_thres_cb(w::Ptr,user_data::Tuple{Tracker_Handles})

    han, = user_data

    thres=getproperty(han.janelia_widgets.jt_seed_thres_button,:value,Float64)

    change_JT_param(:paramSEED_THRESH,convert(Float32,thres))

    nothing
end

function jt_seed_iterations_cb(w::Ptr,user_data::Tuple{Tracker_Handles})

    han, = user_data

    iterations=getproperty(han.janelia_widgets.jt_seed_iterations_button,:value,Int64)

    change_JT_param(:paramSEED_ITERATIONS,convert(Int32,iterations))

    nothing
end

#=
DLC widgets
=#

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

function copy_images_to_dlc(han)

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

#=
Discrete Callbacks
=#

function redraw_all(han)
    plot_image(han,han.current_frame')
    plot_whiskers(han)
end

function discrete_distance_cb(w::Ptr,user_data::Tuple{Tracker_Handles})

    han, = user_data

    num_dist=getproperty(han.d_widgets.space_button,:value,Int)

    han.d_spacing = num_dist

    make_discrete_woi(han.wt,han.woi,han.tracked,num_dist)

    redraw_all(han)

    nothing
end

function discrete_points_cb(w::Ptr,user_data::Tuple{Tracker_Handles})

    han, = user_data

    num_points=getproperty(han.d_widgets.points_button,:value,Int)
    num_dist=getproperty(han.d_widgets.space_button,:value,Int)

    change_discrete_size(han.wt,num_points)
    make_discrete_woi(han.wt,han.woi,han.tracked,num_dist)

    redraw_all(han)

    nothing

end

function discrete_auto_cb(w::Ptr, user_data::Tuple{Tracker_Handles})

    han, = user_data

    han.discrete_auto_calc=getproperty(han.d_widgets.calc_button,:active,Bool)

    nothing
end

#=
Mask Callbacks
=#

function mask_gen_cb(w::Ptr, user_data::Tuple{Tracker_Handles})

    han, = user_data

    redraw_all(han)
    plot_mask(han)

    nothing
end

function mask_min_cb(w::Ptr, user_data::Tuple{Tracker_Handles})

    han, = user_data

    mymin=getproperty(han.mask_widgets.min_button,:value,Int)
    mymax=getproperty(han.mask_widgets.max_button,:value,Int)

    generate_mask(han.wt,mymin,mymax,han.frame)

    redraw_all(han)
    plot_mask(han)

    nothing
end

function mask_max_cb(w::Ptr, user_data::Tuple{Tracker_Handles})

    han, = user_data

    mymin=getproperty(han.mask_widgets.min_button,:value,Int)
    mymax=getproperty(han.mask_widgets.max_button,:value,Int)

    redraw_all(han)
    generate_mask(han.wt,mymin,mymax,han.frame)

    plot_mask(han)

    nothing
end

#=
Whisker Pad
=#

function pad_gen_cb(w::Ptr, user_data::Tuple{Tracker_Handles})

    han, = user_data

    if getproperty(han.pad_widgets.gen_button,:active,Bool)
        han.selection_mode = 10
        han.view_pad = true
    else
        han.selection_mode = 1
        determine_viewers(han)
    end

    redraw_all(han)

    nothing
end

function determine_viewers(han)

    han.view_pad = getproperty(han.view_widgets.whisker_pad_button,:active,Bool)
    han.view_roi = getproperty(han.view_widgets.roi_button,:active,Bool)
    han.view_pole = getproperty(han.view_widgets.pole_button,:active,Bool)
    han.discrete_draw = getproperty(han.view_widgets.discrete_button,:active,Bool)

    nothing
end

#=
Touch Functions
=#

function pole_mode_cb(w::Ptr,user_data::Tuple{Tracker_Handles})

    han, = user_data

    #Update DLC parameter file

    nothing
end

function pole_select_cb(w::Ptr,user_data::Tuple{Tracker_Handles})

    han, = user_data

    if getproperty(han.pole_widgets.gen_button,:active,Bool)
        han.selection_mode = 12
        han.view_pole = true
    else
        han.selection_mode = 1
        determine_viewers(han)
    end

    nothing
end

function pole_auto_cb(w::Ptr,user_data::Tuple{Tracker_Handles})

    han, = user_data

    pole_pos = dlc_extra_pole_location(han)

    println("Acquired Pole Positions")

    for i=1:size(han.pole_present,1)

        if isnan(pole_pos[i,1])

        else
            han.pole_present[i] = true
            han.pole_loc[i,1] = convert(Float32,pole_pos[i,1])
            han.pole_loc[i,2] = convert(Float32,pole_pos[i,2])
        end
    end

    nothing
end

function touch_override_cb(w::Ptr,user_data::Tuple{Tracker_Handles,Int64})

    han, contact = user_data

    #Check if this frame is already in the contact list
    if isempty(find(han.touch_frames_i.==han.displayed_frame))

        push!(han.touch_frames_i,han.displayed_frame)
        push!(han.touch_frames,contact)

        #Do we need to sort these here?

    else #Change existing entry

        ind=find(han.touch_frames_i.==han.displayed_frame)[1]
        han.touch_frames[ind] = contact
    end

    draw_touch(han)

    nothing
end

function pole_delete_cb(w::Ptr,user_data::Tuple{Tracker_Handles})

    han, = user_data

    han.pole_present[han.frame] = false

    redraw_all(han)

    nothing
end

function detect_touch(han)

end

#=
Draw marker to indicate that touch has occured
=#

function draw_touch(han::Tracker_Handles)

    if !isempty(find(han.touch_frames_i.==han.displayed_frame))

        ctx=Gtk.getgc(han.c)

        ind=find(han.touch_frames_i.==han.displayed_frame)[1]

        if han.touch_frames[ind]
            set_source_rgb(ctx,1,0,0)
        else
            set_source_rgb(ctx,1,1,1)
        end

        rectangle(ctx,600,0,20,20)
        fill(ctx)

        reveal(han.c)
    end

    nothing
end

#=
View Callbacks
=#

function view_whisker_pad_cb(w::Ptr,user_data::Tuple{Tracker_Handles})

    han, = user_data
    han.view_pad = getproperty(han.view_widgets.whisker_pad_button,:active,Bool)
    redraw_all(han)
    nothing
end

function view_roi_cb(w::Ptr,user_data::Tuple{Tracker_Handles})

    han, = user_data
    han.view_roi = getproperty(han.view_widgets.roi_button,:active,Bool)
    redraw_all(han)
    nothing
end

function view_pole_cb(w::Ptr,user_data::Tuple{Tracker_Handles})

    han, = user_data
    han.view_pole = getproperty(han.view_widgets.pole_button,:active,Bool)
    redraw_all(han)
    nothing
end

function view_discrete_cb(w::Ptr,user_data::Tuple{Tracker_Handles})

    han, = user_data
    han.discrete_draw = getproperty(han.view_widgets.discrete_button,:active,Bool)
    redraw_all(han)
    nothing
end

function view_whiskers_cb(w::Ptr,user_data::Tuple{Tracker_Handles})

    han, = user_data
    han.show_tracked = getproperty(han.view_widgets.tracked_button,:active,Bool)
    redraw_all(han)
    nothing
end

#=
Frame Drawing
=#

function frame_slider_cb(w::Ptr,user_data::Tuple{Tracker_Handles})

    han, = user_data

    han.displayed_frame = getproperty(han.adj_frame,:value,Int64)

    #Reset array of displayed whiskers
    han.wt.whiskers=Array{Whisker1,1}()

    #If whiskers were found previously, load them
    if (length(han.wt.all_whiskers[han.frame])>0)&(han.displayed_frame == han.frame_list[han.frame])
        han.wt.whiskers=han.wt.all_whiskers[han.frame]
        WT_reorder_whisker(han.wt.whiskers,han.wt.pad_pos) #If you change pad position, from when you first tracked
        plot_whiskers(han)
    end

    #If equal to frame we already acquired, don't get it again
    temp=zeros(UInt8,640,480)
    frame_time = han.displayed_frame  /  25 #Number of frames in a second of video
    try
        load_single_frame(frame_time,temp,han.wt.vid_name)
        han.current_frame=temp'
        han.current_frame2=deepcopy(han.current_frame)
        redraw_all(han)
    catch
    end

    nothing
end

function load_single_frame(x,tt,vn)

    xx=open(`$(ffmpeg_path) -loglevel panic -ss $(x) -i $(vn) -f image2pipe -vcodec rawvideo -pix_fmt gray -`);
    if VERSION > v"0.7-"
        read!(xx,tt)
    else
        read!(xx[1],tt)
    end


end

function draw_frame_list(han)

    ctx=Gtk.getgc(han.ts_canvas)

    set_source_rgb(ctx,1,1,1)
    paint(ctx)

    w=width(ctx)
    h=height(ctx)
    set_source_rgb(ctx,0,0,1)

    for i=1:length(han.frame_list)

        x = han.frame_list[i] / han.max_frames * w

        move_to(ctx,x,0)
        line_to(ctx,x,h)
        stroke(ctx)

    end

    reveal(han.ts_canvas)

end

#=
Change the number of whiskers to track
=#

function num_whiskers_cb(w::Ptr,user_data::Tuple{Tracker_Handles})

    han, = user_data

    #woi_array
    #woi_angle
    #woi_curv
    #woi_id

    nothing
end

function add_frame_cb(w::Ptr,user_data::Tuple{Tracker_Handles})

    han, = user_data

    new_frame=han.displayed_frame

    try

        if isempty(findall(han.frame_list.==new_frame))

            frame_location=findfirst(han.frame_list.>new_frame)
            if frame_location==nothing
                frame_location = length(han.frame_list) + 1
            end

            insert!(han.frame_list,frame_location,new_frame)

            #Add new video frame to video array
            new_vid=zeros(UInt8,size(han.wt.vid,1),size(han.wt.vid,2),size(han.wt.vid,3)+1)
            for i=1:size(han.wt.vid,3)
                if i<frame_location
                    new_vid[:,:,i] = han.wt.vid[:,:,i]
                else
                    new_vid[:,:,i+1] = han.wt.vid[:,:,i]
                end
            end
            new_vid[:,:,frame_location] = han.current_frame2
            han.wt.vid = new_vid

            #add whisker WOI
            insert!(han.woi,frame_location,Whisker1())

            insert!(han.wt.all_whiskers,frame_location,Array{Whisker1,1}())

            #tracked array
            insert!(han.tracked,frame_location,false)

            #woi_angle::Array{Float64,1}
            insert!(han.woi_angle,frame_location,0.0)

            #woi_curv::Array{Float64,1}
            insert!(han.woi_curv,frame_location,0.0)

            #pole present
            insert!(han.pole_present,frame_location,false)

            #pole loc
            new_pole_loc=zeros(Float32,size(han.pole_loc,1)+1,2)
            for i=1:size(han.pole_loc,1)
                if i<frame_location
                    new_pole_loc[i,1] = han.pole_loc[i,1]
                    new_pole_loc[i,2] = han.pole_loc[i,2]
                else
                    new_pole_loc[i+1,1] = han.pole_loc[i,1]
                    new_pole_loc[i+1,2] = han.pole_loc[i,2]
                end
            end
            han.pole_loc = new_pole_loc

            #Discrete points
            new_wp = zeros(Float32,size(han.wt.w_p,1),size(han.wt.w_p,2)+1)
            for i=1:size(han.wt.w_p,2)

                if i<frame_location
                    new_wp[:,i] = han.wt.w_p[:,i]
                else
                    new_wp[:,i+1] = han.wt.w_p[:,i]
                end
            end
            han.wt.w_p = new_wp

            #Change frame list spin button maximum number and current index
            Gtk.GAccessor.range(han.frame_advance_sb,1,length(han.frame_list))
            setproperty!(han.frame_advance_sb,:value,frame_location)

            save_single_image(han,han.current_frame2,new_frame)

            redraw_all(han)

        end

    catch
        println("Could not add frame")
    end

    nothing
end

#=
This needs totally redone
=#
function delete_frame_cb(w::Ptr,user_data::Tuple{Tracker_Handles})

    han, = user_data

    new_frame=han.displayed_frame

    try

        #frame_id=find(han.frame_list.==new_frame)

        #if !isempty(frame_id)

            #frame_location=frame_id[1]

            #deleteat!(han.frame_list,frame_location)

        #end
        println("Deleting frames is not available right now")
    catch
        println("Could not delete frame")
    end

    nothing
end

#=
Save Callbacks
=#

function save_cb(w::Ptr,user_data::Tuple{Tracker_Handles})

    han, = user_data

    #filepath = save_dialog("Save Whisker Tracking",han.win)

    dlg = Gtk.GtkFileChooserDialog("Save WhiskerTracking", han.win, Gtk.GConstants.GtkFileChooserAction.SAVE,
                                   (("_Cancel", Gtk.GConstants.GtkResponseType.CANCEL),
                                    ("_Save",   Gtk.GConstants.GtkResponseType.ACCEPT));)
       dlgp = Gtk.GtkFileChooser(dlg)

       ccall((:gtk_file_chooser_set_do_overwrite_confirmation, Gtk.libgtk), Void, (Ptr{Gtk.GObject}, Cint), dlg, true)
       Gtk.GAccessor.current_folder(dlgp,string(han.wt.tracking_path,"/tracking"))
       Gtk.GAccessor.current_name(dlgp, han.wt.tracking_name)
       response = run(dlg)
       if response == Gtk.GConstants.GtkResponseType.ACCEPT
           selection = Gtk.bytestring(Gtk.GAccessor.filename(dlgp))
       else
           selection = ""
       end
       destroy(dlg)
       filepath=selection

    if filepath != ""

        if filepath[end-3:end]==".jld"
        else
            filepath=string(filepath,".jld")
        end

        file=jldopen(filepath,"w")

        mywhiskers=Array{Whisker1}(0)

        for i=1:length(han.tracked)
            if han.tracked[i]
                han.woi[i].time = i
                push!(mywhiskers,deepcopy(han.woi[i]))
            end
        end

        write(file,"Whiskers",mywhiskers)
        write(file,"Frames_Tracked",han.tracked)
        write(file,"Start_Frame", han.start_frame)
        write(file,"Touch",han.touch_frames)
        write(file,"Touch_Inds",han.touch_frames_i)
        write(file,"Angles",han.woi_angle)
        write(file,"Curvature",han.woi_curv)
        write(file,"all_whiskers",han.wt.all_whiskers)

        close(file)

    end

    nothing
end

function load_whisker_data(han,filepath)

    if filepath != ""

        file = jldopen(filepath,"r")
        if JLD.exists(file,"Whiskers")
            mywhiskers = read(file,"Whiskers")
        end
        if JLD.exists(file,"Whiskers")
            mytracked = read(file, "Frames_Tracked")
            if size(han.wt.vid,3) != length(mytracked)
                println("Error: Number of loaded whisker frames does not match number of video frames")
            else

                for i=1:length(mywhiskers)
                    han.woi[mywhiskers[i].time] = deepcopy(mywhiskers[i])
                end
                han.tracked = mytracked
            end
        end
        if JLD.exists(file,"Start_Frame")
            start_frame = read(file,"Start_Frame")
            if han.start_frame != start_frame
                println("Error: This data was not tracked starting at the same point in the video")
            end
        end
        if JLD.exists(file,"Touch")
            han.touch_frames=read(file,"Touch")
        end
        if JLD.exists(file,"Touch_Inds")
            han.touch_frames_i=read(file,"Touch_Inds")
        end
        if JLD.exists(file,"Angles")
            han.woi_angle=read(file,"Angles")
        end
        if JLD.exists(file,"Curvature")
            han.woi_curv=read(file,"Curvature")
        end
        if JLD.exists(file,"all_whiskers")
            han.wt.all_whiskers=read(file,"all_whiskers")
        end
        close(file)

        #change saving
        han.wt.tracking_name = filepath


    end
    nothing
end

function load_cb(w::Ptr,user_data::Tuple{Tracker_Handles})

    han, = user_data

    filepath = open_dialog("Load Whisker Tracking",han.win)

    load_whisker_data(han,filepath)

    nothing
end

function save_contact_cb(w::Ptr,user_data::Tuple{Tracker_Handles})

    han, = user_data

    filepath = save_dialog("Save Contact Data",han.win)

    if filepath != ""
        if filepath[end-3:end]==".mat"
        else
            filepath=string(filepath,".mat")
        end

        file=matopen(filepath,"w")
        write(file,"Touch_Inds",han.touch_frames_i)
        write(file,"Touch",convert(Array{Int64,1},han.touch_frames))
        close(file)
    end

    nothing
end

function load_contact_cb(w::Ptr,user_data::Tuple{Tracker_Handles})

    han, = user_data

    filepath = open_dialog("Load Contact Data",han.win)

    if filepath != ""
        file = matopen(filepath,"r")
        if MAT.exists(file,"Touch_Inds")
            touch_inds = read(file,"Touch_Inds")
            han.touch_frames_i = touch_inds
        end
        if MAT.exists(file,"Touch")
            touch = read(file,"Touch")
            han.touch_frames = convert(BitArray{1},touch)
        end
        close(file)
    end

    nothing
end


function advance_slider_cb(w::Ptr,param_tuple,user_data::Tuple{Tracker_Handles})

    han, = user_data

    event = unsafe_load(param_tuple)

    if event.keyval == 0xff53 #Right arrow
        setproperty!(han.adj_frame,:value,han.displayed_frame+1) #This will call the slider callback
        #han.displayed_frame += 1
    elseif event.keyval == 0xff51 #Left arrow
        setproperty!(han.adj_frame,:value,han.displayed_frame-1)
        #han.displayed_frame -= 1
    end

    nothing
end

function adjust_contrast_cb(w::Ptr,user_data::Tuple{Tracker_Handles})

    han, = user_data

    try

        han.wt.contrast_min = getproperty(han.image_adj_widgets.adj_contrast_min,:value,Int64)
        han.wt.contrast_max = getproperty(han.image_adj_widgets.adj_contrast_max,:value,Int64)

        adjust_contrast_gui(han)

        plot_image(han,han.current_frame')

    catch
        println("Error while adjusting contrast")
    end

    nothing
end

function background_cb(w::Ptr,user_data::Tuple{Tracker_Handles})

    han, = user_data

    han.background_mode = getproperty(han.image_adj_widgets.background_button,:active,Bool)

    nothing
end

function sharpen_cb(w::Ptr,user_data::Tuple{Tracker_Handles})

    han, = user_data

    han.sharpen_mode = getproperty(han.image_adj_widgets.sharpen_button,:active,Bool)

    nothing
end

function aniso_cb(w::Ptr,user_data::Tuple{Tracker_Handles})

    han, = user_data

    han.anisotropic_mode = getproperty(han.image_adj_widgets.anisotropic_button,:active,Bool)

    nothing
end

function local_contrast_cb(w::Ptr,user_data::Tuple{Tracker_Handles})

    han, = user_data

    han.local_contrast_mode = getproperty(han.image_adj_widgets.local_contrast_button,:active,Bool)

    nothing
end

#=
Adds points from current whisker of interest to
follicle position from last frame.

This is a weird special case and can probably be eliminated
=#
function connect_cb(w::Ptr,user_data::Tuple{Tracker_Handles})

    han, = user_data

    try

        if han.tracked[han.frame-1]
            x_1=han.woi[han.frame-1].x[end]
            y_1=han.woi[han.frame-1].y[end]
            thick_1=han.woi[han.frame-1].thick[end]
            scores_1=han.woi[han.frame-1].scores[end]
        end

        dist=round(Int64,sqrt((han.wt.whiskers[han.woi_id].x[end]-x_1)^2+(han.wt.whiskers[han.woi_id].y[end]-y_1)^2))

        xs=linspace(han.wt.whiskers[han.woi_id].x[end],x_1,dist)
        ys=linspace(han.wt.whiskers[han.woi_id].y[end],y_1,dist)

        for i=2:length(xs)
            push!(han.wt.whiskers[han.woi_id].x,xs[i])
            push!(han.wt.whiskers[han.woi_id].y,ys[i])
            push!(han.wt.whiskers[han.woi_id].thick,thick_1)
            push!(han.wt.whiskers[han.woi_id].scores,scores_1)
        end

        han.wt.whiskers[han.woi_id].len=length(han.wt.whiskers[han.woi_id].x)

        plot_whiskers(han)

        assign_woi(han)

    catch
        println("Could not connect to pad")
    end

    nothing
end

function frame_select(w::Ptr,user_data::Tuple{Tracker_Handles})

    han, = user_data

    han.frame = getproperty(han.frame_advance_sb,:value,Int64)
    setproperty!(han.adj_frame,:value,han.frame_list[han.frame])
    han.displayed_frame = han.frame_list[han.frame]

    han.current_frame = han.wt.vid[:,:,han.frame]

    adjust_contrast_gui(han)

    han.track_attempt=0 #Reset

    nothing
end

function delete_cb(w::Ptr,user_data::Tuple{Tracker_Handles})

    han, = user_data

    han.tracked[han.frame]=false
    han.current_frame = han.wt.vid[:,:,han.frame]
    plot_image(han,han.current_frame')

    nothing
end

function erase_cb(w::Ptr,user_data::Tuple{Tracker_Handles})

    han, = user_data

    han.erase_mode = getproperty(han.erase_button,:active,Bool)

    nothing
end

function draw_cb(w::Ptr,user_data::Tuple{Tracker_Handles})

    han, = user_data

    han.draw_mode = getproperty(han.draw_button,:active,Bool)

    nothing
end

function combine_cb(w::Ptr,user_data::Tuple{Tracker_Handles})

    han, = user_data

    han.combine_mode = getproperty(han.manual_widgets.combine_button,:active,Bool)

    nothing
end

function plot_image(han,img)

   ctx=Gtk.getgc(han.c)

    w,h = size(img)

    for i=1:length(img)
       han.plot_frame[i] = (convert(UInt32,img[i]) << 16) | (convert(UInt32,img[i]) << 8) | img[i]
    end
    stride = Cairo.format_stride_for_width(Cairo.FORMAT_RGB24, w)
    @assert stride == 4*w
    surface_ptr = ccall((:cairo_image_surface_create_for_data,Cairo._jl_libcairo),
                Ptr{Void}, (Ptr{Void},Int32,Int32,Int32,Int32),
                han.plot_frame, Cairo.FORMAT_RGB24, w, h, stride)

    ccall((:cairo_set_source_surface,Cairo._jl_libcairo), Ptr{Void},
    (Ptr{Void},Ptr{Void},Float64,Float64), ctx.ptr, surface_ptr, 0, 0)

    rectangle(ctx, 0, 0, w, h)

    fill(ctx)

    draw_touch(han)

    #If this frame is in the frame list, draw a box around the display
    if !isempty(find(han.frame_list.==han.displayed_frame))
        set_source_rgb(ctx,0,1,0)
        rectangle(ctx, 0, 0, w, h)
        stroke(ctx)
    end

    if han.view_pad
        set_source_rgb(ctx,0,0,1)
        arc(ctx, han.wt.pad_pos[1],han.wt.pad_pos[2], 10, 0, 2*pi);
        stroke(ctx)
    end

    if han.view_roi
        set_source_rgb(ctx,0,0,1)
        arc(ctx, han.wt.pad_pos[1],han.wt.pad_pos[2], 100, 0, 2*pi);
        stroke(ctx)
    end

    if han.view_pole
        if han.pole_present[han.frame]
            set_source_rgb(ctx,0,0,1)
            arc(ctx,han.pole_loc[han.frame,1],han.pole_loc[han.frame,2],10,0,2*pi)
            stroke(ctx)
        end
    end

    reveal(han.c)
end

#=
Clicking on the GUI for interaction
Different functionality depending on the mode
Mode 1 = Select Whisker
Mode 2 = Erase Mode
Mode 3 = Draw Mode
Mode 4 = Select Single Point
Mode 5 =

Mode 10 = Select Whisker Pad
Mode 11 = Select ROI
Mode 12 = Select Pole

=#

function whisker_select_cb(widget::Ptr,param_tuple,user_data::Tuple{Tracker_Handles})

    han, = user_data

    event = unsafe_load(param_tuple)

    m_x = event.x
    m_y = event.y

    if han.selection_mode==1

        #Find whisker of interest (nearest to selection)
        for i=1:length(han.wt.whiskers)
            for j=1:han.wt.whiskers[i].len
                if (m_x>han.wt.whiskers[i].x[j]-5.0)&(m_x<han.wt.whiskers[i].x[j]+5.0)
                    if (m_y>han.wt.whiskers[i].y[j]-5.0)&(m_y<han.wt.whiskers[i].y[j]+5.0)
                        han.woi_id = i
                        han.tracked[han.frame]=true
                        assign_woi(han)
                        break
                    end
                end
            end
        end
    end

    if han.selection_mode == 10 #whisker pad select
        try
            select_whisker_pad(han,m_x,m_y)
            redraw_all(han)
        catch
            println("Could not select whisker pad")
        end
    elseif han.selection_mode == 12
        try
            select_pole_location(han,m_x,m_y)
            redraw_all(han)
        catch
            println("Could not select pole")
        end
    end

    if han.erase_mode
        erase_start(han,m_x,m_y)
    elseif han.draw_mode
        draw_start(han,m_x,m_y)
    elseif han.combine_mode>0
        try
            if han.combine_mode == 1
                combine_start(han,m_x,m_y)
            else
                combine_end(han,m_x,m_y)
            end
        catch
            println("Could not combine whiskers")
        end
    else
        #plot_whiskers(han)
        redraw_all(han)
    end

    nothing
end

function select_whisker_pad(han,x,y)

    han.wt.pad_pos=(x,y)

    redraw_all(han)

end

function select_pole_location(han,x,y)

    han.pole_present[han.frame] = true
    han.pole_loc[han.frame,1] = x
    han.pole_loc[han.frame,2] = y

    redraw_all(han)
end

function combine_start(han,x,y)

    println("start")
    han.partial = deepcopy(han.wt.whiskers[han.woi_id])
    han.combine_mode = 2

    nothing
end

ccw(x1,x2,x3,y1,y2,y3)=(y3-y1) * (x2-x1) > (y2-y1) * (x3-x1)

function intersect(x1,x2,x3,x4,y1,y2,y3,y4)
    (ccw(x1,x3,x4,y1,y3,y4) != ccw(x2,x3,x4,y2,y3,y4))&&(ccw(x1,x2,x3,y1,y2,y3) != ccw(x1,x2,x4,y1,y2,y4))
end

function combine_end(han,x,y)

    out1=1
    out2=1

    for i=2:han.partial.len
        for j=2:han.wt.whiskers[han.woi_id].len
            if intersect(han.partial.x[i-1],han.partial.x[i],han.wt.whiskers[han.woi_id].x[j-1],
            han.wt.whiskers[han.woi_id].x[j],han.partial.y[i-1],han.partial.y[i],
            han.wt.whiskers[han.woi_id].y[j-1],han.wt.whiskers[han.woi_id].y[j])
                out1=i
                out2=j
                break
            end
        end
    end

    if out1==1
        println("No intersection found, looking for closest match")

        for i=2:han.partial.len
            for j=2:han.wt.whiskers[han.woi_id].len
                if sqrt((han.partial.x[i]-han.wt.whiskers[han.woi_id].x[j]).^2+(han.partial.y[i]-han.wt.whiskers[han.woi_id].y[j]).^2)<2.0
                    out1=i
                    out2=j
                    break
                end
            end
        end
    end

    if out1>1
        println("Segments combined")
        new_x = [han.wt.whiskers[han.woi_id].x[1:out2]; han.partial.x[out1:end]]
        new_y = [han.wt.whiskers[han.woi_id].y[1:out2]; han.partial.y[out1:end]]
        new_scores = [han.wt.whiskers[han.woi_id].scores[1:out2]; han.partial.scores[out1:end]]
        new_thick = [han.wt.whiskers[han.woi_id].thick[1:out2]; han.partial.thick[out1:end]]
        han.woi[han.frame].x=new_x
        han.woi[han.frame].y=new_y
        han.woi[han.frame].thick=new_thick
        han.woi[han.frame].scores=new_scores
        han.woi[han.frame].len = length(new_thick)

        if han.discrete_auto_calc
            make_discrete(han.wt.w_p,han.frame,han.woi[han.frame],han.d_spacing)
        end
    else
        println("No intersection found")
    end

    han.combine_mode = 1
    redraw_all(han)

    nothing
end

function draw_start(han,x,y)

    plot_image(han,han.current_frame')
    r = Gtk.getgc(han.c)
    Cairo.save(r)
    ctxcopy = copy(r)

    #
    if han.tracked[han.frame] == false
        new_whisker=Whisker1()

        push!(new_whisker.x,han.woi[han.frame-1].x[end])
        push!(new_whisker.y,han.woi[han.frame-1].y[end])
        push!(new_whisker.scores,han.woi[han.frame-1].scores[end])
        push!(new_whisker.thick,han.woi[han.frame-1].thick[end])

        new_whisker.len=1

        han.wt.whiskers=[new_whisker]

        han.woi_id = 1
    end

    plot_whiskers(han)

    push!((han.c.mouse, :button1motion),  (c, event) -> draw_move(han, event.x, event.y, ctxcopy))
    push!((han.c.mouse, :motion), Gtk.default_mouse_cb)
    push!((han.c.mouse, :button1release), (c, event) -> draw_stop(han, event.x, event.y, ctxcopy))

    nothing
end

function draw_move(han, x,y,ctxcopy)

    r=Gtk.getgc(han.c)

    han.wt.whiskers[han.woi_id].len+=1

    front_dist = (han.wt.whiskers[han.woi_id].x[1]-x)^2+(han.wt.whiskers[han.woi_id].y[1]-y)^2
    end_dist = (han.wt.whiskers[han.woi_id].x[end]-x)^2+(han.wt.whiskers[han.woi_id].y[end]-y)^2

    if end_dist<front_dist #drawing closer to end

        push!(han.wt.whiskers[han.woi_id].x,x)
        push!(han.wt.whiskers[han.woi_id].y,y)
        push!(han.wt.whiskers[han.woi_id].thick,1.0)
        push!(han.wt.whiskers[han.woi_id].scores,1.0)

    else
        unshift!(han.wt.whiskers[han.woi_id].x,x)
        unshift!(han.wt.whiskers[han.woi_id].y,y)
        unshift!(han.wt.whiskers[han.woi_id].thick,1.0)
        unshift!(han.wt.whiskers[han.woi_id].scores,1.0)
    end

    #redraw whisker
    set_source(r,ctxcopy)
    paint(r)

    plot_whiskers(han)

    nothing
end

function draw_stop(han,x,y,ctxcopy)

    assign_woi(han)
    han.tracked[han.frame]=true

    pop!((han.c.mouse, :button1motion))
    pop!((han.c.mouse, :motion))
    pop!((han.c.mouse, :button1release))

    nothing
end

function erase_start(han,x,y)

    plot_image(han,han.current_frame')
    r = Gtk.getgc(han.c)
    Cairo.save(r)
    ctxcopy = copy(r)

    plot_whiskers(han)

    push!((han.c.mouse, :button1motion),  (c, event) -> erase_move(han, event.x, event.y, ctxcopy))
    push!((han.c.mouse, :motion), Gtk.default_mouse_cb)
    push!((han.c.mouse, :button1release), (c, event) -> erase_stop(han, event.x, event.y, ctxcopy))

    nothing
end

function erase_move(han, x,y,ctxcopy)

    r=Gtk.getgc(han.c)

    #check for whisker overlap and erase points that are overlapping
    keep=trues(han.wt.whiskers[han.woi_id].len)
    for i=1:han.wt.whiskers[han.woi_id].len
        if (x+5.0>han.wt.whiskers[han.woi_id].x[i])&(x-5.0<han.wt.whiskers[han.woi_id].x[i])
            if (y+5.0>han.wt.whiskers[han.woi_id].y[i])&(y-5.0<han.wt.whiskers[han.woi_id].y[i])
                keep[i]=false
            end
        end
    end

    if length(find(keep.==false))>0
        keep[1:findfirst(keep.==false)] .= false
    end

    han.wt.whiskers[han.woi_id].x=han.wt.whiskers[han.woi_id].x[keep]
    han.wt.whiskers[han.woi_id].y=han.wt.whiskers[han.woi_id].y[keep]
    han.wt.whiskers[han.woi_id].thick=han.wt.whiskers[han.woi_id].thick[keep]
    han.wt.whiskers[han.woi_id].scores=han.wt.whiskers[han.woi_id].scores[keep]

    han.wt.whiskers[han.woi_id].len=length(han.wt.whiskers[han.woi_id].x)

    #redraw whisker
    set_source(r,ctxcopy)
    paint(r)

    plot_whiskers(han)

    nothing
end

function erase_stop(han,x,y,ctxcopy)

    assign_woi(han)

    pop!((han.c.mouse, :button1motion))
    pop!((han.c.mouse, :motion))
    pop!((han.c.mouse, :button1release))

    nothing
end

function trace_cb(w::Ptr,user_data::Tuple{Tracker_Handles})

    han, = user_data

    try

        if han.background_mode
            subtract_background(han)
        end
        if han.sharpen_mode
            sharpen_image(han)
        end
        if han.local_contrast_mode
            han.current_frame = round.(UInt8,local_contrast_enhance(han.current_frame))
        end
        if han.anisotropic_mode
            myimg=convert(Array{Float64,2},han.current_frame)
            han.current_frame = round.(UInt8,anisodiff(myimg,20,20.0,0.05,1))
        end
        han.send_frame[:,:] = han.current_frame'
        han.wt.whiskers=WT_trace(han.frame,han.send_frame,han.wt.min_length,han.wt.pad_pos,han.wt.mask)

        plot_image(han,han.current_frame')
        #WT_constraints(han)

        plot_whiskers(han)

    catch
        println("Could not perform tracing")
    end

    nothing
end


function WT_constraints(han)

    #get_follicle average
    (fx,fy)=get_follicle(han)
    #Find most similar whisker follicle position
    #=
    if length(han.wt.whiskers)>0
        min_dist = sqrt((han.wt.whiskers[1].x[end]-fx)^2+(han.wt.whiskers[1].y[end]-fy)^2)
        han.woi_id = 1
        for i=2:length(han.wt.whiskers)
            mydist = sqrt((han.wt.whiskers[i].x[end]-fx)^2+(han.wt.whiskers[i].y[end]-fy)^2)
            if mydist<min_dist
                min_dist = mydist
                han.woi_id = i
            end
        end
    else
        min_dist=100.0
    end
    =#
    use_both = false
    if (length(han.wt.whiskers)>0)&(han.frame>2)
        #If the previous frame was tracked, compare this frame with the previous
        if han.tracked[han.frame-1]
            (mincor, w_id) = whisker_similarity(han,1)
            use_both = true
        elseif han.tracked[han.frame-2] #if the previous frame wasn't tracked, go back two frames
            (mincor, w_id) = whisker_similarity(han,2)
            use_both = true
        else
            w_id =0
        end
        if w_id !=0
            han.woi_id = w_id
            min_dist = sqrt((han.wt.whiskers[w_id].x[end]-fx)^2+(han.wt.whiskers[w_id].y[end]-fy)^2)
        else
            min_dist=100.0
        end
    else
        min_dist=100.0
    end

    #Whisker should not move more than 0.64 mm / ms  (1.28 mm / 2ms)
    # If about 0.07 mm / pixel or about 20 pixels
    #If we don't have a whisker with this criteria met, adjust paramters
    #and try again
    if (!han.tracked[han.frame])
        if (use_both)
            if ((mincor<15.0)&(min_dist < 20.0))|(mincor<han.cor_thres)
                han.tracked[han.frame]=true
                assign_woi(han)
            end
        else
            if (min_dist <10.0)
                han.tracked[han.frame]=true
                assign_woi(han)
            end
        end
    end

    if !han.tracked[han.frame]
        han.stop_flag = true
    end
    #=
    if !han.tracked[han.frame]
        han.track_attempt+=1
        if han.track_attempt==1
            subtract_background(han)
            WT_trace(han.wt,han.frame,han.current_frame')
            WT_constraints(han)
        elseif han.track_attempt==2
            sharpen_image(han)
            plot_(han.wt,han.frame,han.current_frame')
            WT_constraints(han)
        else #tried lots of tricks, and still didn't work
            #if min_dist <20.0
                #han.tracked[han.frame]=true
                #han.woi[han.frame]=deepcopy(han.wt.whiskers[han.woi_id])
            #end
        end

            #Tracking Statistics
            println("Frame number: ", han.frame, " Distance: ", min_dist)
            println("Track attempt: ", han.track_attempt)
    end
    =#

    if han.tracked[han.frame]
        detect_touch(han)
    end

    nothing
end

function plot_whiskers(han::Tracker_Handles)

    ctx=Gtk.getgc(han.c)

    for w=1:length(han.wt.whiskers)

        set_source_rgb(ctx,0.0,0.0,1.0)

        move_to(ctx,han.wt.whiskers[w].x[1],han.wt.whiskers[w].y[1])
        for i=2:han.wt.whiskers[w].len
            line_to(ctx,han.wt.whiskers[w].x[i],han.wt.whiskers[w].y[i])
        end
        stroke(ctx)
    end

    if (han.tracked[han.frame])&(han.frame_list[han.frame]==han.displayed_frame)
        set_source_rgb(ctx,1.0,0.0,0.0)

        move_to(ctx,han.woi[han.frame].x[1],han.woi[han.frame].y[1])
        for i=2:han.woi[han.frame].len
            line_to(ctx,han.woi[han.frame].x[i],han.woi[han.frame].y[i])
        end
        stroke(ctx)

        if han.discrete_draw
            draw_discrete(han)
        end

    end

    if han.show_tracked
        draw_tracked_whisker(han)
    end

    reveal(han.c)

    nothing
end
