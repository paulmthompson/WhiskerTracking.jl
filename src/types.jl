
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

function classifier()
    if CUDA.has_cuda_gpu()
        classifier(TouchClassifier(64,2,2),1)
    else
        classifier(TouchClassifier(64,2,2,Array),1)
    end
end

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

mutable struct Manual_Class
    max_frames::Int64

    partial_contact::Int64
    contact_block::Array{Tuple,1} #Contact on and off tuples
    no_contact_block::Array{Tuple,1} #No Contact on and off
    contact::Array{Int64,1} #Manually classified contact frames; 0 is not manual; 1 = no contact; 2 = contact

    calc_contact_block::Array{Tuple,1}

    pro_re::Dict{Int,Int}
    pro_re_block::Array{Int64,1}

    exclude::Array{Tuple,1}
    exclude_block::BitArray{1}
end

Manual_Class() = Manual_Class(0,1,Array{Tuple,1}(),Array{Tuple,1}(),Array{Int64,1}(),Array{Tuple,1}(),Dict{Int,Int}(),Array{Int64,1}(),Array{Tuple,1}(),falses(1))

Manual_Class(frame_num::Int) = Manual_Class(frame_num,1,Array{Tuple,1}(),Array{Tuple,1}(),
zeros(Int64,frame_num),Array{Tuple,1}(),Dict{Int,Int}(),zeros(Int64,frame_num),Array{Tuple,1}(),falses(frame_num))

mutable struct Analog_Class
    c::Gtk.GtkCanvasLeaf
    t_zoom::Int64
    show::Bool
    cam::Array{Float64,1}
    var::Dict{Int64,Array{Float64,1}}
    ts::Dict{Int64,Array{Float64,1}}
    ts_d::Dict{Int64,Array{Float64,1}}
    gains::Dict{Int64,Float64}
end

Analog_Class() = Analog_Class(Canvas(100,100),100,false,zeros(Float64,0),Dict{Int64,Array{Float64,1}}(),Dict{Int64,Array{Float64,1}}(),
Dict{Int64,Array{Float64,1}}(),Dict{Int64,Float64}())

mutable struct Zoom_Class
    c::Gtk.GtkCanvasLeaf
    w1::Int64
    w2::Int64
    h1::Int64
    h2::Int64
end

Zoom_Class() = Zoom_Class(Canvas(100,100),1,100,1,100)

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
    flip_x::Bool
    flip_y::Bool
end

function NeuralNetwork()
    if CUDA.has_cuda_gpu()
        hg = HG2(64,13,4)
    else
        hg = HG2(64,13,4, Array)
    end
    NeuralNetwork(zeros(Float32,0,0,0,0),zeros(Float32,0,0,0,0),Normalize_Parameters(), hg,10,zeros(Float32,0),0.5,false,
true,pre_train_path,1,false,false,false,zeros(Float32,0,3,0),false,false)
end
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

mutable struct Tracked_Whisker
    whiskers_x::Vector{Vector{Float64}}
    whiskers_y::Vector{Vector{Float64}}
    whiskers_l::Vector{Float64}
    pole_x::Array{Float64,1}
    pole_y::Array{Float64,1}
    follicle_x::Array{Float64,1}
    follicle_y::Array{Float64,1}
    follicle_angle::Array{Float64,1}
    contact_angle::Array{Float64,1}
    normal_angle::Array{Float64,1}
end

function Tracked_Whisker(n)
    Tracked_Whisker([zeros(Float64,0) for i=1:n],[zeros(Float64,0) for i=1:n],1000.0 .* ones(Float64,n),zeros(Float64,n),zeros(Float64,n),zeros(Float64,n),
    zeros(Float64,n),zeros(Float64,n),zeros(Float64,n),zeros(Float64,n))
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
    c2::Gtk.GtkCanvasLeaf

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

    tracked_w::Tracked_Whisker
    draw_mechanics::Bool

    show_contact::Bool
    tracked_contact::BitArray{1}
    show_tracked_whisker::Bool

    show_event::Bool
    event_array::BitArray{1}
    save_label_path::String

    class::classifier
    analog::Analog_Class
    zoom::Zoom_Class
    nn::NeuralNetwork
    man::Manual_Class
    speed::Int64

    paths::Save_Paths
    temp_frame::Array{UInt8,2}
end
