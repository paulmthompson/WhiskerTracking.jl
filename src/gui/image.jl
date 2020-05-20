
function add_image_callbacks(b::Gtk.GtkBuilder,handles::Tracker_Handles)

    signal_connect(adjust_contrast_cb,b["contrast_max_slider"],"value-changed",Void,(),false,(handles,))
    signal_connect(adjust_contrast_cb,b["contrast_max_slider"],"value-changed",Void,(),false,(handles,))

    nothing
end

function adjust_contrast_cb(w::Ptr,user_data::Tuple{Tracker_Handles})

    han, = user_data

    try

        #han.wt.contrast_min = getproperty(han.image_adj_widgets.adj_contrast_min,:value,Int64)
        #han.wt.contrast_max = getproperty(han.image_adj_widgets.adj_contrast_max,:value,Int64)

        adjust_contrast_gui(han)

        plot_image(han,han.current_frame')

    catch
        println("Error while adjusting contrast")
    end

    nothing
end

background_mode(b::Gtk.GtkBuilder)=getproperty(b["subtract_background_button"],:active,Bool)
sharpen_mode(b::Gtk.GtkBuilder)=getproperty(b["sharpen_image_button"],:active,Bool)
anisotropic_mode(b::Gtk.GtkBuilder)=getproperty(b["aniso_button"],:active,Bool)
local_contrast_mode(b::Gtk.GtkBuilder)=getproperty(b["local_contrast_enhance"],:active,Bool)
