
function _make_image_gui()

    image_adj_grid = Grid()
    hist_c = Canvas(200,200)
    image_adj_grid[1,1]=hist_c

    contrast_min_slider = Scale(false,0,255,1)
    adj_contrast_min=Adjustment(contrast_min_slider)
    setproperty!(adj_contrast_min,:value,0)
    image_adj_grid[1,2]=contrast_min_slider
    image_adj_grid[2,2]=Label("Minimum")

    contrast_max_slider = Scale(false,0,255,1)
    adj_contrast_max=Adjustment(contrast_max_slider)
    setproperty!(adj_contrast_max,:value,255)
    image_adj_grid[1,3]=contrast_max_slider
    image_adj_grid[2,3]=Label("Maximum")

    background_button = CheckButton("Subtract Background")
    image_adj_grid[1,4]=background_button

    sharpen_button = CheckButton("Sharpen Image")
    image_adj_grid[1,5]=sharpen_button

    aniso_button = CheckButton("Anisotropic Diffusion")
    image_adj_grid[1,6]=aniso_button

    local_contrast_button = CheckButton("Local Contrast Enhancement")
    image_adj_grid[1,7]=local_contrast_button

    image_adj_win = Window(image_adj_grid)
    Gtk.showall(image_adj_win)
    visible(image_adj_win,false)

    ia_widgets = image_adj_widgets(image_adj_win,hist_c,contrast_min_slider,adj_contrast_min,contrast_max_slider,adj_contrast_max,
    background_button,sharpen_button,aniso_button,local_contrast_button)
end

function add_image_callbacks(w,handles)

    signal_connect(adjust_contrast_cb,w.contrast_min_slider,"value-changed",Void,(),false,(handles,))
    signal_connect(adjust_contrast_cb,w.contrast_max_slider,"value-changed",Void,(),false,(handles,))
    signal_connect(background_cb,w.background_button,"clicked",Void,(),false,(handles,))
    signal_connect(sharpen_cb,w.sharpen_button,"clicked",Void,(),false,(handles,))
    signal_connect(aniso_cb,w.anisotropic_button,"clicked",Void,(),false,(handles,))
    signal_connect(local_contrast_cb,w.local_contrast_button,"clicked",Void,(),false,(handles,))

    nothing
end

function adjust_contrast_cb(w::Ptr,user_data::Tuple{Tracker_Handles})

    han, = user_data

    try

        han.wt.contrast_min = getproperty(han.image_adj_widgets.adj_contrast_min,:value,Int64)
        han.wt.contrast_max = getproperty(han.image_adj_widgets.adj_contrast_max,:value,Int64)

        adjust_contrast_gui(han)

        plot_image(han,han.current_frame')

    catch
        println("Error while adjusting contrast")
    end

    nothing
end

function background_cb(w::Ptr,user_data::Tuple{Tracker_Handles})

    han, = user_data

    han.background_mode = getproperty(han.image_adj_widgets.background_button,:active,Bool)

    nothing
end

function sharpen_cb(w::Ptr,user_data::Tuple{Tracker_Handles})

    han, = user_data

    han.sharpen_mode = getproperty(han.image_adj_widgets.sharpen_button,:active,Bool)

    nothing
end

function aniso_cb(w::Ptr,user_data::Tuple{Tracker_Handles})

    han, = user_data

    han.anisotropic_mode = getproperty(han.image_adj_widgets.anisotropic_button,:active,Bool)

    nothing
end

function local_contrast_cb(w::Ptr,user_data::Tuple{Tracker_Handles})

    han, = user_data

    han.local_contrast_mode = getproperty(han.image_adj_widgets.local_contrast_button,:active,Bool)

    nothing
end
