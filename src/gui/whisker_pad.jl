
function _make_pad_gui()

    pad_grid=Grid()
    pad_gen_button = CheckButton("Select Whisker Pad")
    pad_grid[1,1] = pad_gen_button
    pad_grid[1,2] = Label("Select the location of the whisker pad when box is checked")
    pad_grid[1,3] = Label("Whiskers will be oriented so that the root is nearest the pad location")
    pad_win=Window(pad_grid)
    Gtk.showall(pad_win)
    visible(pad_win,false)

    p_widgets=pad_widgets(pad_win,pad_gen_button)
end

function add_pad_callbacks(w::pad_widgets,handles::Tracker_Handles)

    signal_connect(pad_gen_cb,w.gen_button,"clicked",Void,(),false,(handles,))
    nothing
end

function pad_gen_cb(w::Ptr, user_data::Tuple{Tracker_Handles})

    han, = user_data

    if getproperty(han.pad_widgets.gen_button,:active,Bool)
        han.selection_mode = 10
        han.view_pad = true
    else
        han.selection_mode = 1
        determine_viewers(han)
    end

    redraw_all(han)

    nothing
end
