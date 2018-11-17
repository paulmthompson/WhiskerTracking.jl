
export make_gui

function make_gui(path,name)

    vid_name = string(path,name,".tif")
    whisk_path = string(path,name,".whiskers")
    meas_path = string(path,name,".measurements")

    vid=reinterpret(UInt8,load(vid_name))

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

    delete_button=Button("Delete Whisker")
    control_grid[1,7]=delete_button

    combine_button=ToggleButton("Combine Segments")
    control_grid[1,8]=combine_button

    background_button = CheckButton("Subtract Background")
    control_grid[1,9]=background_button

    grid[2,1]=control_grid

    win = Window(grid, "Whisker Tracker") |> showall

    handles = Tracker_Handles(path,name,vid_name,whisk_path,meas_path,win,c,vid,1,
    frame_slider,adj_frame,trace_button,Array{Whisker1}(0),zeros(UInt32,640,480),
    hist_c,vid[:,:,1],50,0,Array{Whisker1}(size(vid,3)),
    0.0,0.0,auto_button,false,erase_button,false,falses(640,480),0,falses(size(vid,3)),
    (0.0,0.0),delete_button,combine_button,0,Whisker1(),background_button,false,
    contrast_min_slider,adj_contrast_min,contrast_max_slider,adj_contrast_max,255,0)

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

    handles
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

    han.contrast_min = getproperty(han.adj_contrast_min,:value,Int64)
    han.contrast_max = getproperty(han.adj_contrast_max,:value,Int64)

    adjust_contrast(han)

    plot_image(han,han.current_frame')

    nothing
end

function background_cb(w::Ptr,user_data::Tuple{Tracker_Handles})

    han, = user_data

    han.background_mode = getproperty(han.background_button,:active,Bool)

    nothing
end

function frame_select(w::Ptr,user_data::Tuple{Tracker_Handles})

    han, = user_data

    han.frame = getproperty(han.adj_frame,:value,Int64)

    han.current_frame = han.vid[:,:,han.frame]

    adjust_contrast(han)

    han.track_attempt=0 #Reset

    plot_image(han,han.current_frame')

    #Plot whisker if it has been previously tracked
    if han.tracked[han.frame]
        han.whiskers=[han.woi[han.frame]]
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
    han.current_frame = han.vid[:,:,han.frame]
    plot_image(han,han.current_frame')

    nothing
end

function erase_cb(w::Ptr,user_data::Tuple{Tracker_Handles})

    han, = user_data

    han.erase_mode = getproperty(han.erase_button,:active,Bool)

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

    reveal(han.c)
end

function whisker_select_cb(widget::Ptr,param_tuple,user_data::Tuple{Tracker_Handles})

    han, = user_data

    event = unsafe_load(param_tuple)

    m_x = event.x
    m_y = event.y

    #Find whisker of interest
    for i=1:length(han.whiskers)
        for j=1:han.whiskers[i].len
            if (m_x>han.whiskers[i].x[j]-5.0)&(m_x<han.whiskers[i].x[j]+5.0)
                if (m_y>han.whiskers[i].y[j]-5.0)&(m_y<han.whiskers[i].y[j]+5.0)
                    han.woi_id = i
                    #han.woi_x_f = han.whiskers[han.woi_id].x[end]
                    #han.woi_y_f = han.whiskers[han.woi_id].y[end]
                    han.tracked[han.frame]=true
                    han.woi[han.frame]=deepcopy(han.whiskers[han.woi_id])
                    break
                end
            end
        end
    end

    if han.erase_mode
        erase_start(han,m_x,m_y)
    elseif han.combine_mode>0
        if han.combine_mode == 1
            combine_start(han,m_x,m_y)
        else
            combine_end(han,m_x,m_y)
        end
    else
        plot_whiskers(han)
    end

    nothing
end

function combine_start(han,x,y)

    println("start")
    han.partial = deepcopy(han.whiskers[han.woi_id])
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
        for j=2:han.whiskers[han.woi_id].len
            if intersect(han.partial.x[i-1],han.partial.x[i],han.whiskers[han.woi_id].x[j-1],
            han.whiskers[han.woi_id].x[j],han.partial.y[i-1],han.partial.y[i],
            han.whiskers[han.woi_id].y[j-1],han.whiskers[han.woi_id].y[j])
                out1=i
                out2=j
                break
            end
        end
    end

    if out1==1
        println("No intersection found, looking for closest match")

        for i=2:han.partial.len
            for j=2:han.whiskers[han.woi_id].len
                if sqrt((han.partial.x[i]-han.whiskers[han.woi_id].x[j]).^2+(han.partial.y[i]-han.whiskers[han.woi_id].y[j]).^2)<2.0
                    out1=i
                    out2=j
                    break
                end
            end
        end
    end

    if out1>1
        println("Segments combined")
        new_x = [han.whiskers[han.woi_id].x[1:out2]; han.partial.x[out1:end]]
        new_y = [han.whiskers[han.woi_id].y[1:out2]; han.partial.y[out1:end]]
        new_scores = [han.whiskers[han.woi_id].scores[1:out2]; han.partial.scores[out1:end]]
        new_thick = [han.whiskers[han.woi_id].thick[1:out2]; han.partial.thick[out1:end]]
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
    keep=trues(han.whiskers[han.woi_id].len)
    for i=1:han.whiskers[han.woi_id].len
        if (x+5.0>han.whiskers[han.woi_id].x[i])&(x-5.0<han.whiskers[han.woi_id].x[i])
            if (y+5.0>han.whiskers[han.woi_id].y[i])&(y-5.0<han.whiskers[han.woi_id].y[i])
                keep[i]=false
            end
        end
    end

    if length(find(keep.==false))>0
        keep[1:findfirst(keep.==false)]=false
    end

    han.whiskers[han.woi_id].x=han.whiskers[han.woi_id].x[keep]
    han.whiskers[han.woi_id].y=han.whiskers[han.woi_id].y[keep]
    han.whiskers[han.woi_id].thick=han.whiskers[han.woi_id].thick[keep]
    han.whiskers[han.woi_id].scores=han.whiskers[han.woi_id].scores[keep]

    han.whiskers[han.woi_id].len=length(han.whiskers[han.woi_id].x)

    #redraw whisker
    set_source(r,ctxcopy)
    paint(r)

    plot_whiskers(han)

    nothing
end

function erase_stop(han,x,y,ctxcopy)

    han.woi[han.frame] = deepcopy(han.whiskers[han.woi_id])

    pop!((han.c.mouse, :button1motion))
    pop!((han.c.mouse, :motion))
    pop!((han.c.mouse, :button1release))

    nothing
end

function trace_cb(w::Ptr,user_data::Tuple{Tracker_Handles})

    han, = user_data

    han.whiskers = WT_trace(han.frame,han.current_frame')

    WT_constraints(han)

    plot_whiskers(han)

    nothing
end

function WT_constraints(han)

    pass = trues(length(han.whiskers))

    for i=1:length(han.whiskers)
        if han.whiskers[i].len<han.min_length
            pass[i]=false
        end
    end

    han.whiskers=han.whiskers[pass]

    #order whiskers so that the last index is closest to the whisker pad
    for i=1:length(han.whiskers)
        front_dist = (han.whiskers[i].x[1]-han.pad_pos[1])^2+(han.whiskers[i].y[1]-han.pad_pos[2])^2
        end_dist = (han.whiskers[i].x[end]-han.pad_pos[1])^2+(han.whiskers[i].y[end]-han.pad_pos[2])^2

        if front_dist < end_dist #
            han.whiskers[i].x = flipdim(han.whiskers[i].x,1)
            han.whiskers[i].y = flipdim(han.whiskers[i].y,1)
            han.whiskers[i].scores = flipdim(han.whiskers[i].scores,1)
            han.whiskers[i].thick = flipdim(han.whiskers[i].thick,1)
        end
    end

    #Apply mask
    apply_mask(han)

    #Find most similar whisker follicle position
    min_dist = sqrt((han.whiskers[1].x[end]-han.woi_x_f)^2+(han.whiskers[1].y[end]-han.woi_y_f)^2)
    han.woi_id = 1
    for i=2:length(han.whiskers)
        mydist = sqrt((han.whiskers[i].x[end]-han.woi_x_f)^2+(han.whiskers[i].y[end]-han.woi_y_f)^2)
        if mydist<min_dist
            min_dist = mydist
            han.woi_id = i
        end
    end

    #Whisker should not move more than 0.64 mm / ms  (1.28 mm / 2ms)
    # If about 0.07 mm / pixel or about 20 pixels
    #If we don't have a whisker with this criteria met, adjust paramters
    #and try again
    if !han.tracked[han.frame]
        if min_dist <5.0
            han.tracked[han.frame]=true
            han.woi[han.frame]=deepcopy(han.whiskers[han.woi_id])
        else
            han.track_attempt+=1
            if han.track_attempt==1
                subtract_background(han)
                han.whiskers = WT_trace(han.frame,han.current_frame')
                WT_constraints(han)
            elseif han.track_attempt==2
                sharpen_image(han)
                han.whiskers = WT_trace(han.frame,han.current_frame')
                WT_constraints(han)
            else
                if min_dist <20.0
                    han.tracked[han.frame]=true
                    han.woi[han.frame]=deepcopy(han.whiskers[han.woi_id])
                end
            end

            #Tracking Statistics
            println("Frame number: ", han.frame, " Distance: ", min_dist)
            println("Track attempt: ", han.track_attempt)
        end
    end

    #Find

    nothing
end

function apply_mask(han)

    for i=1:length(han.whiskers)
        save_points=trues(length(han.whiskers[i].x))
        for j=1:length(han.whiskers[i].x)
            x_ind = round(Int64,han.whiskers[i].y[j])
            y_ind = round(Int64,han.whiskers[i].x[j])
            if han.mask[x_ind,y_ind]
                save_points[j]=false
            end
        end

        han.whiskers[i].x=han.whiskers[i].x[save_points]
        han.whiskers[i].y=han.whiskers[i].y[save_points]
        han.whiskers[i].thick=han.whiskers[i].thick[save_points]
        han.whiskers[i].scores=han.whiskers[i].scores[save_points]
        han.whiskers[i].len = length(han.whiskers[i].x)
    end


    nothing
end

function start_auto(han::Tracker_Handles)

    if han.frame+1 <= size(han.vid,3)
        setproperty!(han.adj_frame,:value,han.frame+1)

        han.whiskers = WT_trace(han.frame,han.current_frame')

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

    for w=1:length(han.whiskers)

        set_source_rgb(ctx,0.0,0.0,1.0)

        move_to(ctx,han.whiskers[w].x[1],han.whiskers[w].y[1])
        for i=2:han.whiskers[w].len
            line_to(ctx,han.whiskers[w].x[i],han.whiskers[w].y[i])
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
