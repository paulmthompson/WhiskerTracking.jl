
function add_pole_callbacks(b::Gtk.GtkBuilder,handles::Tracker_Handles)

    signal_connect(pole_select_cb,b["select_pole_button"],"clicked",Void,(),false,(handles,))
    signal_connect(pole_auto_cb,b["find_pole_auto"],"clicked",Void,(),false,(handles,))
    signal_connect(pole_delete_cb,b["delete_pole_button"],"clicked",Void,(),false,(handles,))

end

function pole_select_cb(w::Ptr,user_data::Tuple{Tracker_Handles})

    han, = user_data

    if getproperty(han.b["select_pole_button"],:active,Bool)
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

    println("I don't do anything yet")

    nothing
end

function pole_delete_cb(w::Ptr,user_data::Tuple{Tracker_Handles})

    han, = user_data

    han.pole_present[han.frame] = false

    redraw_all(han)

    nothing
end
