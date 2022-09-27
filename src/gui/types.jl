
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

mutable struct image_adjustment_settings
    contrast_min::Int64
    contrast_max::Int64
    sharpen_win ::Int64
    sharpen_reps::Int64
    sharpen_filter::Int64
end

image_adjustment_settings()=image_adjustment_settings(0,255,3,1,1)

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

mutable struct Save_Paths
    path::String
    temp::String
    images::String
    backup::String
    DLC::String
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

mutable struct Draw_Area
    surface::Cairo.CairoSurfaceImage{UInt32}
    plot_frame::Array{UInt32,2}
    img2::Array{UInt8,2} #This is the image modified in draw image task
end

function Draw_Area(w,h) 
    surface = CairoImageSurface(zeros(UInt32,h,w), Cairo.FORMAT_RGB24)
    Draw_Area(surface,zeros(UInt32,w,h),zeros(UInt8,w,h))
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

    c::Gtk.GtkCanvasLeaf
    c2::Gtk.GtkCanvasLeaf

    current_frame::Array{UInt8,2}
    current_frame2::Array{UInt8,2}
    

    woi_id::Int64 #Index in array of displayed whiskers which is whisker of interest.
    woi::Dict{Int64,WhiskerTracking.Whisker1} #Dictionary of properties for whisker of interest for every frame
    num_whiskers::Int64
    sw::Int64 #Selected Whisker

    erase_mode::Bool

    tracked::Dict{Int64,Bool} #Array of true/false to specify if corresponding frame has been tracked

    combine_mode::Int64
    partial::Whisker1

    draw_mode::Bool

    wt::Tracker

    im_adj::image_adjustment_settings

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

    mask::Array{Tuple{Float64,Float64},1} #This is a line that goes around the face that will clip the whiskers

    paths::Save_Paths
    temp_frame::Array{UInt8,2}

    draw_area::Draw_Area
end
