
function _make_janelia_gui()

    janelia_grid=Grid()
    janelia_label=Label("Janelia Parameters")
    janelia_grid[1,1]=janelia_label

    janelia_seed_thres=SpinButton(0.01:.01:1.0)
    setproperty!(janelia_seed_thres,:value,0.99)
    janelia_grid[1,2]=janelia_seed_thres
    janelia_grid[2,2]=Label("Seed Threshold")

    janelia_seed_iterations=SpinButton(1:1:10)
    setproperty!(janelia_seed_iterations,:value,1)
    janelia_grid[1,3]=janelia_seed_iterations
    janelia_grid[1,3]=Label("Seed Iterations")

    janelia_win=Window(janelia_grid)
    Gtk.showall(janelia_win)
    visible(janelia_win,false)

    j_widgets=janelia_widgets(janelia_win,janelia_seed_thres,janelia_seed_iterations)
end

function add_janelia_callbacks(w::janelia_widgets,handles::Tracker_Handles)

    signal_connect(jt_seed_thres_cb,w.jt_seed_thres_button,"value-changed",Void,(),false,(handles,))
    signal_connect(jt_seed_iterations_cb,w.jt_seed_iterations_button,"value-changed",Void,(),false,(handles,))

    nothing
end

function jt_seed_thres_cb(w::Ptr,user_data::Tuple{Tracker_Handles})

    han, = user_data

    thres=getproperty(han.janelia_widgets.jt_seed_thres_button,:value,Float64)

    change_JT_param(:paramSEED_THRESH,convert(Float32,thres))

    nothing
end

function jt_seed_iterations_cb(w::Ptr,user_data::Tuple{Tracker_Handles})

    han, = user_data

    iterations=getproperty(han.janelia_widgets.jt_seed_iterations_button,:value,Int64)

    change_JT_param(:paramSEED_ITERATIONS,convert(Int32,iterations))

    nothing
end
