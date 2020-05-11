
function erase_cb(w::Ptr,user_data::Tuple{Tracker_Handles})

    han, = user_data

    han.erase_mode = getproperty(han.erase_button,:active,Bool)

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
