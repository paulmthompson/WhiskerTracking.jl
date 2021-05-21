
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
    data_path::String
    file_name::String
    vid_name::String
    tracking_path::String
    tracking_name::String
    min_length::Int64 #Minimum size of traced element from Janelia tracker, in pixels
    mask::BitArray{2}
    whiskers::Array{Whisker1,1} #Properties of whiskers in active frame
    pad_pos::Tuple{Float32,Float32}
    h::Int64
    w::Int64
    all_whiskers::Array{Array{Whisker1,1},1} #Whiskers on every frame - IS THIS STILL NEEDED?
end

mutable struct discrete_widgets
    win::Gtk.GtkWindowLeaf
    space_button::Gtk.GtkSpinButtonLeaf
    points_button::Gtk.GtkSpinButtonLeaf
    calc_button::Gtk.GtkCheckButtonLeaf
    add_button::Gtk.GtkCheckButtonLeaf
    delete_button::Gtk.GtkButtonLeaf
end

mutable struct janelia_widgets
    win::Gtk.GtkWindowLeaf
    jt_seed_thres_button::Gtk.GtkSpinButtonLeaf
    jt_seed_iterations_button::Gtk.GtkSpinButtonLeaf
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

include("contact_detection.jl")

mutable struct classifier
    tc::TouchClassifier
    w_id::Int64
end

classifier()=classifier(TouchClassifier(64,2,2),1)

mutable struct image_adjustment_settings
    contrast_min::Int64
    contrast_max::Int64
    sharpen_win ::Int64
    sharpen_reps::Int64
    sharpen_filter::Int64
end

image_adjustment_settings()=image_adjustment_settings(0,255,3,1,1)

mutable struct Normalize_Parameters
    mean_img::Array{Float32,3}
    std_img::Array{Float32,3}
    min_ref::Float32
    max_ref::Float32
    num::Int64 #Number of frames to calculate mean over
end

Normalize_Parameters() = Normalize_Parameters(zeros(Float32,0,0,0),zeros(Float32,0,0,0),0,0,10000)

mutable struct NeuralNetwork
    labels::Array{Float32,4} #Labels for training
    imgs::Array{Float32,4} #Images for training
    norm::Normalize_Parameters #Reference values to scale input images
    hg::StackedHourglass.NN #Deep Learning weights
    epochs::Int64
    losses::Array{Float32,1}
    confidence_thres::Float64
    predict_single::Bool
    normalize_inputs::Bool
    weight_path::String
    features::Int64
    draw_preds::Bool
    use_existing_weights::Bool
    use_existing_labels::Bool
    predicted::Array{Float32,3}
end

NeuralNetwork() = NeuralNetwork(zeros(Float32,0,0,0,0),zeros(Float32,0,0,0,0),Normalize_Parameters(), HG2(64,13,4),10,zeros(Float32,0),0.5,false,
true,pre_train_path,1,false,false,false,zeros(Float32,0,3,0))

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

    b::Gtk.GtkBuilder
    max_frames::Int64
    h::Int64
    w::Int64
    fps::Float64
    frame_loaded::Bool
    requested_frame::Int64
    start_frame::Int64 #First frame for analysis (like taking average)
    end_frame::Int64 #last frame for analysis (like taking average)

    c::Gtk.GtkCanvasLeaf

    plot_frame::Array{UInt32,2}

    current_frame::Array{UInt8,2}
    current_frame2::Array{UInt8,2}

    woi_id::Int64 #Index in array of displayed whiskers which is whisker of interest.
    woi::Dict{Int64,WhiskerTracking.Whisker1} #Dictionary of properties for whisker of interest for every frame
    num_whiskers::Int64
    sw::Int64 #Selected Whisker

    auto_mode::Bool
    erase_mode::Bool

    tracked::Dict{Int64,Bool} #Array of true/false to specify if corresponding frame has been tracked

    combine_mode::Int64
    partial::Whisker1

    draw_mode::Bool

    touch_mode::Bool

    touch_override_mode::Bool
    touch_frames::BitArray{1}
    touch_frames_i::Array{Int64,1}
    wt::Tracker

    im_adj::image_adjustment_settings

    discrete_auto_calc::Bool
    d_spacing::Int64

    frame_list::Array{Int64,1}

    displayed_frame::Int64

    contact_widgets::contact_widgets

    pole_present::Dict{Int64,Bool}
    pole_loc::Dict{Int64,Array{Float32,1}}
    send_frame::Array{UInt8,2}

    selection_mode::Int64 #What the mouse will do when you click

    tracked_whiskers_x::Array{Float64,2}
    tracked_whiskers_y::Array{Float64,2}
    tracked_whiskers_l::BitArray{2}

    show_contact::Bool
    tracked_contact::BitArray{1}
    tracked_pole::Array{Float64,2}

    show_event::Bool
    event_array::BitArray{1}
    save_label_path::String

    class::classifier
    nn::NeuralNetwork

    paths::Save_Paths
    temp_frame::Array{UInt8,2}
end
