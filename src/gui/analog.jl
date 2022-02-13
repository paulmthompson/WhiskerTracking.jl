
function make_analog_gui(b::Gtk.GtkBuilder,handles::Tracker_Handles)

    push!(b["analog_c_box"],handles.analog.c)
    setproperty!(handles.analog.c,:hexpand,true)
    setproperty!(handles.analog.c,:vexpand,true)
    show(handles.analog.c)

end

function add_analog_callbacks(b::Gtk.GtkBuilder,handles::Tracker_Handles)

    signal_connect(analog_time_cb,b["analog_x_zoom_minus"],"clicked",Void,(),false,(handles,0))
    signal_connect(analog_time_cb,b["analog_x_zoom_plus"],"clicked",Void,(),false,(handles,1))

    nothing
end

function analog_time_cb(w::Ptr,user_data::Tuple{Tracker_Handles,Int})

    han, time_zoom = user_data

    if time_zoom == 0
        han.analog.t_zoom = han.analog.t_zoom - 1
        if han.analog.t_zoom < 0
            han.analog.t_zoom = 0
        end
    else
        han.analog.t_zoom = han.analog.t_zoom + 1
    end

    update_analog_canvas(han)

    nothing
end

function update_analog_canvas(han::Tracker_Handles)

    frame_range = han.analog.t_zoom
    (lower_id, upper_id) = get_lower_upper_frame(han.displayed_frame,frame_range,han.max_frames)

    ctx=Gtk.getgc(han.analog.c)

    set_source_rgb(ctx,1,1,1)
    paint(ctx)

    w=width(ctx)
    h=height(ctx)

    #center line
    set_source_rgb(ctx,1,0,0)
    cent = (upper_id - han.displayed_frame) / (upper_id - lower_id)
    move_to(ctx,cent * w,0)
    line_to(ctx,cent * w,h)
    stroke(ctx)

    #exclude
    #e_line = make_line(han.man.exclude_block,lower_id,upper_id,w)
    #set_source_rgb(ctx,0,0,0)
    #draw_manual_line(han.analog.c,e_line,2)

    #spikes
    set_source_rgb(ctx,0,0,0)

    #Find points from along signal that are within the frame

    #Get min ind of analog
    a_min=get_min_analog(han,han.analog.cam[lower_id],1)

    #Get max ind of analog
    a_max=get_max_analog(han,han.analog.cam[upper_id],1)

    off = h/2
    move_to(ctx,0,off+han.analog.var[1][a_min] * han.analog.gains[1])
    aa = a_min + 1

    while aa < a_max
        x = (aa - a_min) / (a_max - a_min) * w
        y = han.analog.var[1][aa] * han.analog.gains[1] + off
        line_to(ctx,x,y)
        aa += 1
    end
    stroke(ctx)

    #draw time
    set_source_rgb(ctx,0,0,0)
    move_to(ctx,w/2-10,h-10.0)
    show_text(ctx,string(round((a_min + a_max) / 2 / 30000.0,digits=2)))

    #draw exclude block
    e_line = make_line(han.man.exclude_block,lower_id,upper_id,w)
    draw_manual_line(han.analog.c,e_line,10)
    stroke(ctx)

    #draw contact Block
    try
        con_line = make_line(han.man.contact .== 2,lower_id,upper_id,w)
        set_source_rgb(ctx,0,1,0)
        draw_manual_line(han.analog.c,con_line,14)

        con_t_line = make_line(han.tracked_contact, lower_id, upper_id,w)
        set_source_rgba(ctx,0,1,0,0.5)
        draw_manual_line(han.analog.c,con_t_line,18)
    catch
        println("Error drawing contact")
    end

    #Draw Events
    t1 = han.analog.cam[lower_id]
    t2 = han.analog.cam[upper_id]

    for i=1:length(han.analog.ts_d[1])

        if (han.analog.ts_d[1][i] >= t1) & (han.analog.ts_d[1][i] <= t2)
            pos = (han.analog.ts_d[1][i] - t1) / (t2 - t1) * w

            set_source_rgb(ctx,0,0,0)
            move_to(ctx,pos,20)
            line_to(ctx,pos,25)
            stroke(ctx)
        end

    end

    reveal(han.analog.c)

    nothing
end

function get_min_analog(han,b1::Real,an::Int)

    findfirst(han.analog.ts[an] .>= b1)[1]
end

function get_max_analog(han,b1::Real,an::Int)

    findfirst(han.analog.ts[an] .>= b1)[1]-1
end
