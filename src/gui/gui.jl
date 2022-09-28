
export make_gui

if Sys.iswindows()
    const glade_path = string(dirname(Base.source_path()),"\\whiskertracking.glade")
else
    const glade_path = string(dirname(Base.source_path()),"/whiskertracking.glade")
end

function make_gui()

    b = Builder(filename=glade_path)

    h=480
    w=640

    c=Canvas(w,h)
    c_box = b["canvas_box"]
    push!(c_box,c)

    c2=Canvas(w,20)
    push!(b["manual_box"],c2)

    #contact options
    c_widgets = _make_contact_gui()

    all_whiskers=[Array{Whisker1,1}() for i=1:1]

    wt=Tracker("","","","","",50,falses(h,w),Array{Whisker1,1}(),
    (0.0,0.0),h,w,all_whiskers)

    woi_array = Dict{Int64,WhiskerTracking.Whisker1}()

    these_paths = Save_Paths("",false)

    handles = Tracker_Handles(1,b,2,h,w,25.0,true,0,c,c2,
    zeros(UInt8,h,w),zeros(UInt8,w,h),0,woi_array,1,1,
    false,Dict{Int64,Bool}(),0,Whisker1(),false,
    wt,image_adjustment_settings(),zeros(Int64,0),1,
    c_widgets,Dict{Int64,Bool}(),Dict{Int64,Array{Float32,1}}(),zeros(UInt8,w,h),1,
    Tracked_Whisker(0),false,false,falses(1),false,false,falses(1),".",
    classifier(),Analog_Class(),Zoom_Class(),NeuralNetwork(),Manual_Class(),1,Array{Tuple{Float64,Float64},1}(),these_paths,zeros(UInt8,w,h),Draw_Area(w,h))
end

function add_callbacks(b::Gtk.GtkBuilder,handles::Tracker_Handles)

    signal_connect(frame_slider_cb, b["frame_slider"], "value-changed", Nothing, (), false, (handles,))
    signal_connect(trace_cb,b["trace_button"], "clicked", Nothing, (), false, (handles,))

    signal_connect(erase_cb,b["erase_button"], "clicked",Nothing,(),false,(handles,))
    signal_connect(whisker_select_cb,handles.c,"button-press-event",Nothing,(Ptr{Gtk.GdkEventButton},),false,(handles,))

    signal_connect(advance_slider_cb,b["win"],"key-press-event",Nothing,(Ptr{Gtk.GdkEventKey},),false,(handles,))
    signal_connect(advance_slider_cb_mouse,b["win"],"scroll-event",Nothing,(Ptr{Gtk.GdkEventScroll},),false,(handles,))

    signal_connect(draw_cb,b["draw_button"],"clicked",Nothing,(),false,(handles,))

    signal_connect(touch_override_cb,b["contact_button"],"clicked",Nothing,(),false,(handles,1))
    signal_connect(touch_override_cb,b["no_contact_button"],"clicked",Nothing,(),false,(handles,0))

    signal_connect(add_frame_cb,b["add_frame_button"],"clicked",Nothing,(),false,(handles,))
    signal_connect(delete_frame_cb,b["delete_frame_button"],"clicked",Nothing,(),false,(handles,))

    #signal_connect(num_whiskers_cb,b["num_whiskers_sb"],"value-changed",Nothing,(),false,(handles,))

    #File Callbacks
    signal_connect(load_video_cb, b["load_video_"], "activate",Nothing,(),false,(handles,))

    add_additional_callbacks(b,handles)
end

function add_additional_callbacks(b::Gtk.GtkBuilder,handles::Tracker_Handles)
    #Mask Callbacks
    make_menu_callbacks(b["mask_menu_"],b["mask_win"])
    add_mask_callbacks(b,handles)

    #Pad Callbacks
    make_menu_callbacks(b["pad_menu_"],b["pad_win"])
    add_pad_callbacks(b,handles)

    #Pole Callbacks
    make_menu_callbacks(b["pole_menu_"],b["pole_win"])
    add_pole_callbacks(b,handles)

    #View Callbacks
    make_menu_callbacks(b["view_menu_"],b["view_win"])
    add_view_callbacks(b,handles)

    #analog
    make_analog_gui(b,handles)
    make_menu_callbacks(b["analog_menu_"],b["analog_win"])
    add_analog_callbacks(b,handles)

    #Zoom
    make_zoom_gui(b,handles)
    make_menu_callbacks(b["zoom_menu_"],b["zoom_win"])
    add_zoom_callbacks(b,handles)

    #Tracing Callbacks
    make_menu_callbacks(b["manual_menu_"],b["tracing_win"])
    add_tracing_callbacks(b,handles)

    #Image Adjustment Callbacks
    make_menu_callbacks(b["image_adjust_menu_"],b["image_adjust_window"])
    add_image_callbacks(b,handles)

    #Export
    make_menu_callbacks(b["export_menu_"],b["export_win"])
    add_export_callbacks(b,handles)

    #Contact
    make_menu_callbacks(b["classifier_"],handles.contact_widgets.win)
    add_contact_callbacks(handles.contact_widgets,handles)

    make_menu_callbacks(b["contact_mark_"],b["contact_win"])
    add_contact_mark_callbacks(b,handles)

    #Deep learning
    make_menu_callbacks(b["dl_menu_"],b["deep_learning_win"])
    add_deeplearning_callbacks(b,handles)

    add_table_callbacks(b,handles)

    Gtk.showall(handles.b["win"])

    nothing
end

function make_menu_callbacks(menu::Gtk.GtkMenuItem,win::Gtk.GtkWindowLeaf)

    signal_connect(open_window_cb,menu,"activate",Nothing,(),false,(win,))
    signal_connect(delete_makes_invisible_cb,win,"delete-event",Nothing,(),false,())
end

function open_window_cb(w::Ptr,user_data)
    win, = user_data
    visible(win,true)
    nothing
end

function delete_makes_invisible_cb(w::Ptr,user_data)
    visible(convert(Window,w),false)
    nothing
end

function redraw_all(han::Tracker_Handles)
    plot_image(han,han.current_frame')
    plot_whiskers(han)
end

function load_video_cb(w::Ptr,user_data::Tuple{Tracker_Handles})

    han, = user_data

    filepath = open_dialog("Load Whisker Tracking",han.b["win"])

    if filepath != ""

        (path,vid_title) = splitdir(filepath)
        load_video_to_gui(string(path,"/"),vid_title,han)
    end
    nothing
end

#https://stackoverflow.com/questions/35414020/parse-input-to-rational-in-julia/35414995
function myparse(xx)
    ms,ns=split(xx,'/',keepempty=false)
    m=parse(Int,ms)
    n=parse(Int,ns)
    m/n
end

function get_vid_dims(vid_name::String)
    ww=@ffmpeg_env read(`$(FFMPEG.ffprobe) -v error -select_streams v:0 -show_entries stream=width -of default=nw=1:nk=1 $(vid_name)`)
    hh=@ffmpeg_env read(`$(FFMPEG.ffprobe) -v error -select_streams v:0 -show_entries stream=height -of default=nw=1:nk=1 $(vid_name)`)
    ff=@ffmpeg_env read(`$(FFMPEG.ffprobe) -v error -select_streams v -of default=noprint_wrappers=1:nokey=1 -show_entries stream=r_frame_rate $(vid_name)`)

    width=0
    height=0
    fps=0
    if is_windows()
        width=parse(Int64,String(ww[1:(end-2)]))
        height=parse(Int64,String(hh[1:(end-2)]))
        fps=myparse(String(ff[1:(end-2)]))
    else
        width=parse(Int64,String(ww[1:(end-1)]))
        height=parse(Int64,String(hh[1:(end-1)]))
        fps = myparse(String(ff[1:(end-1)]))
    end

    println("width = ", width)
    println("height = ", height)
    println("fps = ", fps)

    (width,height,fps)
end

function resize_for_video(han::Tracker_Handles,w,h,fps)

    han.wt.h = h
    han.wt.w = w
    han.wt.mask = falses(h,w)

    han.h = h
    han.w = w
    han.fps = fps

    han.draw_area = Draw_Area(w,h)

    han.current_frame = zeros(UInt8,h,w)
    han.current_frame2 = zeros(UInt8,w,h)

    han.send_frame = zeros(UInt8,w,h)
    han.temp_frame = zeros(UInt8,w,h)

    Gtk.GAccessor.size_request(han.c,w,h)

end

function load_video_to_gui(path::String,vid_title::String,handles::Tracker_Handles)

    vid_name = string(path,vid_title)

    #load first frame
    (width,height,fps)=get_vid_dims(vid_name)
    resize_for_video(handles,width,height,fps)
    temp=zeros(UInt8,width,height)
    frame_time = 1  /  fps #Number of frames in a second of video
    try
        load_single_frame(frame_time,temp,vid_name)
    catch
    end

    handles.max_frames = get_max_frames(vid_name)

    handles.man=Manual_Class(handles.max_frames)

    handles.tracked_contact = falses(handles.max_frames)

    #Adjust Frame Slider Scale
    set_gtk_property!(handles.b["adj_frame"],:upper,handles.max_frames)

    all_whiskers=[Array{Whisker1,1}() for i=1:1]
    handles.tracked_w = Tracked_Whisker(handles.max_frames)

    tracker_name = (vid_name)[1:(end-4)]

    handles.wt=Tracker(path,"",vid_name,path,tracker_name,50,falses(height,width),Array{Whisker1,1}(),
    (0.0,0.0),height,width,all_whiskers)

    #Update these paths
    date_folder=Dates.format(now(),"yyyy-mm-dd-HH-MM-SS")

    t_folder = string(path,date_folder)

    these_paths = Save_Paths(t_folder)
    handles.paths = these_paths

    #save_single_image(handles,temp',1)

    handles.current_frame[:]=temp'
    handles.current_frame2[:]=handles.current_frame
    redraw_all(handles)

    nothing
end

function get_max_frames(vid_name::String)

    yy=@ffmpeg_env read(`$(FFMPEG.ffprobe) -v error -select_streams v:0 -show_entries stream=nb_frames -of default=nokey=1:noprint_wrappers=1 $(vid_name)`)
    if is_windows()
        max_frames=parse(Int64,String(yy[1:(end-2)]))
    else
        max_frames=parse(Int64,String(yy[1:(end-1)]))
    end

    max_frames
end

#=
Frame Drawing
=#
function frame_slider_cb(w::Ptr,user_data)

    han, = user_data

    sleep(0.002) #make sure that asynchronous tasks arrive in order

    @async update_new_frame(han)

    nothing
end

function update_new_frame(han)

    han.requested_frame = round(Int,get_gtk_property(han.b["adj_frame"],:value,Int))

    #If equal to frame we already acquired, don't get it again
    if han.frame_loaded == true

        han.frame_loaded = false

        han.displayed_frame = round(Int,get_gtk_property(han.b["adj_frame"],:value,Int))

        #Reset array of displayed whiskers
        han.wt.whiskers=Array{Whisker1,1}()

        frame_time = han.displayed_frame  /  han.fps #Number of frames in a second of video
        try
            load_single_frame(frame_time,han.temp_frame,han.wt.vid_name)
            han.current_frame[:]=han.temp_frame'
            han.current_frame2[:]=han.current_frame
            redraw_all(han)

            update_times(han,1000)
            #set_gtk_property!(han.b["frame_id_label"],:label,string(han.displayed_frame))
            #set_gtk_property!(han.b["time_label"],:label,string(round(frame_time,digits=2), " s"))
        catch
        end
        han.frame_loaded = true

        if han.requested_frame != han.displayed_frame
            update_new_frame(han)
        else

            try
                draw_manual(han)
            catch
            end

            if han.analog.show
                update_analog_canvas(han)
            end
        end
    else

    end

end

function update_times(han::Tracker_Handles,frame_range)
    update_times(han.b,han.displayed_frame,han.fps,han.max_frames,frame_range)
end

function update_times(b,frame_id,fps,max_frames,frame_range)

    set_gtk_property!(b["frame_id_label"],:label,string(frame_id))
    set_gtk_property!(b["time_label"],:label,string(round(frame_id / fps,digits=2), " s"))

    (lower_id, upper_id) = get_lower_upper_frame(frame_id,frame_range,max_frames)

    set_gtk_property!(b["negative_frame_label"],:label,string(lower_id))
    set_gtk_property!(b["negative_time_label"],:label,string(round(lower_id / fps,digits=2), " s"))

    set_gtk_property!(b["positive_frame_label"],:label,string(upper_id))
    set_gtk_property!(b["positive_time_label"],:label,string(round(upper_id / fps,digits=2), " s"))
end

function get_lower_upper_frame(frame_id,frame_range,max_frames)
    lower_id = frame_id - frame_range
    if lower_id < 1
        lower_id = 1
    end

    upper_id = frame_id + frame_range
    if upper_id > max_frames
        upper_id = max_frames
    end

    (lower_id, upper_id)
end

function draw_manual(han::Tracker_Handles)

    frame_range = 1000
    (lower_id, upper_id) = get_lower_upper_frame(han.displayed_frame,frame_range,han.max_frames)

    ctx=Gtk.getgc(han.c2)
    w = width(ctx)
    set_source_rgb(ctx,1,1,1)
    paint(ctx)

    #center line
    set_source_rgb(ctx,0,0,0)
    cent = (upper_id - han.displayed_frame) / (upper_id - lower_id)
    move_to(ctx,cent * w,0)
    line_to(ctx,cent * w,20)
    stroke(ctx)

    #exclude
    try
        e_line = make_line(han.man.exclude_block,lower_id,upper_id,w)
        set_source_rgb(ctx,0,0,0)
        draw_manual_line(han.c2,e_line,2)
    catch
        println("Could not draw exclude block")
    end

    #Protraction
    try
        pro_line = make_line(han.man.pro_re_block .== 1,lower_id,upper_id,w)
        set_source_rgb(ctx,1,0,0)
        draw_manual_line(han.c2,pro_line,8)
    catch
        println("Error drawing protraction")
    end

    #Retraction
    try
        re_line = make_line(han.man.pro_re_block .== 2,lower_id,upper_id,w)
        set_source_rgb(ctx,0,0,1)
        draw_manual_line(han.c2,re_line,8)
    catch
        println("Error drawing retraction")
    end

    #Contact
    try
        con_line = make_line(han.man.contact .== 2,lower_id,upper_id,w)
        set_source_rgb(ctx,0,1,0)
        draw_manual_line(han.c2,con_line,14)

        con_t_line = make_line(han.tracked_contact, lower_id, upper_id,w)
        set_source_rgba(ctx,0,1,0,0.5)
        draw_manual_line(han.c2,con_t_line,18)
    catch
        println("Error drawing contact")
    end

    reveal(han.c2)
end

function draw_manual_line(c,a,j)
    ctx=Gtk.getgc(c)
    w=width(ctx)

    i=1
    while (i<w)
        if a[i]
            move_to(ctx,i,j)
            i = findnext(.!a,i)
            if (i != 0)&(i != nothing)
                line_to(ctx,i,j)
            else
                i = round(Int,w)
                line_to(ctx,i,j)
            end
        end
        i += 1
    end
    stroke(ctx)

end

function make_line(a,l_id,u_id,w)
    iter = range(l_id,u_id,length=round(Int,w))

    out = falses(round(Int,w))

    for i=2:length(iter)
        ind1 = round(Int,iter[i-1])
        ind2 = round(Int,iter[i])
        out[i]=maximum(a[ind1:ind2])
    end

    out
end

function load_single_frame(x::Float64,tt::AbstractArray{UInt8,2},vn::String)

    xx=@ffmpeg_env open(`$(FFMPEG.ffmpeg) -loglevel panic -ss $(x) -i $(vn) -f image2pipe -vcodec rawvideo -pix_fmt gray -`);
    
    read!(xx,tt)

    close(xx)

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
    #woi_id

    nothing
end

function get_label_path_from_config(config_path::String)

    dlc_folder_path = dirname(config_path)

    label_dir=string(dlc_folder_path,"/labeled-data")

    vid_dir=string(label_dir,"/",readdir(label_dir)[1])

    label_path=string(vid_dir,"/",filter(x->occursin(".h5",x), readdir(vid_dir))[1])
end

function change_save_paths(han::Tracker_Handles,config_path::String)

    dlc_folder_path = dirname(config_path)

    save_folder_name=dirname(dirname(dlc_folder_path))

    han.paths=Save_Paths(save_folder_name,false)

    nothing
end

#=
Add and remove frames for deep learning labels
=#

function add_frame_cb(w::Ptr,user_data::Tuple{Tracker_Handles})

    han, = user_data

    new_frame=han.displayed_frame

    try

        #add whisker WOI
        han.woi[new_frame]=Whisker1()

        han.frame_list = sort(collect(keys(han.woi)))

        #tracked array
        han.tracked[new_frame]=false

        #pole present
        han.pole_present[new_frame]=false

        #pole loc
        han.pole_loc[new_frame]=zeros(Float32,2)

        redraw_all(han)
        save_backup(han)

        update_table(han)

    catch
        println("Could not add frame")
    end

    nothing
end

function delete_frame_cb(w::Ptr,user_data::Tuple{Tracker_Handles})

    han, = user_data
    new_frame=han.displayed_frame

    try
        delete!(han.woi,new_frame)

        han.frame_list = sort(collect(keys(han.woi)))

        delete!(han.tracked,new_frame)
        delete!(han.pole_present,new_frame)
        delete!(han.pole_loc,new_frame)

        redraw_all(han)
        save_backup(han)

        update_table(han)

    catch
        println("Could not delete frame")
    end

    nothing
end

function save_backup(han::Tracker_Handles)

    #Read backup

    #Write backup
    file = jldopen(string(han.paths.backup,"/backup.jld"), "w")
    write(file, "frame_list",han.frame_list)
    write(file, "woi",han.woi)
    close(file)

    nothing
end

#=
Save Callbacks
=#

function save_cb(w::Ptr,user_data::Tuple{Tracker_Handles})

    han, = user_data

    dlg = Gtk.GtkFileChooserDialog("Save WhiskerTracking", han.b["win"], Gtk.GConstants.GtkFileChooserAction.SAVE,
                                   (("_Cancel", Gtk.GConstants.GtkResponseType.CANCEL),
                                    ("_Save",   Gtk.GConstants.GtkResponseType.ACCEPT));)
       dlgp = Gtk.GtkFileChooser(dlg)

       ccall((:gtk_file_chooser_set_do_overwrite_confirmation, Gtk.libgtk), Nothing, (Ptr{Gtk.GObject}, Cint), dlg, true)
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

        for i in keys(han.tracked)
            if han.tracked[i]
                han.woi[i].time = i
                push!(mywhiskers,deepcopy(han.woi[i]))
            end
        end

        write(file,"Whiskers",mywhiskers)
        write(file,"Frames_Tracked",han.tracked)
        #write(file,"all_whiskers",han.wt.all_whiskers)

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
        close(file)

        #change saving
        han.wt.tracking_name = filepath

    end
    nothing
end

function load_cb(w::Ptr,user_data::Tuple{Tracker_Handles})

    han, = user_data

    filepath = open_dialog("Load Whisker Tracking",han.b["win"])

    load_whisker_data(han,filepath)

    nothing
end

function advance_slider_cb(w::Ptr,param_tuple,user_data::Tuple{Tracker_Handles})

    han, = user_data

    event = unsafe_load(param_tuple)

    if event.keyval == 0xff53 #Right arrow
        setproperty!(han.b["adj_frame"],:value,han.requested_frame + han.speed) #This will call the slider callback
        #han.displayed_frame += 1
    elseif event.keyval == 0xff51 #Left arrow
        setproperty!(han.b["adj_frame"],:value,han.requested_frame - han.speed)
        #han.displayed_frame -= 1
    elseif event.keyval == 0xFFE9 #Left alt
        take_snapshot(han)
    elseif event.keyval == 0x063 #c
        contact = get_gtk_property(han.b["contact_block_button"],:active,Bool)
        set_gtk_property!(han.b["contact_block_button"],:active,!contact)
    elseif event.keyval == 0x02c # ,
        c_i = get_gtk_property(han.b["contact_spin"],:value,Int64)
        if c_i > 1
            set_gtk_property!(han.b["contact_spin_adj"],:value,c_i - 1)
        end
    elseif event.keyval == 0x02e # .
        c_i = get_gtk_property(han.b["contact_spin"],:value,Int64)
        set_gtk_property!(han.b["contact_spin_adj"],:value,c_i + 1)
    elseif event.keyval == 0x074 #t
        trace_cb(han)
    end

    nothing
end

function advance_slider_cb_mouse(w::Ptr,param_tuple,user_data::Tuple{Tracker_Handles})

    han, = user_data

    event = unsafe_load(param_tuple)

    if event.direction == Gtk.GdkScrollDirection.UP
        setproperty!(han.b["adj_frame"],:value,han.requested_frame + han.speed)
    elseif event.direction == Gtk.GdkScrollDirection.DOWN
        setproperty!(han.b["adj_frame"],:value,han.requested_frame - han.speed)
    end

    nothing
end

function take_snapshot(han::Tracker_Handles)
    save_label_image(han,han.save_label_path)
end

function plot_image(han::Tracker_Handles,img::AbstractArray{UInt8,2})

   ctx=Gtk.getgc(han.c)

    w,h = size(img)
    han.draw_area.img2[:] = img
    if sharpen_mode(han.b)
        han.draw_area.img2 = sharpen_image(han.draw_area.img2,han.im_adj.sharpen_win,han.im_adj.sharpen_reps,han.im_adj.sharpen_filter)
    end
    adjust_contrast(han.draw_area.img2,han.im_adj.contrast_min,han.im_adj.contrast_max)

    for i=1:length(han.draw_area.img2)
        han.draw_area.surface.data[i] = (convert(UInt32,han.draw_area.img2[i]) << 16) | (convert(UInt32,han.draw_area.img2[i]) << 8) | han.draw_area.img2[i]
    end

    ccall((:cairo_set_source_surface,Cairo._jl_libcairo), Ptr{Nothing},
    (Ptr{Nothing},Ptr{Nothing},Float64,Float64), ctx.ptr, han.draw_area.surface.ptr, 0, 0)

    rectangle(ctx, 0, 0, w, h)

    fill(ctx)

    draw_touch2(han)

    draw_event(han)

    #If this frame is in the frame list, draw a box around the display
    if !isempty(find(han.frame_list.==han.displayed_frame))
        set_source_rgb(ctx,0,1,0)
        rectangle(ctx, 0, 0, w, h)
        stroke(ctx)
    end

    if view_pad(han.b)
        set_source_rgb(ctx,0,0,1)
        arc(ctx, han.wt.pad_pos[1],han.wt.pad_pos[2], 10, 0, 2*pi);
        stroke(ctx)
    end

    if view_pole(han.b)
        if han.pole_present[han.displayed_frame]
            set_source_rgb(ctx,0,0,1)
            arc(ctx,han.pole_loc[han.displayed_frame][1],han.pole_loc[han.displayed_frame][2],10,0,2*pi)
            stroke(ctx)
        end
    end

    if get_gtk_property(han.b["zoom_win"],:visible,Bool)
        if han.selection_mode != 14
            draw_zoom(han)
        end
    end

    reveal(han.c)

    nothing
end

function draw_event(han::Tracker_Handles)

    if (han.show_event)

        try

            if han.event_array[han.displayed_frame]
                ctx = Gtk.getgc(han.c)

                w = 640
                h = 480
                set_source_rgb(ctx,1,0,0)
                rectangle(ctx, 40, h - 40, 20, 20)
                fill(ctx)

                reveal(han.c)
            end
        catch
            println("Could not draw event")
        end
    end

    nothing
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
Mode 13 = Draw Mask around face
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
                        han.tracked[han.displayed_frame]=true
                        assign_woi(han)
                        redraw_all(han)
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
            draw_start(han,m_x,m_y,2)
            redraw_all(han)
        catch
            println("Could not add point")
        end

    elseif han.selection_mode == 14
        try
            select_zoom_location(han,m_x,m_y)
        catch
            println("Selecting Box failed")
        end
    elseif han.selection_mode == 15
        try
            select_contact_angle(han,m_x,m_y)
        catch
            println("Selecting contact angle failed")
        end
    elseif han.selection_mode == 16
        try
            select_contact_location(han,m_x,m_y)
        catch
            println("Selecting contact location failed")
        end
    elseif han.selection_mode == 17
        try
            select_follicle_location(han,m_x,m_y)
        catch
            println("Selecting follicle location failed")
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
        redraw_all(han)
    end

    nothing
end

function select_whisker_pad(han::Tracker_Handles,x,y)

    han.wt.pad_pos=(x,y)

    redraw_all(han)
end

function select_pole_location(han::Tracker_Handles,x,y)

    #This should be in a temporary frame if frame isn't added yet. Otherwise, you
    #are changing the pole position for other frames.
    han.pole_present[han.displayed_frame] = true
    han.pole_loc[han.displayed_frame] = [x,y]

    redraw_all(han)
end

function trace_cb(w::Ptr,user_data::Tuple{Tracker_Handles})

    han, = user_data

    trace_cb(han)
end

function trace_cb(han::Tracker_Handles)
    try

        han.send_frame[:] = han.current_frame'
        if sharpen_mode(han.b)
            han.send_frame = sharpen_image(han.send_frame,han.im_adj.sharpen_win,han.im_adj.sharpen_reps,han.im_adj.sharpen_filter)
        end
        adjust_contrast(han.send_frame,han.im_adj.contrast_min,han.im_adj.contrast_max)
        han.wt.whiskers=WT_trace(han.frame,han.send_frame,han.wt.min_length,han.wt.pad_pos,han.wt.mask)

        redraw_all(han)

    catch
        println("Could not perform tracing")
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


    if haskey(han.woi,han.displayed_frame)
        if (han.tracked[han.displayed_frame])

            draw_woi(han,ctx)

            if view_discrete(han.b)
                draw_discrete(han)
            end
        end
    end

    if han.show_tracked_whisker
        draw_tracked_whisker(han)
    end

    if (han.nn.draw_preds)|(get_draw_predictions(han.b))
        #draw_predictions(han)
        try
            draw_prediction2(han,han.nn.hg,0.5)
        catch
            println("Could not predict")
        end
    end

    reveal(han.c)

    nothing
end

function draw_tracked_whisker(han::Tracker_Handles)

    ctx=Gtk.getgc(han.c)

    set_source_rgba(ctx,235/255,52/255,192/255,0.9)
    set_line_width(ctx,0.5)

    w_x = han.tracked_w.whiskers_x[han.displayed_frame]
    w_y = han.tracked_w.whiskers_y[han.displayed_frame]

    if length(w_x) > 0

        #Draw Whisker
        move_to(ctx,w_x[1],w_y[1])
        for i=2:length(w_x)
            line_to(ctx,w_x[i],w_y[i])
        end
        stroke(ctx)

        ip1 = han.tracked_w.ip_1[han.displayed_frame]
        ip2 = han.tracked_w.ip_2[han.displayed_frame]

        ip_1=get_ind_at_dist(w_x,w_y,ip1)
        ip_2=get_ind_at_dist(w_x,w_y,ip2)

        (x2,y2) = get_parabola_fit(w_x,w_y,han.tracked_w.parabola_coeffs[:,han.displayed_frame],han.tracked_w.parabola_angle[han.displayed_frame])

        set_source_rgba(ctx,58/255,235/255,52/255,0.9)
        set_line_width(ctx,0.5)
        move_to(ctx,x2[ip_1],y2[ip_1])
        for i=(ip_1+1):ip_2
            line_to(ctx,x2[i],y2[i])
        end
        stroke(ctx)

        myerror = sum((y2[ip_1:ip_2] .- w_y[ip_1:ip_2]).^2) / (ip_2 - ip_1)
        #curvs = [curvature(x2[i],han.tracked_w.parabola_coeffs[han.displayed_frame][1:2]...) for i=ip_1:ip_2]

        set_gtk_property!(han.b["parabola_error_label"],:label,string(round(myerror,digits=3)))

        if han.draw_mechanics
            set_source_rgb(ctx,0,0,1)
            x = han.tracked_w.pole_x[han.displayed_frame]
            y = han.tracked_w.pole_y[han.displayed_frame]
            arc(ctx, x,y, 5, 0, 2*pi);
            stroke(ctx)

            #a
            draw_arrow(ctx,x,y,30.0,han.tracked_w.contact_angle[han.displayed_frame],(1,1,1))

            draw_arrow(ctx,x,y,30.0,han.tracked_w.normal_angle[han.displayed_frame],(1,1,1))

            set_source_rgb(ctx,0,0,1)
            x = han.tracked_w.follicle_x[han.displayed_frame]
            y = han.tracked_w.follicle_y[han.displayed_frame]
            arc(ctx, x,y, 5, 0, 2*pi);
            stroke(ctx)

            draw_arrow(ctx,x,y,30.0,han.tracked_w.follicle_angle[han.displayed_frame],(1,1,1))
        end
    end
end

function draw_woi(han::Tracker_Handles,ctx)

    set_source_rgb(ctx,1.0,0.0,0.0)

    move_to(ctx,han.woi[han.displayed_frame].x[1],han.woi[han.displayed_frame].y[1])
    for i=2:han.woi[han.displayed_frame].len
        line_to(ctx,han.woi[han.displayed_frame].x[i],han.woi[han.displayed_frame].y[i])
    end
    stroke(ctx)

    nothing
end

function draw_woi2(han::Tracker_Handles,ctx)

    img = create_label_image(han,0)
    img = img'
    w,h = size(img)

    for i=1:length(img)
        if (img[i]>0)
            han.plot_frame[i] = (convert(UInt32,img[i]) << 16)
        end
    end
    stride = Cairo.format_stride_for_width(Cairo.FORMAT_RGB24, w)
    @assert stride == 4*w
    surface_ptr = ccall((:cairo_image_surface_create_for_data,Cairo._jl_libcairo),
                Ptr{Nothing}, (Ptr{Nothing},Int32,Int32,Int32,Int32),
                han.plot_frame, Cairo.FORMAT_RGB24, w, h, stride)

    ccall((:cairo_set_source_surface,Cairo._jl_libcairo), Ptr{Nothing},
    (Ptr{Nothing},Ptr{Nothing},Float64,Float64), ctx.ptr, surface_ptr, 0, 0)

    rectangle(ctx, 0, 0, w, h)

    fill(ctx)

    nothing
end

function assign_woi(han::Tracker_Handles)

    han.woi[han.displayed_frame] = deepcopy(han.wt.whiskers[han.woi_id])

    if get_gtk_property(han.b["tracked_whisker_toggle"],:active,Bool)
        han.tracked_w.whiskers_x[han.displayed_frame] = deepcopy(han.woi[han.displayed_frame].x)
        han.tracked_w.whiskers_y[han.displayed_frame] = deepcopy(han.woi[han.displayed_frame].y)

        han.tracked_w.whiskers_l[han.displayed_frame] = 1.0 # Manual assignment is a loss of zero

        correct_follicle(han.tracked_w.whiskers_x[han.displayed_frame],han.tracked_w.whiskers_y[han.displayed_frame],han.tracked_w.whisker_pad...)

        x = han.tracked_w.whiskers_x[han.displayed_frame]
        y = han.tracked_w.whiskers_y[han.displayed_frame]

        if get_gtk_property(han.b["contact_angle_check"],:active,Bool)
            ii = calc_p_dist(x,y,han.tracked_w.pole_x[han.displayed_frame],han.tracked_w.pole_y[han.displayed_frame])[2]
            han.tracked_w.contact_angle[han.displayed_frame] = get_theta_contact(x,y,ii,true)

            update_normal_angle(han,han.displayed_frame)
        end

        if get_gtk_property(han.b["follicle_location_check"],:active,Bool)
            han.tracked_w.follicle_x[han.displayed_frame] = x[1]
            han.tracked_w.follicle_y[han.displayed_frame] = y[1]
        end

        if get_gtk_property(han.b["follicle_angle_check"],:active,Bool)
            han.tracked_w.follicle_angle[han.displayed_frame] = get_angle(x,y,10.0,30.0)
        end
    end

    update_table(han)

    nothing
end

function get_frame_list(han::Tracker_Handles)
    sort(collect(keys(han.woi)))
end

function get_woi_array(han::Tracker_Handles)
    [han.woi[i] for i in get_frame_list(han)]
end
