
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
    line_to(ctx,cent * w,20)
    stroke(ctx)

    #exclude
    #e_line = make_line(han.man.exclude_block,lower_id,upper_id,w)
    #set_source_rgb(ctx,0,0,0)
    #draw_manual_line(han.analog.c,e_line,2)

    #spikes
    set_source_rgb(ctx,0,0,0)

    #Find points from along signal that are within the frame

    #Get min ind
    a_min=get_min_analog(han,lower_id,1)

    #Get center ind
    get_min_analog(han,han.displayed_frame,1)

    #Get max ind
    a_max=get_max_analog(han,upper_id,1)

    #myline = rand(-100:100,round(Int,w))
    off = h/2

    an_range = range(a_min,a_max,length=round(Int64,w))
    move_to(ctx,0,off+han.analog.var[1][a_min])
    aa = a_min + 1
    a_val = 0
    ww = 1
    while aa < a_max

        if abs(han.analog.var[1][aa]) > a_val
            a_val = han.analog.var[1][aa]
        end

        if aa > an_range[ww]
            line_to(ctx,ww,a_val + off)
            a_val = 0
            ww += 1
        end
        aa += 1
    end
    stroke(ctx)

    reveal(han.analog.c)

    nothing
end

function get_min_analog(han,b1::Int,an::Int)

    findfirst(han.analog.ts[an].>b1)[1]
end

function get_max_analog(han,b1::Int,an::Int)

    findfirst(han.analog.ts[an].>b1)[1]-1
end
