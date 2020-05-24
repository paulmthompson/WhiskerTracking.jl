
function draw_cb(w::Ptr,user_data::Tuple{Tracker_Handles})

    han, = user_data

    han.draw_mode = getproperty(han.b["draw_button"],:active,Bool)

    nothing
end

function draw_start(han::Tracker_Handles,x,y)

    plot_image(han,han.current_frame')
    r = Gtk.getgc(han.c)
    Cairo.save(r)
    ctxcopy = copy(r)

    #if han.tracked[han.frame]
        new_whisker=Whisker1()

        push!(new_whisker.x,x)
        push!(new_whisker.y,y)
        push!(new_whisker.scores,1.0f0)
        push!(new_whisker.thick,1.0f0)

        new_whisker.len=1

        han.wt.whiskers=[new_whisker]
        han.woi_id = 1
    #end

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
