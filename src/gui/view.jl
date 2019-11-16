
function _make_view_gui()

    view_grid=Grid()
    view_whisker_pad_button = CheckButtonLeaf("Whisker Pad")
    view_grid[1,1] = view_whisker_pad_button
    view_roi_button = CheckButtonLeaf("Region of Interest")
    view_grid[1,2] = view_roi_button
    view_discrete_button = CheckButtonLeaf("Discrete Points")
    setproperty!(view_discrete_button,:active,true)
    view_grid[1,3] = view_discrete_button
    view_pole_button = CheckButtonLeaf("Pole")
    view_grid[1,4] = view_pole_button
    view_tracked_button = CheckButtonLeaf("Tracked Whiskers")
    view_grid[1,5] = view_tracked_button

    view_grid[1,7] = Label("Select which items are always displayed for each frame")

    view_win = Window(view_grid)
    Gtk.showall(view_win)
    visible(view_win,false)

    v_widgets=view_widgets(view_win,view_whisker_pad_button,view_roi_button,view_discrete_button,view_pole_button,view_tracked_button)
end

function add_view_callbacks(w::view_widgets,handles::Tracker_Handles)

    signal_connect(view_whisker_pad_cb,w.whisker_pad_button,"clicked",Void,(),false,(handles,))
    signal_connect(view_roi_cb,w.roi_button,"clicked",Void,(),false,(handles,))
    signal_connect(view_pole_cb,w.pole_button,"clicked",Void,(),false,(handles,))
    signal_connect(view_discrete_cb,w.discrete_button,"clicked",Void,(),false,(handles,))
    signal_connect(view_whiskers_cb,w.tracked_button,"clicked",Void,(),false,(handles,))

    nothing
end

function view_whisker_pad_cb(w::Ptr,user_data::Tuple{Tracker_Handles})

    han, = user_data
    han.view_pad = getproperty(han.view_widgets.whisker_pad_button,:active,Bool)
    redraw_all(han)
    nothing
end

function view_roi_cb(w::Ptr,user_data::Tuple{Tracker_Handles})

    han, = user_data
    han.view_roi = getproperty(han.view_widgets.roi_button,:active,Bool)
    redraw_all(han)
    nothing
end

function view_pole_cb(w::Ptr,user_data::Tuple{Tracker_Handles})

    han, = user_data
    han.view_pole = getproperty(han.view_widgets.pole_button,:active,Bool)
    redraw_all(han)
    nothing
end

function view_discrete_cb(w::Ptr,user_data::Tuple{Tracker_Handles})

    han, = user_data
    han.discrete_draw = getproperty(han.view_widgets.discrete_button,:active,Bool)
    redraw_all(han)
    nothing
end

function view_whiskers_cb(w::Ptr,user_data::Tuple{Tracker_Handles})

    han, = user_data
    han.show_tracked = getproperty(han.view_widgets.tracked_button,:active,Bool)
    redraw_all(han)
    nothing
end
