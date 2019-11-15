
function _make_pole_gui()

    pole_grid=Grid()
    pole_mode_button = CheckButtonLeaf("Find Location in Tracking?")
    pole_grid[1,1] = pole_mode_button
    pole_gen_button = CheckButton("Select Pole Location")
    pole_grid[1,2] = pole_gen_button
    pole_auto_button = Button("Automatically Determine Pole Location")
    pole_grid[1,3] = pole_auto_button
    pole_touch_button = CheckButton("Show Touch Location")
    pole_grid[1,4] = pole_touch_button

    pole_delete_button = Button("Delete Pole in Frame")
    pole_grid[1,5] = pole_delete_button

    pole_grid[1,7] = Label("Check the top checkbox if you want the whisker tracker to \n also look for a pole in each frame")

    pole_win = Window(pole_grid)
    Gtk.showall(pole_win)
    visible(pole_win,false)

    pp_widgets=pole_widgets(pole_win,pole_mode_button,pole_gen_button,pole_auto_button,pole_touch_button,pole_delete_button)
end

function add_pole_callbacks(w::pole_widgets,handles::Tracker_Handles)

    signal_connect(pole_mode_cb,w.pole_mode_button,"clicked",Void,(),false,(handles,))
    signal_connect(pole_select_cb,w.gen_button,"clicked",Void,(),false,(handles,))
    signal_connect(pole_auto_cb,w.auto_button,"clicked",Void,(),false,(handles,))
    signal_connect(pole_delete_cb,w.delete_button,"clicked",Void,(),false,(handles,))

end

function pole_mode_cb(w::Ptr,user_data::Tuple{Tracker_Handles})

    han, = user_data

    #Update DLC parameter file

    nothing
end

function pole_select_cb(w::Ptr,user_data::Tuple{Tracker_Handles})

    han, = user_data

    if getproperty(han.pole_widgets.gen_button,:active,Bool)
        han.selection_mode = 12
        han.view_pole = true
    else
        han.selection_mode = 1
        determine_viewers(han)
    end

    nothing
end

function pole_auto_cb(w::Ptr,user_data::Tuple{Tracker_Handles})

    han, = user_data

    pole_pos = dlc_extra_pole_location(han)

    println("Acquired Pole Positions")

    for i=1:size(han.pole_present,1)

        if isnan(pole_pos[i,1])

        else
            han.pole_present[i] = true
            han.pole_loc[i,1] = convert(Float32,pole_pos[i,1])
            han.pole_loc[i,2] = convert(Float32,pole_pos[i,2])
        end
    end

    nothing
end

function pole_delete_cb(w::Ptr,user_data::Tuple{Tracker_Handles})

    han, = user_data

    han.pole_present[han.frame] = false

    redraw_all(han)

    nothing
end
