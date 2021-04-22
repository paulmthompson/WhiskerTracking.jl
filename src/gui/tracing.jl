
function add_tracing_callbacks(b::Gtk.GtkBuilder,handles::Tracker_Handles)

    signal_connect(combine_cb,b["tracing_combine_button"],"clicked",Void,(),false,(handles,))

    nothing
end

function combine_cb(w::Ptr,user_data::Tuple{Tracker_Handles})

    han, = user_data

    han.combine_mode = getproperty(han.b["tracing_combine_button"],:active,Bool)

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
        d=1000.0
        for i=2:han.partial.len
            for j=2:han.wt.whiskers[han.woi_id].len
                this_d = sqrt((han.partial.x[i]-han.wt.whiskers[han.woi_id].x[j]).^2+(han.partial.y[i]-han.wt.whiskers[han.woi_id].y[j]).^2)
                if this_d<d
                    d = this_d
                    out1=i
                    out2=j
                end
            end
        end
    end


    println("Segments combined")
    new_x = [han.wt.whiskers[han.woi_id].x[1:out2]; han.partial.x[out1:end]]
    new_y = [han.wt.whiskers[han.woi_id].y[1:out2]; han.partial.y[out1:end]]
    new_scores = [han.wt.whiskers[han.woi_id].scores[1:out2]; han.partial.scores[out1:end]]
    new_thick = [han.wt.whiskers[han.woi_id].thick[1:out2]; han.partial.thick[out1:end]]
    han.woi[han.displayed_frame].x=new_x
    han.woi[han.displayed_frame].y=new_y
    han.woi[han.displayed_frame].thick=new_thick
    han.woi[han.displayed_frame].scores=new_scores
    han.woi[han.displayed_frame].len = length(new_thick)

    han.combine_mode = 1
    redraw_all(han)

    nothing
end
