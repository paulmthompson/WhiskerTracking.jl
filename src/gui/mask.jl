
function _make_mask_gui()

    mask_grid = Grid()
    mask_gen_button = CheckButton("Create Mask")
    mask_grid[1,1] = mask_gen_button
    mask_min_button = SpinButton(0:255)
    mask_grid[1,2] = mask_min_button
    mask_grid[2,2] = Label("Minimum Intensity")
    mask_max_button = SpinButton(0:255)
    mask_grid[1,3] = mask_max_button
    mask_grid[2,3] = Label("Maximum Intensity")

    mask_win=Window(mask_grid)
    Gtk.showall(mask_win)
    visible(mask_win,false)

    m_widgets=mask_widgets(mask_win,mask_gen_button,mask_min_button,mask_max_button)
end

function add_mask_callbacks(w::mask_widgets,handles::Tracker_Handles)

    signal_connect(mask_min_cb,w.min_button,"value-changed",Void,(),false,(handles,))
    signal_connect(mask_max_cb,w.max_button,"value-changed",Void,(),false,(handles,))
    signal_connect(mask_gen_cb,w.gen_button,"clicked",Void,(),false,(handles,))

    nothing
end

function mask_gen_cb(w::Ptr, user_data::Tuple{Tracker_Handles})

    han, = user_data

    redraw_all(han)
    plot_mask(han)

    nothing
end

function mask_min_cb(w::Ptr, user_data::Tuple{Tracker_Handles})

    han, = user_data

    mymin=getproperty(han.mask_widgets.min_button,:value,Int)
    mymax=getproperty(han.mask_widgets.max_button,:value,Int)

    generate_mask(han.wt,mymin,mymax,han.frame)

    redraw_all(han)
    plot_mask(han)

    nothing
end

function mask_max_cb(w::Ptr, user_data::Tuple{Tracker_Handles})

    han, = user_data

    mymin=getproperty(han.mask_widgets.min_button,:value,Int)
    mymax=getproperty(han.mask_widgets.max_button,:value,Int)

    redraw_all(han)
    generate_mask(han.wt,mymin,mymax,han.frame)

    plot_mask(han)

    nothing
end
