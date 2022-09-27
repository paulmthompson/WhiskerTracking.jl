
function _make_discrete_gui()

    discrete_grid = Grid()
    discrete_space_button = SpinButton(2:100)
    discrete_grid[1,1] = discrete_space_button
    discrete_grid[2,1] = Label("Space Between Points")

    discrete_max_points_button = SpinButton(4:20)
    discrete_grid[1,2] = discrete_max_points_button
    discrete_grid[2,2] = Label("Max number of Points")

    discrete_auto_calc = CheckButton("Auto Calculate")
    setproperty!(discrete_auto_calc,:active,true)
    discrete_grid[1,3] = discrete_auto_calc

    discrete_add_button = CheckButton("Add Discrete Point")
    discrete_grid[1,4] = discrete_add_button

    discrete_delete_button = Button("Delete All Points in Frame")
    discrete_grid[1,5] = discrete_delete_button

    discrete_win=Window(discrete_grid)
    Gtk.showall(discrete_win)
    visible(discrete_win,false)

    d_widgets=discrete_widgets(discrete_win,discrete_space_button,discrete_max_points_button,discrete_auto_calc,
    discrete_add_button,discrete_delete_button)
end

function add_discrete_callbacks(w::discrete_widgets,handles::Tracker_Handles)

    signal_connect(discrete_distance_cb,w.space_button,"value-changed",Void,(),false,(handles,))
    signal_connect(discrete_points_cb,w.points_button,"value-changed",Void,(),false,(handles,))
    signal_connect(discrete_auto_cb,w.calc_button,"clicked",Void,(),false,(handles,))
    signal_connect(discrete_add_cb,w.add_button,"clicked",Void,(),false,(handles,))
    signal_connect(discrete_delete_cb,w.delete_button,"clicked",Void,(),false,(handles,))

    nothing
end

function discrete_distance_cb(w::Ptr,user_data::Tuple{Tracker_Handles})

    han, = user_data

    num_dist=getproperty(han.d_widgets.space_button,:value,Int)


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

    #han.discrete_auto_calc=getproperty(han.d_widgets.calc_button,:active,Bool)

    nothing
end

function discrete_add_cb(w::Ptr,user_data::Tuple{Tracker_Handles})

    han, = user_data

    if getproperty(han.d_widgets.add_button,:active,Bool)
        han.selection_mode = 13
    else
        han.selection_mode = 1
        determine_viewers(han)
    end

    nothing
end

function discrete_delete_cb(w::Ptr,user_data::Tuple{Tracker_Handles})

    han, = user_data

    #han.wt.w_p[:,han.frame] .= 0.0
    redraw_all(han)

    nothing
end

function make_discrete_all_whiskers(han::Tracker_Handles,spacing=15.0)
    woi=get_woi_array(han)
    make_discrete_all_whiskers(woi,han.wt.pad_pos,spacing)
end

function draw_discrete(han::Tracker_Handles)

    x1 = han.woi[han.displayed_frame].x
    y1 = han.woi[han.displayed_frame].y

    w_length = total_length(x1,y1)
    d_vec=range(0.1,0.9,step=0.02)

    (w1_theta,w1_theta_absolute,last_ind) = convert_to_angular_coordinates(x1,y1,d_vec.*w_length)

    ctx=Gtk.getgc(han.c)

    (x_p2,y_p2) = get_ind_at_dist_exact(x1,y1,(d_vec.*w_length)[1])
    draw_discrete(ctx,w1_theta_absolute,d_vec.*w_length,(x_p2,y_p2))

    nothing
end

function draw_discrete(ctx,theta,l,origin = (0.0,0.0))

    (x1,y1) = origin
    x2 = 0.0
    y2 = 0.0
    
    t_length = 0.0
    
    circ_rad=5.0

    for i=2:length(theta)
        y2 = sin(theta[i])*(l[i]-l[i-1]) + y1
        x2 = cos(theta[i])*(l[i]-l[i-1]) + x1

        arc(ctx, x2,y2, circ_rad, 0, 2*pi);
        stroke(ctx);
        
        t_length += sqrt((x2-x1)^2+(y2-y1)^2)
        y1 = y2
        x1 = x2
    end
    println(t_length)

end