
function _make_discrete_gui()

    discrete_grid = Grid()
    discrete_space_button = SpinButton(2:100)
    discrete_grid[1,1] = discrete_space_button
    discrete_grid[2,1] = Label("Space Between Points")

    discrete_max_points_button = SpinButton(4:20)
    discrete_grid[1,2] = discrete_max_points_button
    discrete_grid[2,2] = Label("Max number of Points")

    discrete_auto_calc = CheckButton("Auto Calculate")
    discrete_grid[1,3] = discrete_auto_calc

    discrete_win=Window(discrete_grid)
    Gtk.showall(discrete_win)
    visible(discrete_win,false)

    d_widgets=discrete_widgets(discrete_win,discrete_space_button,discrete_max_points_button,discrete_auto_calc)
end

function add_discrete_callbacks(w::discrete_widgets,handles::Tracker_Handles)

    signal_connect(discrete_distance_cb,w.space_button,"value-changed",Void,(),false,(handles,))
    signal_connect(discrete_points_cb,w.points_button,"value-changed",Void,(),false,(handles,))
    signal_connect(discrete_auto_cb,w.calc_button,"clicked",Void,(),false,(handles,))

    nothing
end

function discrete_distance_cb(w::Ptr,user_data::Tuple{Tracker_Handles})

    han, = user_data

    num_dist=getproperty(han.d_widgets.space_button,:value,Int)

    han.d_spacing = num_dist

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

    han.discrete_auto_calc=getproperty(han.d_widgets.calc_button,:active,Bool)

    nothing
end
