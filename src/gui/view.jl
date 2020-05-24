
function add_view_callbacks(b::Gtk.GtkBuilder,handles::Tracker_Handles)

    signal_connect(view_pole_cb,b["select_pole_button"],"clicked",Void,(),false,(handles,))
    signal_connect(view_discrete_cb,b["view_discrete_points"],"clicked",Void,(),false,(handles,))
    signal_connect(view_whiskers_cb,b["view_tracked"],"clicked",Void,(),false,(handles,))

    nothing
end

view_pole(b::Gtk.GtkBuilder)=getproperty(b["select_pole_button"],:active,Bool)
view_discrete(b::Gtk.GtkBuilder)=getproperty(b["view_discrete_points"],:active,Bool)
show_tracked(b::Gtk.GtkBuilder)=getproperty(b["view_tracked"],:active,Bool)

function view_pole_cb(w::Ptr,user_data::Tuple{Tracker_Handles})

    han, = user_data
    redraw_all(han)
    nothing
end

function view_discrete_cb(w::Ptr,user_data::Tuple{Tracker_Handles})

    han, = user_data
    redraw_all(han)
    nothing
end

function view_whiskers_cb(w::Ptr,user_data::Tuple{Tracker_Handles})

    han, = user_data
    redraw_all(han)
    nothing
end
