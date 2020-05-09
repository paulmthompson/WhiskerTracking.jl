
mutable struct Whisker1
    id::Int32
    time::Int32
    len::Int32
    x::Array{Float32,1}
    y::Array{Float32,1}
    thick::Array{Float32,1}
    scores::Array{Float32,1}
end

Whisker1()=Whisker1(0,0,0,Array{Float32,1}(),Array{Float32,1}(),Array{Float32,1}(),Array{Float32,1}())

include("janelia_types.jl")

function Whisker1(w::Whisker2)
    id=w.id
    time=w.time
    len=w.len
    x=unsafe_wrap(Array,w.x,len)
    y=unsafe_wrap(Array,w.y,len)
    thick=unsafe_wrap(Array,w.thick,len)
    scores=unsafe_wrap(Array,w.scores,len)
    Whisker1(id,time,len,x,y,thick,scores)
end

mutable struct Tracker
    vid::SharedArray{UInt8,3} #Video pixel data (width x height x frame)
    data_path::String
    file_name::String
    vid_name::String
    whisk_path::String
    meas_path::String
    tracking_path::String
    tracking_name::String
    min_length::Int64 #Minimum size of traced element from Janelia tracker, in pixels
    mask::BitArray{2}
    whiskers::Array{Whisker1,1} #Properties of whiskers in active frame
    pad_pos::Tuple{Float32,Float32}
    contrast_max::Int64
    contrast_min::Int64
    all_whiskers::Array{Array{Whisker1,1},1} #Whiskers on every frame
    w_p::Array{Float32,2}
end

mutable struct discrete_widgets
    win::Gtk.GtkWindowLeaf
    space_button::Gtk.GtkSpinButtonLeaf
    points_button::Gtk.GtkSpinButtonLeaf
    calc_button::Gtk.GtkCheckButtonLeaf
    add_button::Gtk.GtkCheckButtonLeaf
    delete_button::Gtk.GtkButtonLeaf
end

mutable struct mask_widgets
    win::Gtk.GtkWindowLeaf
    gen_button::Gtk.GtkCheckButtonLeaf
    max_button::Gtk.GtkSpinButtonLeaf
    min_button::Gtk.GtkSpinButtonLeaf
end

mutable struct pad_widgets
    win::Gtk.GtkWindowLeaf
    gen_button::Gtk.GtkCheckButtonLeaf
end

mutable struct roi_widgets
    win::Gtk.GtkWindowLeaf
    gen_button::Gtk.GtkCheckButtonLeaf
    height_button::Gtk.GtkSpinButtonLeaf
    width_button::Gtk.GtkSpinButtonLeaf
    tilt_button::Gtk.GtkSpinButtonLeaf
end

mutable struct pole_widgets
    win::Gtk.GtkWindowLeaf
    pole_mode_button::Gtk.GtkCheckButtonLeaf
    gen_button::Gtk.GtkCheckButtonLeaf
    auto_button::Gtk.GtkButtonLeaf
    touch_button::Gtk.GtkCheckButtonLeaf
    delete_button::Gtk.GtkButtonLeaf
    use_pole_tracked_button::Gtk.GtkButtonLeaf
end

mutable struct view_widgets
    win::Gtk.GtkWindowLeaf
    whisker_pad_button::Gtk.GtkCheckButtonLeaf
    roi_button::Gtk.GtkCheckButtonLeaf
    discrete_button::Gtk.GtkCheckButtonLeaf
    pole_button::Gtk.GtkCheckButtonLeaf
    tracked_button::Gtk.GtkCheckButtonLeaf
end

mutable struct manual_widgets
    win::Gtk.GtkWindowLeaf
    connect_button::Gtk.GtkButtonLeaf
    combine_button::Gtk.GtkToggleButtonLeaf
end

mutable struct image_adj_widgets
    win::Gtk.GtkWindowLeaf
    hist_c::Gtk.GtkCanvasLeaf
    contrast_min_slider::Gtk.GtkScaleLeaf
    adj_contrast_min::Gtk.GtkAdjustmentLeaf
    contrast_max_slider::Gtk.GtkScaleLeaf
    adj_contrast_max::Gtk.GtkAdjustmentLeaf
    background_button::Gtk.GtkCheckButtonLeaf
    sharpen_button::Gtk.GtkCheckButtonLeaf
    anisotropic_button::Gtk.GtkCheckButtonLeaf
    local_contrast_button::Gtk.GtkCheckButtonLeaf
end

mutable struct janelia_widgets
    win::Gtk.GtkWindowLeaf
    jt_seed_thres_button::Gtk.GtkSpinButtonLeaf
    jt_seed_iterations_button::Gtk.GtkSpinButtonLeaf
end

mutable struct dlc_widgets
    win::Gtk.GtkWindowLeaf
    create_button::Gtk.GtkButtonLeaf
    export_button::Gtk.GtkButtonLeaf
    with_pole_button::Gtk.GtkCheckButtonLeaf
    train_button::Gtk.GtkButtonLeaf
    analyze_button::Gtk.GtkButtonLeaf
    weights_label::Gtk.GtkLabelLeaf
    load_weights_button::Gtk.GtkButtonLeaf
    create_training_button::Gtk.GtkButtonLeaf
    select_network_button::Gtk.GtkButtonLeaf
end

mutable struct export_widgets
    win::Gtk.GtkWindowLeaf
    face_axis::Gtk.GtkComboBoxTextLeaf
    angle_button::Gtk.GtkCheckButtonLeaf
    curve_button::Gtk.GtkCheckButtonLeaf
    phase_button::Gtk.GtkCheckButtonLeaf
    export_button::Gtk.GtkButtonLeaf
end

mutable struct contact_widgets
    win::Gtk.GtkWindowLeaf
    training_num_label::Gtk.GtkLabelLeaf
    fit_button::Gtk.GtkButtonLeaf
    load_predicted_button::Gtk.GtkButtonLeaf
    n_estimators_button::Gtk.GtkSpinButtonLeaf
    forest_depth_button::Gtk.GtkSpinButtonLeaf
    cv_label::Gtk.GtkLabelLeaf
    pred_pole_button::Gtk.GtkCheckButtonLeaf
    pred_pole_position::Gtk.GtkCheckButtonLeaf
    pred_curv::Gtk.GtkCheckButtonLeaf
end

mutable struct deep_learning_widgets
    win::Gtk.GtkWindowLeaf
    prog::Gtk.GtkProgressBar
    create_button::Gtk.GtkButtonLeaf
    train_button::Gtk.GtkButtonLeaf
end

mutable struct classifier
    predictors::Array{Float64,2}
    n_estimators::Int64
    forest_depth::Int64
    clf::PyObject
    cv::Float64
end

classifier()=classifier(zeros(Float64,1,1),100,10,PyObject(1),0.0)

mutable struct Normalize_Parameters
    mean_img::Array{Float32,3}
    std_img::Array{Float32,3}
    min_ref::Float32
    max_ref::Float32
end

Normalize_Parameters() = Normalize_Parameters(zeros(Float32,0,0,0),zeros(Float32,0,0,0),0,0)

abstract type NN end;

include("deep_learning/hourglass/residual.jl")
include("deep_learning/hourglass/hourglass.jl")

mutable struct NeuralNetwork
    labels::Array{Float32,4} #Labels for training
    imgs::Array{Float32,4} #Images for training
    norm::Normalize_Parameters #Reference values to scale input images
    hg::NN #Deep Learning weights
    epochs::Int64
    losses::Array{Float32,1}
end

NeuralNetwork() = NeuralNetwork(zeros(Float32,0,0,0,0),zeros(Float32,0,0,0,0),Normalize_Parameters(), HG2(64,13,4),10,zeros(Float32,0))

mutable struct Save_Paths
    path::String
    temp::String
    images::String
    backup::String
    DLC::String
end

mutable struct DLC_Wrapper
end

function Save_Paths(mypath,make_dirs=true)

    if make_dirs
        mkdir(mypath)
    end

    if is_windows()
        out=Save_Paths(mypath,string(mypath,"\\temp"),string(mypath,"\\images"),string(mypath,"\\backup"),string(mypath,"\\DLC"))
    else
        out=Save_Paths(mypath,string(mypath,"/temp"),string(mypath,"/images"),string(mypath,"/backup"),string(mypath,"/DLC"))
    end

    if make_dirs
        mkdir(out.temp)
        mkdir(out.images)
        mkdir(out.backup)
        mkdir(out.DLC)
    end

    out
end

mutable struct Tracker_Handles
    frame::Int64 #currently active frame number
    kept_frames::Int64
    max_frames::Int64
    win::Gtk.GtkWindowLeaf
    c::Gtk.GtkCanvasLeaf
    frame_slider::Gtk.GtkScaleLeaf
    adj_frame::Gtk.GtkAdjustmentLeaf
    trace_button::Gtk.GtkButtonLeaf

    plot_frame::Array{UInt32,2}

    current_frame::Array{UInt8,2}
    current_frame2::Array{UInt8,2}

    woi_id::Int64 #Index in array of displayed whiskers which is whisker of interest.
    woi::Array{Whisker1,1} #Array of properties for whisker of interest for every frame
    num_whiskers::Int64
    num_whiskers_sb::Gtk.GtkSpinButtonLeaf
    sw::Int64 #Selected Whisker

    auto_mode::Bool
    erase_button::Gtk.GtkToggleButtonLeaf
    erase_mode::Bool

    track_attempt::Int64
    tracked::BitArray{1} #Array of true/false to specify if corresponding frame has been tracked

    delete_button::Gtk.GtkButtonLeaf

    combine_mode::Int64
    partial::Whisker1

    background_mode::Bool

    start_frame::Int64

    sharpen_mode::Bool
    anisotropic_mode::Bool
    local_contrast_mode::Bool

    draw_button::Gtk.GtkToggleButtonLeaf
    draw_mode::Bool

    touch_mode::Bool

    touch_override::Gtk.GtkButtonLeaf
    touch_no_contact::Gtk.GtkButtonLeaf
    touch_override_mode::Bool
    touch_frames::BitArray{1}
    touch_frames_i::Array{Int64,1}
    woi_angle::Array{Float64,1}
    woi_curv::Array{Float64,1}
    wt::Tracker
    cor_thres::Float64
    stop_flag::Bool

    discrete_draw::Bool
    discrete_auto_calc::Bool
    d_spacing::Int64

    ts_canvas::Gtk.GtkCanvasLeaf
    frame_list::Array{Int64,1}
    frame_advance_sb::Gtk.GtkSpinButtonLeaf
    displayed_frame::Int64

    d_widgets::discrete_widgets
    mask_widgets::mask_widgets
    pad_widgets::pad_widgets
    roi_widgets::roi_widgets
    pole_widgets::pole_widgets
    view_widgets::view_widgets
    manual_widgets::manual_widgets
    image_adj_widgets::image_adj_widgets
    janelia_widgets::janelia_widgets
    dlc_widgets::dlc_widgets
    export_widgets::export_widgets
    contact_widgets::contact_widgets
    dl_widgets::deep_learning_widgets

    pole_present::BitArray{1}
    pole_loc::Array{Float32,2}
    send_frame::Array{UInt8,2}

    view_pad::Bool
    view_roi::Bool
    view_pole::Bool

    selection_mode::Int64 #What the mouse will do when you click

    show_tracked::Bool
    tracked_whiskers_x::Array{Float64,2}
    tracked_whiskers_y::Array{Float64,2}
    tracked_whiskers_l::BitArray{2}

    show_contact::Bool
    tracked_contact::BitArray{1}
    tracked_pole::Array{Float64,2}

    class::classifier
    nn::NeuralNetwork

    paths::Save_Paths
    temp_frame::Array{UInt8,2}
end
