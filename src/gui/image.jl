
function add_image_callbacks(b::Gtk.GtkBuilder,handles::Tracker_Handles)

    signal_connect(adjust_contrast_cb,b["contrast_min_slider"],"value-changed",Void,(),false,(handles,))
    signal_connect(adjust_contrast_cb,b["contrast_max_slider"],"value-changed",Void,(),false,(handles,))

    signal_connect(sharpen_cb,b["sharpen_window"],"value-changed",Void,(),false,(handles,))
    signal_connect(sharpen_cb,b["sharpen_reps"],"value-changed",Void,(),false,(handles,))
    signal_connect(sharpen_cb,b["sharpening_filter_type"],"changed",Void,(),false,(handles,))

    nothing
end

function adjust_contrast_cb(w::Ptr,user_data::Tuple{Tracker_Handles})

    han, = user_data

    try

        han.im_adj.contrast_min = get_gtk_property(han.b["adj_contrast_min"],:value,Int64)
        han.im_adj.contrast_max = get_gtk_property(han.b["adj_contrast_max"],:value,Int64)

        plot_image(han,han.current_frame')

    catch
        println("Error while adjusting contrast")
    end

    nothing
end

function sharpen_cb(w::Ptr,user_data::Tuple{Tracker_Handles})

    han, = user_data

    try

        han.im_adj.sharpen_filter = get_gtk_property(han.b["sharpening_filter_type"],:active,Int64) + 1
        han.im_adj.sharpen_win = get_gtk_property(han.b["adj_sharpen_window"],:value,Int64)
        han.im_adj.sharpen_reps = get_gtk_property(han.b["adj_sharpen_reps"],:value,Int64)

        plot_image(han,han.current_frame')

    catch
        println("Error while adjusting sharpening settings")
    end
    nothing
end

sharpen_mode(b::Gtk.GtkBuilder)=getproperty(b["sharpen_image_button"],:active,Bool)
anisotropic_mode(b::Gtk.GtkBuilder)=getproperty(b["aniso_button"],:active,Bool)
local_contrast_mode(b::Gtk.GtkBuilder)=getproperty(b["local_contrast_enhance"],:active,Bool)
