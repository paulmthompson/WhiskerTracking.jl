
export make_gui

function make_gui()

    name=""
    path=""
    vid_name = ""

    max_frames = 2
    vid_length = 1
    frame_list = [1]
    start_frame = 1

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

    load_video_ = MenuItem("Load Video")
    push!(sortmenu,load_video_)

    load_dlc_whiskers_ = MenuItem("Load DLC Tracked Whiskers")
    push!(sortmenu,load_dlc_whiskers_)

    save_whisk_ = MenuItem("Save Whiskers")
    #push!(sortmenu,save_whisk_)
    load_whisk_ = MenuItem("Load Whiskers")
    #push!(sortmenu,load_whisk_)

    load_previous_ = MenuItem("Load Previous Tracking Frames")
    push!(sortmenu,load_previous_)

    export_menu_ = MenuItem("Export...")
    push!(sortmenu,export_menu_)

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

    dl_menu_ = MenuItem("Deep Learning")
    push!(extramenu,dl_menu_)

    push!(mb,extraopts)

    imageopts = MenuItem("_Image")
    imagemenu = Menu(imageopts)
    crop_menu_ = MenuItem("Crop")
    push!(imagemenu,crop_menu_)

    image_adjust_menu_ = MenuItem("Image Adjustment")
    push!(imagemenu,image_adjust_menu_)

    push!(mb,imageopts)

    contactopts = MenuItem("_Contact Detection")
    contactmenu = Menu(contactopts)

    labelopts = MenuItem("_Training Labels")
    push!(contactmenu,labelopts)
    labelmenu = Menu(labelopts)

    save_contact_ = MenuItem("Save Contact Labels")
    push!(labelmenu,save_contact_)
    load_contact_ = MenuItem("Load Contact Labels")
    push!(labelmenu,load_contact_)

    predopts = MenuItem("_Predicted Labels")
    push!(contactmenu,predopts)
    label_pred_menu = Menu(predopts)

    load_pred_labels = MenuItem("Load Predicted Labels")
    push!(label_pred_menu,load_pred_labels)

    classifier_ = MenuItem("Classifier for Prediction")
    push!(contactmenu,classifier_)

    push!(mb,contactopts)

    otheropts = MenuItem("_Other Programs")
    othermenu = Menu(otheropts)
    janelia_menu_ = MenuItem("Janelia Tracker")
    push!(othermenu,janelia_menu_)
    dlc_menu_ = MenuItem("DeepLabCut")
    push!(othermenu,dlc_menu_)

    push!(mb,otheropts)

    grid[1,1] = mb

    #Menu for discrete points
    d_widgets = _make_discrete_gui()

    #Mask Menu Widgets
    m_widgets = _make_mask_gui()

    #Pad Menu Widgets
    p_widgets=_make_pad_gui()

    #ROI Menu Widgets
    r_widgets =  _make_roi_gui()

    #Pole Menu Widgets
    pp_widgets = _make_pole_gui()

    #View Window
    v_widgets = _make_view_gui()

    #Manual Tracing Menu
    man_widgets = _make_tracing_gui()

    #Image adjustment window
    ia_widgets = _make_image_gui()

    #Menu for Janelia Tracker Parameter Tweaking
    j_widgets = _make_janelia_gui()

    #DeepLabCut options
    deep_widgets = _make_dlc_gui()

    #Export options
    e_widgets = _make_export_gui()

    #contact options
    c_widgets = _make_contact_gui()

    dl_widgets = _make_deeplearning_gui()

    win = Window(grid, "Whisker Tracker") |> Gtk.showall

    all_whiskers=[Array{Whisker1,1}() for i=1:vid_length]

    tracker_name = (vid_name)[1:(end-4)]

    wt=Tracker(path,name,vid_name,path,tracker_name,50,falses(480,640),Array{Whisker1,1}(),
    (0.0,0.0),255,0,all_whiskers,zeros(Float32,10,vid_length))

    if VERSION > v"0.7-"
        woi_array = Array{Whisker1,1}(undef,vid_length)
    else
        woi_array = Array{Whisker1,1}(vid_length)
    end

    these_paths = Save_Paths("",false)

    handles = Tracker_Handles(1,vid_length,max_frames,win,c,frame_slider,adj_frame,trace_button,zeros(UInt32,640,480),
    zeros(UInt8,480,640),zeros(UInt8,640,480),0,woi_array,1,num_whiskers_sb,1,
    false,erase_button,false,0,falses(vid_length),
    delete_button,0,Whisker1(),false,
    start_frame,false,false,false,draw_button,false,false,touch_override,touch_no_contact,false,
    falses(0),Array{Int64,1}(),zeros(Float64,vid_length),zeros(Float64,vid_length),
    wt,5.0,false,true,true,2,ts_canvas,frame_list,frame_advance_sb,1,d_widgets,m_widgets,p_widgets,
    r_widgets,pp_widgets,v_widgets,man_widgets,ia_widgets,j_widgets,deep_widgets,e_widgets,
    c_widgets,dl_widgets,falses(vid_length),zeros(Float32,vid_length,2),zeros(UInt8,640,480),false,false,false,1,
    false,zeros(Float64,1,1),zeros(Float64,1,1),falses(1,1),false,falses(1),
    zeros(Float64,1,1),classifier(),NeuralNetwork(),these_paths,zeros(UInt8,640,480))

    signal_connect(frame_slider_cb, frame_slider, "value-changed", Void, (), false, (handles,))
    signal_connect(frame_select, frame_advance_sb, "value-changed", Void, (), false, (handles,))
    signal_connect(trace_cb,trace_button, "clicked", Void, (), false, (handles,))

    signal_connect(erase_cb,erase_button, "clicked",Void,(),false,(handles,))
    signal_connect(whisker_select_cb,c,"button-press-event",Void,(Ptr{Gtk.GdkEventButton},),false,(handles,))
    signal_connect(delete_cb,delete_button, "clicked",Void,(),false,(handles,))


    signal_connect(advance_slider_cb,win,"key-press-event",Void,(Ptr{Gtk.GdkEventKey},),false,(handles,))
    signal_connect(draw_cb,draw_button,"clicked",Void,(),false,(handles,))

    signal_connect(touch_override_cb,touch_override,"clicked",Void,(),false,(handles,1))
    signal_connect(touch_override_cb,touch_no_contact,"clicked",Void,(),false,(handles,0))

    signal_connect(add_frame_cb,add_frame_button,"clicked",Void,(),false,(handles,))
    signal_connect(delete_frame_cb,delete_frame_button,"clicked",Void,(),false,(handles,))

    signal_connect(num_whiskers_cb,num_whiskers_sb,"value-changed",Void,(),false,(handles,))

    #File Callbacks
    signal_connect(load_video_cb, load_video_, "activate",Void,(),false,(handles,))
    signal_connect(load_dlc_tracked_cb,load_dlc_whiskers_,"activate",Void,(),false,(handles,))
    signal_connect(load_previous_cb,load_previous_,"activate",Void,(),false,(handles,))
    signal_connect(save_cb, save_whisk_, "activate",Void,(),false,(handles,))
    signal_connect(load_cb, load_whisk_, "activate",Void,(),false,(handles,))
    signal_connect(save_contact_cb,save_contact_,"activate",Void,(),false,(handles,))
    signal_connect(load_contact_cb,load_contact_,"activate",Void,(),false,(handles,))

    #Discrete Callbacks
    make_menu_callbacks(discrete_menu_,d_widgets.win)
    add_discrete_callbacks(d_widgets,handles)

    #Mask Callbacks
    make_menu_callbacks(mask_menu_,m_widgets.win)
    add_mask_callbacks(m_widgets,handles)

    #Pad Callbacks
    make_menu_callbacks(pad_menu_,p_widgets.win)
    add_pad_callbacks(p_widgets,handles)

    #ROI Callbacks
    make_menu_callbacks(roi_menu_,r_widgets.win)

    #Pole Callbacks
    make_menu_callbacks(pole_menu_,pp_widgets.win)
    add_pole_callbacks(pp_widgets,handles)

    #View Callbacks
    make_menu_callbacks(view_menu_,v_widgets.win)
    add_view_callbacks(v_widgets,handles)

    #Tracing Callbacks
    make_menu_callbacks(manual_menu_,man_widgets.win)
    add_tracing_callbacks(man_widgets,handles)

    #Image Adjustment Callbacks
    make_menu_callbacks(image_adjust_menu_,ia_widgets.win)
    add_image_callbacks(ia_widgets,handles)

    #Janelia Tweaking Callbacks
    make_menu_callbacks(janelia_menu_,j_widgets.win)
    add_janelia_callbacks(j_widgets,handles)

    #DLC Callbacks
    make_menu_callbacks(dlc_menu_,deep_widgets.win)
    add_dlc_callbacks(deep_widgets,handles)

    #Export
    make_menu_callbacks(export_menu_,e_widgets.win)
    add_export_callbacks(e_widgets,handles)

    #Contact
    make_menu_callbacks(classifier_,c_widgets.win)
    add_contact_callbacks(c_widgets,handles)

    #Deep learning
    make_menu_callbacks(dl_menu_,dl_widgets.win)
    add_deeplearning_callbacks(dl_widgets,handles)

    handles
end

function make_menu_callbacks(menu,win)

    signal_connect((widget,w)->visible(w[1],true),menu,"activate",Void,(),false,(win,))
    signal_connect(win, :delete_event) do widget, event
        visible(win, false)
        true
    end
end

function redraw_all(han::Tracker_Handles)
    plot_image(han,han.current_frame')
    plot_whiskers(han)
end

function determine_viewers(han::Tracker_Handles)

    han.view_pad = getproperty(han.view_widgets.whisker_pad_button,:active,Bool)
    han.view_roi = getproperty(han.view_widgets.roi_button,:active,Bool)
    han.view_pole = getproperty(han.view_widgets.pole_button,:active,Bool)
    han.discrete_draw = getproperty(han.view_widgets.discrete_button,:active,Bool)

    nothing
end

function load_video_cb(w::Ptr,user_data::Tuple{Tracker_Handles})

    han, = user_data

    filepath = open_dialog("Load Whisker Tracking",han.win)

    if filepath != ""

        (path,vid_title) = splitdir(filepath)
        load_video_to_gui(string(path,"/"),vid_title,han)
    end
    nothing
end

function load_video_to_gui(path::String,vid_title::String,handles::Tracker_Handles;frame_range = (false,0.0,0),image_stack=false,dynamic_load=true)

    name=""
    vid_name = string(path,vid_title)

    if (dynamic_load)
        #load first frame
        temp=zeros(UInt8,640,480)
        frame_time = 1  /  25 #Number of frames in a second of video
        try
            load_single_frame(frame_time,temp,vid_name)
        catch
        end
        vid_length = 1
        frame_list=[1]
        start_frame=1
    else
        #=
        if !image_stack
            (vid,start_frame,vid_length)=load_video(vid_name,frame_range)
            frame_list=Array{Int64,1}()
        else
            (vid,start_frame,vid_length,frame_list)=load_image_stack(string(path,name))
        end
        =#
    end

    handles.max_frames = get_max_frames(vid_name)

    #Adjust Frame Slider Scale
    Gtk.GAccessor.range(handles.frame_slider,1,handles.max_frames)

    all_whiskers=[Array{Whisker1,1}() for i=1:vid_length]

    tracker_name = (vid_name)[1:(end-4)]

    handles.wt=Tracker(path,name,vid_name,path,tracker_name,50,falses(480,640),Array{Whisker1,1}(),
    (0.0,0.0),255,0,all_whiskers,zeros(Float32,10,vid_length))

    #Update these paths
    date_folder=Dates.format(now(),"yyyy-mm-dd-HH-MM-SS")

    t_folder = string(path,date_folder)

    these_paths = Save_Paths(t_folder)
    handles.paths = these_paths

    save_single_image(handles,temp',1)

    handles.current_frame=temp'
    handles.current_frame2=deepcopy(handles.current_frame)
    redraw_all(handles)

    nothing
end

function load_dlc_tracked_cb(w::Ptr,user_data::Tuple{Tracker_Handles})

    han, = user_data

    try
        filepath = open_dialog("Load DLC Whisker File",han.win)

        if filepath != ""
            (xxx,yyy,lll)=dlc_hd5_to_array(filepath,0.2,true);
            dlc_smooth_liklihood(xxx,yyy,15,lll,50.0)
            han.tracked_whiskers_x=xxx
            han.tracked_whiskers_y=yyy
            han.tracked_whiskers_l=lll;
        end
    catch
        println("Could not load whiskers")
    end

    nothing
end

function get_max_frames(vid_name::String)

    yy=read(`$(ffprobe_path) -v error -select_streams v:0 -show_entries stream=nb_frames -of default=nokey=1:noprint_wrappers=1 $(vid_name)`)
    if is_windows()
        max_frames=parse(Int64,String(yy[1:(end-2)]))
    else
        max_frames=parse(Int64,String(yy[1:(end-1)]))
    end

    max_frames
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
    frame_time = han.displayed_frame  /  25 #Number of frames in a second of video
    try
        load_single_frame(frame_time,han.temp_frame,han.wt.vid_name)
        han.current_frame=han.temp_frame'
        han.current_frame2=deepcopy(han.current_frame)
        redraw_all(han)
    catch
    end

    nothing
end

function load_single_frame(x::Float64,tt::AbstractArray{UInt8,2},vn::String)


    xx=open(`$(ffmpeg_path) -loglevel panic -ss $(x) -i $(vn) -f image2pipe -vcodec rawvideo -pix_fmt gray -`);
    if VERSION > v"0.7-"
        read!(xx,tt)
    else
        read!(xx[1],tt)
    end

    nothing
end

function draw_frame_list(han::Tracker_Handles)

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

function load_previous_cb(w::Ptr,user_data::Tuple{Tracker_Handles})

    han, = user_data

    config_path = open_dialog("Load Previous DLC session",han.win)

    if config_path != ""

        change_save_paths(han,config_path)
        han.dlc.config_path = config_path
        try
            load_label_data(han,config_path)
        catch
            println("Could not load labeled data")
        end

        update_discrete(han)

        println("Previous Session Loaded")
    end

    nothing
end

function update_discrete(han::Tracker_Handles)

    w_p = deepcopy(han.wt.w_p)

    num_discrete=div(size(w_p,1),2)
    setproperty!(han.d_widgets.points_button,:value,num_discrete)

    d_spacing = 0.0
    num=0
    wp_x = 0.0
    wp_y = 0.0
    for i=1:size(w_p,2)
        d=sqrt((w_p[3,i] - w_p[1,i]) ^2 + (w_p[4,i] - w_p[2,i]) ^2)
        if !isnan(d)
            d_spacing += d
            num += 1
            wp_x += w_p[1,i]
            wp_y += w_p[2,i]
        end
    end

    han.d_spacing = round(Int64,d_spacing / num)
    setproperty!(han.d_widgets.space_button,:value,han.d_spacing)

    han.wt.pad_pos = (convert(Float32,wp_x/num),convert(Float32,wp_y/num))

    han.wt.w_p = w_p

    nothing
end

function load_label_data(han::Tracker_Handles,config_path::String)

    label_path=get_label_path_from_config(config_path)

    (w_p,frame_list)=load_labels(label_path)

    #If one of the whiskers doesn't exist, delete it
    keep = trues(length(frame_list))
    for i=1:length(frame_list)
        if all(isnan.(w_p[:,i]))
            keep[i] = false
        end
    end

    frame_list = frame_list[keep]
    w_p = w_p[:,keep]
    han.wt.w_p = w_p
    han.frame_list = frame_list

    #Change frame list spin button maximum number and current index
    Gtk.GAccessor.range(han.frame_advance_sb,1,length(han.frame_list))

    #add whisker WOI
    han.woi=[Whisker1() for i=1:length(frame_list)]
    for i=1:length(frame_list)
        x=reverse(han.wt.w_p[1:2:(end-1),i])
        y=reverse(han.wt.w_p[2:2:end,i])
        x=x[.!isnan.(x)]
        y=y[.!isnan.(y)]
        if length(x) != length(y)
            println("Error")
        end

        (xx,yy) = get_woi_x_y(x,y,5.0,(x[end],y[end]))

        n_points=length(xx)

        han.woi[i] = Whisker1(1,han.frame_list[i],n_points,xx,yy,zeros(Float32,n_points),zeros(Float32,n_points))
    end

    han.wt.all_whiskers = [Array{Whisker1,1}() for i=1:length(frame_list)]
    for i=1:length(frame_list)
        han.wt.all_whiskers[i] = [deepcopy(han.woi[i])]
    end

    han.tracked = trues(length(frame_list))
    han.woi_angle = zeros(Float64,length(frame_list))
    han.woi_curv = zeros(Float64,length(frame_list))

    han.pole_present = zeros(Float64,length(frame_list))

    han.pole_loc = zeros(Float32,length(frame_list),2)

    nothing
end

function get_label_path_from_config(config_path::String)

    dlc_folder_path = dirname(config_path)

    label_dir=string(dlc_folder_path,"/labeled-data")

    vid_dir=string(label_dir,"/",readdir(label_dir)[1])

    label_path=string(vid_dir,"/",filter(x->occursin(".h5",x), readdir(vid_dir))[1])
end

function load_labels(label_path::String)
    myfile=h5open(label_path)
    mytable=read(myfile,"df_with_missing")["table"]

    d_points_length=length(mytable[1].data[2])-2 #subtract pole

    frame_num=length(mytable)

    w_p=zeros(Float32,d_points_length,frame_num)

    frame_list=zeros(Int64,frame_num)

    for i=1:frame_num
        for j=1:d_points_length
            w_p[j,i] = mytable[i].data[2][j]
        end
        frame_list[i] = parse(Int64,basename(mytable[i].data[1])[4:(end-4)])
    end

    close(myfile)

    #Check for duplicates. This can happen on windows with / \ confusion
    if length(unique(frame_list)) < length(frame_list)
        unique_inds=findfirst.(isequal.(unique(frame_list)), [frame_list])

        frame_list=unique(frame_list)
        w_p = w_p[:,unique_inds]
    end

    (w_p,frame_list)
end

function change_save_paths(han::Tracker_Handles,config_path::String)

    dlc_folder_path = dirname(config_path)

    save_folder_name=dirname(dirname(dlc_folder_path))

    han.paths=Save_Paths(save_folder_name,false)

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

            save_backup(han)

        end

    catch
        println("Could not add frame")
    end

    nothing
end

function save_backup(han::Tracker_Handles)

    #Read backup

    #Write backup
    file = matopen(string(han.paths.backup,"/backup.mat"), "w")
    write(file, "w_p", han.wt.w_p)
    write(file, "frame_list",han.frame_list)
    close(file)


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
            for i=1:length(mywhiskers)
                han.woi[mywhiskers[i].time] = deepcopy(mywhiskers[i])
            end
            han.tracked = mytracked
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

function frame_select(w::Ptr,user_data::Tuple{Tracker_Handles})

    han, = user_data

    han.frame = getproperty(han.frame_advance_sb,:value,Int64)
    setproperty!(han.adj_frame,:value,han.frame_list[han.frame])
    han.displayed_frame = han.frame_list[han.frame]

    frame_time = han.displayed_frame  /  25 #Number of frames in a second of video
    try
        load_single_frame(frame_time,han.temp_frame,han.wt.vid_name)
        han.current_frame=han.temp_frame'
        han.current_frame2=deepcopy(han.current_frame)
        redraw_all(han)
    catch

    end

    adjust_contrast_gui(han)

    han.track_attempt=0 #Reset

    nothing
end

function delete_cb(w::Ptr,user_data::Tuple{Tracker_Handles})

    han, = user_data

    han.tracked[han.frame]=false
    frame_time = han.displayed_frame  /  25 #Number of frames in a second of video
    try
        load_single_frame(frame_time,han.temp_frame,han.wt.vid_name)
        han.current_frame=han.temp_frame'
        han.current_frame2=deepcopy(han.current_frame)
        redraw_all(han)
    catch

    end

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


function plot_image(han::Tracker_Handles,img::AbstractArray{UInt8,2})

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
Mode 13 = Discrete Select
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
    elseif han.selection_mode == 13
        try
            add_discrete_point(han,m_x,m_y)
            redraw_all(han)
        catch
            println("Could not add point")
        end

    end

    if han.erase_mode
        erase_start(han,m_x,m_y)
    elseif han.draw_mode
        try
            draw_start(han,m_x,m_y)
        catch
            println("Drawing Failed")
        end
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

function select_whisker_pad(han::Tracker_Handles,x,y)

    han.wt.pad_pos=(x,y)

    redraw_all(han)

end

function select_pole_location(han::Tracker_Handles,x,y)

    han.pole_present[han.frame] = true
    han.pole_loc[han.frame,1] = x
    han.pole_loc[han.frame,2] = y

    redraw_all(han)
end


function draw_start(han::Tracker_Handles,x,y)

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

function draw_move(han::Tracker_Handles, x,y,ctxcopy)

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

function draw_stop(han::Tracker_Handles,x,y,ctxcopy)

    assign_woi(han)
    han.tracked[han.frame]=true

    pop!((han.c.mouse, :button1motion))
    pop!((han.c.mouse, :motion))
    pop!((han.c.mouse, :button1release))

    nothing
end

function erase_start(han::Tracker_Handles,x,y)

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

function erase_move(han::Tracker_Handles, x,y,ctxcopy)

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

function erase_stop(han::Tracker_Handles,x,y,ctxcopy)

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
