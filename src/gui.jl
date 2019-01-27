
export make_gui

function make_gui(path,name; frame_range = (false,(0,0,0),(0,0,0)))

    vid_name = string(path,name)
    whisk_path = string(path,name,".whiskers")
    meas_path = string(path,name,".measurements")

    (vid,start_frame)=load_video(vid_name,frame_range)
    vid_length=size(vid,3)

    c=Canvas(640,480)

    grid=Grid()

    grid[1,1]=c

    frame_slider = Scale(false, 1,size(vid,3),1)
    adj_frame = Adjustment(frame_slider)
    setproperty!(adj_frame,:value,1)

    grid[1,2]=frame_slider

    control_grid=Grid()

    hist_c = Canvas(200,200)

    control_grid[1,1]=hist_c

    contrast_min_slider = Scale(false,0,255,1)
    adj_contrast_min=Adjustment(contrast_min_slider)
    setproperty!(adj_contrast_min,:value,0)
    control_grid[1,2]=contrast_min_slider
    control_grid[2,2]=Label("Minimum")

    contrast_max_slider = Scale(false,0,255,1)
    adj_contrast_max=Adjustment(contrast_max_slider)
    setproperty!(adj_contrast_max,:value,255)
    control_grid[1,3]=contrast_max_slider
    control_grid[2,3]=Label("Maximum")

    trace_button=Button("Trace")
    control_grid[1,4]=trace_button

    auto_button=ToggleButton("Auto")
    control_grid[1,5]=auto_button

    erase_button=ToggleButton("Erase Mode")
    control_grid[1,6]=erase_button

    draw_button=ToggleButton("Draw Mode")
    control_grid[1,7]=draw_button

    connect_button=Button("Connect to Pad")
    control_grid[2,7]=connect_button

    delete_button=Button("Delete Whisker")
    control_grid[1,8]=delete_button

    combine_button=ToggleButton("Combine Segments")
    control_grid[1,9]=combine_button

    background_button = CheckButton("Subtract Background")
    control_grid[1,10]=background_button

    sharpen_button = CheckButton("Sharpen Image")
    control_grid[1,11]=sharpen_button

    save_button = Button("Save")
    control_grid[1,12]=save_button

    load_button = Button("Load")
    control_grid[1,13]=load_button

    touch_button = ToggleButton("Define Touch")
    control_grid[2,9] = touch_button

    touch_override = Button("Touch Override")
    control_grid[2,10] = touch_override

    janelia_label=Label("Janelia Parameters")
    control_grid[3,4]=janelia_label

    janelia_seed_thres=SpinButton(0.01:.01:1.0)
    setproperty!(janelia_seed_thres,:value,0.99)
    control_grid[3,5]=janelia_seed_thres
    control_grid[4,5]=Label("Seed Threshold")

    janelia_seed_iterations=SpinButton(1:1:10)
    setproperty!(janelia_seed_iterations,:value,1)
    control_grid[3,6]=janelia_seed_iterations
    control_grid[4,6]=Label("Seed Iterations")


    grid[2,1]=control_grid

    win = Window(grid, "Whisker Tracker") |> showall

    all_whiskers=[Array{Whisker1}(0) for i=1:vid_length]

    wt=Tracker(vid,path,name,vid_name,whisk_path,meas_path,50,falses(480,640),Array{Whisker1}(0),
    (0.0,0.0),255,0,all_whiskers)

    handles = Tracker_Handles(1,win,c,frame_slider,adj_frame,trace_button,zeros(UInt32,640,480),
    hist_c,vid[:,:,1],0,Array{Whisker1}(size(vid,3)),
    0.0,0.0,zeros(Float64,size(vid,3),2),auto_button,false,erase_button,false,0,falses(size(vid,3)),
    delete_button,combine_button,0,Whisker1(),background_button,false,
    contrast_min_slider,adj_contrast_min,contrast_max_slider,adj_contrast_max,
    save_button, load_button,start_frame,zeros(Int64,vid_length),sharpen_button,false,
    draw_button,false,connect_button,touch_button,false,falses(480,640),touch_override,
    falses(size(vid,3)),zeros(Float64,size(vid,3)),zeros(Float64,size(vid,3)),janelia_seed_thres,
    janelia_seed_iterations,wt)

    #plot_image(handles,vid[:,:,1]')

    signal_connect(frame_select, frame_slider, "value-changed", Void, (), false, (handles,))
    signal_connect(trace_cb,trace_button, "clicked", Void, (), false, (handles,))
    signal_connect(auto_cb,auto_button, "clicked",Void,(),false,(handles,))
    signal_connect(erase_cb,erase_button, "clicked",Void,(),false,(handles,))
    signal_connect(whisker_select_cb,c,"button-press-event",Void,(Ptr{Gtk.GdkEventButton},),false,(handles,))
    signal_connect(delete_cb,delete_button, "clicked",Void,(),false,(handles,))
    signal_connect(combine_cb,combine_button,"clicked",Void,(),false,(handles,))
    signal_connect(background_cb,background_button,"clicked",Void,(),false,(handles,))
    signal_connect(adjust_contrast_cb,contrast_min_slider,"value-changed",Void,(),false,(handles,))
    signal_connect(adjust_contrast_cb,contrast_max_slider,"value-changed",Void,(),false,(handles,))
    signal_connect(advance_slider_cb,win,"key-press-event",Void,(Ptr{Gtk.GdkEventKey},),false,(handles,))
    signal_connect(save_cb, save_button, "clicked",Void,(),false,(handles,))
    signal_connect(load_cb, load_button, "clicked",Void,(),false,(handles,))
    signal_connect(sharpen_cb,sharpen_button,"clicked",Void,(),false,(handles,))
    signal_connect(draw_cb,draw_button,"clicked",Void,(),false,(handles,))
    signal_connect(connect_cb,connect_button,"clicked",Void,(),false,(handles,))
    signal_connect(touch_cb,touch_button,"clicked",Void,(),false,(handles,))
    signal_connect(touch_override_cb,touch_override,"clicked",Void,(),false,(handles,))

    signal_connect(jt_seed_thres_cb,janelia_seed_thres,"value-changed",Void,(),false,(handles,))
    signal_connect(jt_seed_iterations_cb,janelia_seed_iterations,"value-changed",Void,(),false,(handles,))

    handles
end

function jt_seed_thres_cb(w::Ptr,user_data::Tuple{Tracker_Handles})

    han, = user_data

    thres=getproperty(han.jt_seed_thres_button,:value,Float64)

    change_JT_param(:paramSEED_THRESH,convert(Float32,thres))

    nothing
end

function jt_seed_iterations_cb(w::Ptr,user_data::Tuple{Tracker_Handles})

    han, = user_data

    iterations=getproperty(han.jt_seed_iterations_button,:value,Int64)

    change_JT_param(:paramSEED_ITERATIONS,convert(Int32,iterations))

    nothing
end

function touch_cb(w::Ptr,user_data::Tuple{Tracker_Handles})

    han, = user_data

    han.touch_mode = getproperty(han.touch_button,:active,Bool)

    nothing
end

function touch_override_cb(w::Ptr,user_data::Tuple{Tracker_Handles})

    han, = user_data

    han.touch_frames[han.frame] = !han.touch_frames[han.frame]

    draw_touch(han)

    nothing
end

function detect_touch(han)

    if han.tracked[han.frame]

        hit=0

        for i=1:han.woi[han.frame].len
            xx=round(Int64,han.woi[han.frame].x[i])
            yy=round(Int64,han.woi[han.frame].y[i])

            if han.touch_mask[yy,xx]
                hit+=1
            end

        end

        if hit>2
            han.touch_frames[han.frame]=true
        end

    end
    nothing
end

function draw_touch(han::Tracker_Handles)

    ctx=Gtk.getgc(han.c)

    if han.touch_frames[han.frame]
        set_source_rgb(ctx,0,1,0)
    else
        set_source_rgb(ctx,1,0,0)
    end

    rectangle(ctx,600,0,20,20)
    fill(ctx)

    nothing
end


function touch_start(han,x,y)

    plot_image(han,han.current_frame')
    plot_touch_mask(han)
    reveal(han.c)

    push!((han.c.mouse, :button1motion),  (c, event) -> touch_move(han, event.x, event.y))
    push!((han.c.mouse, :motion), Gtk.default_mouse_cb)
    push!((han.c.mouse, :button1release), (c, event) -> touch_stop(han, event.x, event.y))

    nothing
end

function touch_move(han, x,y)

    x=round(Int64,x)
    y=round(Int64,y)

    for i=x-3:x+3
        for j=y-3:y+3
            han.touch_mask[j,i]=true
        end
    end

    plot_touch_mask(han)
    reveal(han.c)

    nothing
end

function plot_touch_mask(han)

    ctx=Gtk.getgc(han.c)

    set_source_rgb(ctx,1.0,0.0,0.0)

    for x=1:639
        for y=1:479
            if han.touch_mask[y,x]
                rectangle(ctx,x,y,1.0,1.0)
            end
        end
    end

    fill(ctx)

    nothing
end

function touch_stop(han,x,y)

    pop!((han.c.mouse, :button1motion))
    pop!((han.c.mouse, :motion))
    pop!((han.c.mouse, :button1release))

    nothing
end

function save_cb(w::Ptr,user_data::Tuple{Tracker_Handles})

    han, = user_data

    #filepath = save_dialog("Save Whisker Tracking",han.win)

    dlg = Gtk.GtkFileChooserDialog("Save WhiskerTracking", han.win, Gtk.GConstants.GtkFileChooserAction.SAVE,
                                   (("_Cancel", Gtk.GConstants.GtkResponseType.CANCEL),
                                    ("_Save",   Gtk.GConstants.GtkResponseType.ACCEPT));)
       dlgp = Gtk.GtkFileChooser(dlg)

       ccall((:gtk_file_chooser_set_do_overwrite_confirmation, Gtk.libgtk), Void, (Ptr{Gtk.GObject}, Cint), dlg, true)
       Gtk.GAccessor.current_folder(dlgp,string(dirname(dirname(han.wt.vid_name)),"/tracking"))
       Gtk.GAccessor.current_name(dlgp, basename(han.wt.vid_name)[1:(end-4)])
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
        mywhiskers = read(file,"Whiskers")
        mytracked = read(file, "Frames_Tracked")
        start_frame = read(file,"Start_Frame")
        if JLD.exists(file,"Touch")
            han.touch_frames=read(file,"Touch")
        end
        if JLD.exists(file,"Angles")
            han.woi_angle=read(file,"Angles")
        end
        if JLD.exists(file,"Curvature")
            han.woi_curv=read(file,"Curvature")
        end
        if JLD.exists(file,"all_whiskers")
            han.all_whiskers=read(file,"all_whiskers")
        end
        close(file)

        if size(han.wt.vid,3) != length(mytracked)
            println("Error: Number of loaded whisker frames does not match number of video frames")
        else

            for i=1:length(mywhiskers)
                han.woi[mywhiskers[i].time] = deepcopy(mywhiskers[i])
            end
            han.tracked = mytracked

        end

        if han.start_frame != start_frame
            println("Error: This data was not tracked starting at the same point in the video")
        end
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
        setproperty!(han.adj_frame,:value,han.frame+1)
    elseif event.keyval == 0xff51 #Left arrow
        setproperty!(han.adj_frame,:value,han.frame-1)
    end

    nothing
end

function adjust_contrast_cb(w::Ptr,user_data::Tuple{Tracker_Handles})

    han, = user_data

    han.wt.contrast_min = getproperty(han.adj_contrast_min,:value,Int64)
    han.wt.contrast_max = getproperty(han.adj_contrast_max,:value,Int64)

    adjust_contrast_gui(han)

    plot_image(han,han.current_frame')

    nothing
end

function background_cb(w::Ptr,user_data::Tuple{Tracker_Handles})

    han, = user_data

    han.background_mode = getproperty(han.background_button,:active,Bool)

    nothing
end

function sharpen_cb(w::Ptr,user_data::Tuple{Tracker_Handles})

    han, = user_data

    han.sharpen_mode = getproperty(han.sharpen_button,:active,Bool)

    nothing
end

function connect_cb(w::Ptr,user_data::Tuple{Tracker_Handles})

    han, = user_data

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

    nothing
end

function frame_select(w::Ptr,user_data::Tuple{Tracker_Handles})

    han, = user_data

    han.frame = getproperty(han.adj_frame,:value,Int64)

    han.current_frame = han.wt.vid[:,:,han.frame]

    adjust_contrast_gui(han)

    han.track_attempt=0 #Reset

    plot_image(han,han.current_frame')

    #Reset array of displayed whiskers
    han.wt.whiskers=Array{Whisker1}(0)

    #If whiskers were found previously, load them
    if length(han.wt.all_whiskers[han.frame])>0
        han.wt.whiskers=han.wt.all_whiskers[han.frame]
    end

    #Plot whisker if it has been previously tracked
    if han.tracked[han.frame]
        han.wt.whiskers=[han.woi[han.frame]]
        han.woi_id = 1
        plot_whiskers(han)
    end

    #Load prior position of tracked whisker (if it exists)
    if han.frame-1 != 0
        if han.tracked[han.frame-1]
            han.woi_x_f = han.woi[han.frame-1].x[end]
            han.woi_y_f = han.woi[han.frame-1].y[end]
        end
    end

    nothing
end

function auto_cb(w::Ptr,user_data::Tuple{Tracker_Handles})

    han, = user_data

    @async if getproperty(han.auto_button, :active, Bool)
        han.auto_mode = true
        while getproperty(han.auto_button, :active, Bool)
            start_auto(han)
        end
    else
        han.auto_mode = false
    end

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

    han.combine_mode = getproperty(han.combine_button,:active,Bool)

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

    if han.cov1[han.frame]>0
        set_source_rgb(ctx,0,0,0)
        rectangle(ctx,0,0,10,10)
        fill(ctx)
    end

    draw_touch(han)

    reveal(han.c)
end

function whisker_select_cb(widget::Ptr,param_tuple,user_data::Tuple{Tracker_Handles})

    han, = user_data

    event = unsafe_load(param_tuple)

    m_x = event.x
    m_y = event.y

    #Find whisker of interest
    for i=1:length(han.wt.whiskers)
        for j=1:han.wt.whiskers[i].len
            if (m_x>han.wt.whiskers[i].x[j]-5.0)&(m_x<han.wt.whiskers[i].x[j]+5.0)
                if (m_y>han.wt.whiskers[i].y[j]-5.0)&(m_y<han.wt.whiskers[i].y[j]+5.0)
                    han.woi_id = i
                    #han.woi_x_f = han.whiskers[han.woi_id].x[end]
                    #han.woi_y_f = han.whiskers[han.woi_id].y[end]
                    han.tracked[han.frame]=true
                    assign_woi(han)
                    break
                end
            end
        end
    end

    if han.erase_mode
        erase_start(han,m_x,m_y)
    elseif han.draw_mode
        draw_start(han,m_x,m_y)
    elseif han.combine_mode>0
        if han.combine_mode == 1
            combine_start(han,m_x,m_y)
        else
            combine_end(han,m_x,m_y)
        end
    elseif han.touch_mode
        touch_start(han,m_x,m_y)
    else
        plot_whiskers(han)
    end

    nothing
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
    else
        println("No intersection found")
    end

    han.combine_mode = 1
    plot_whiskers(han)

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
        keep[1:findfirst(keep.==false)]=false
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

    if han.background_mode
        subtract_background(han)
    end
    if han.sharpen_mode
        sharpen_image(han)
    end
    WT_trace(han.wt,han.frame,han.current_frame')

    WT_constraints(han)

    plot_whiskers(han)

    nothing
end


function WT_constraints(han)

    #get_follicle
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
    if !han.tracked[han.frame]
        if (use_both)
            if (mincor<15.0)&(min_dist < 20.0)
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
        han.track_attempt+=1
        if han.track_attempt==1
            subtract_background(han)
            WT_trace(han.wt,han.frame,han.current_frame')
            WT_constraints(han)
        elseif han.track_attempt==2
            sharpen_image(han)
            WT_trace(han.wt,han.frame,han.current_frame')
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

    #Check for overlapped whiskers


    if han.tracked[han.frame]
        detect_touch(han)
    end

    #Find

    nothing
end

function start_auto(han::Tracker_Handles)

    if han.frame+1 <= size(han.wt.vid,3)
        #advance one frame
        setproperty!(han.adj_frame,:value,han.frame+1)

        if length(han.wt.all_whiskers[han.frame])==0
            WT_trace(han.wt,han.frame,han.current_frame')
        end

        #Link whiskers
        WT_constraints(han)

        plot_whiskers(han)
    else
        setproperty!(han.auto_button,:active,false)
    end
    sleep(0.001)

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

    if han.tracked[han.frame]
        set_source_rgb(ctx,1.0,0.0,0.0)

        move_to(ctx,han.woi[han.frame].x[1],han.woi[han.frame].y[1])
        for i=2:han.woi[han.frame].len
            line_to(ctx,han.woi[han.frame].x[i],han.woi[han.frame].y[i])
        end
        stroke(ctx)
    end

    reveal(han.c)

    nothing
end
