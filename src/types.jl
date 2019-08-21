
if is_unix()
    const libwhisk_path = "/home/wanglab/Programs/whisk/build/libwhisk.so"
else
    const libwhisk_path = "C:\\Program Files\\WhiskerTracking\\lib\\whisk.dll"
end

jt_parameters = "/home/wanglab/Programs/whisk/build/default.parameters"
libwhisk = Libdl.dlopen(libwhisk_path)
const ffmpeg_path = "/home/wanglab/Programs/ffmpeg/ffmpeg"


mutable struct WT_Image
    kind::Int32 #bytes per pixel
    width::Int32
    height::Int32
    text::Cstring #NULL for TIFF
    array::Ptr{UInt8} #data
end

mutable struct Line_Params
    offset::Float32
    angle::Float32
    width::Float32
    score::Float32
end

mutable struct Seed
    xpnt::Int32
    ypnt::Int32
    xdir::Int32
    ydir::Int32
end

mutable struct Whisker1
    id::Int32
    time::Int32
    len::Int32
    x::Array{Float32,1}
    y::Array{Float32,1}
    thick::Array{Float32,1}
    scores::Array{Float32,1}
end

Whisker1()=Whisker1(0,0,0,Array{Float32}(0),Array{Float32}(0),Array{Float32}(0),Array{Float32}(0))

mutable struct Whisker2
    id::Int32
    time::Int32
    len::Int32
    x::Ptr{Float32}
    y::Ptr{Float32}
    thick::Ptr{Float32}
    scores::Ptr{Float32}
end

function Whisker2(w::Whisker1)
    id=w.id
    time=w.time
    len=w.len
    x=pointer(w.x)
    y=pointer(w.y)
    thick=pointer(w.thick)
    scores=pointer(w.scores)
    Whisker2(id,time,len,x,y,thick,scores)
end

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

struct JT_Measurements
    row::Int32
    fid::Int32
    wid::Int32
    state::Int32 #1 if Whisker, 0 if not. Defaults to 0 when measurements are first made
    face_x::Int32
    face_y::Int32
    col_follicle_x::Int32
    col_follicle_y::Int32
    valid_velocity::Int32
    n::Int32
    face_axis::Cuchar
    data::Ptr{Float64}
    velocity::Ptr{Float64}
end

mutable struct JT_Params
    paramMIN_LENPRJ::Int32
    paramMIN_LENSQR::Int32
    paramMIN_LENGTH::Int32
    paramDUPLICATE_THRESHOLD::Float32
    paramFRAME_DELTA::Int32
    paramHALF_SPACE_TUNNELING_MAX_MOVES::Int32
    paramHALF_SPACE_ASSYMETRY_THRESH::Float32
    paramMAX_DELTA_OFFSET::Float32
    paramMAX_DELTA_WIDTH::Float32
    paramMAX_DELTA_ANGLE::Float32
    paramMIN_SIGNAL::Float32
    paramWIDTH_MAX::Float32
    paramWIDTH_MIN::Float32
    paramWIDTH_STEP::Float32
    paramANGLE_STEP::Float32
    paramOFFSET_STEP::Float32
    paramTLEN::Int32
    paramMIN_SIZE::Int32
    paramMIN_LEVEL::Int32
    paramHAT_RADIUS::Float32
    paramSEED_THRESH::Float32
    paramSEED_ACCUM_THRESH::Float32
    paramSEED_ITERATION_THRESH::Float32
    paramSEED_ITERATIONS::Int32
    paramSEED_SIZE_PX::Int32
    paramSEED_ON_GRID_LATTICE_SPACING::Int32
    paramSEED_METHOD::Int32
    paramIDENTITY_SOLVER_SHAPE_NBINS::Int32
    paramIDENTITY_SOLVER_VELOCITY_NBINS::Int32
    paramCOMPARE_IDENTITIES_DISTS_NBINS::Int32
    paramHMM_RECLASSIFY_BASELINE_LOG2::Float32
    paramHMM_RECLASSIFY_VEL_DISTS_NBINS::Int32
    paramHMM_RECLASSIFY_SHP_DISTS_NBINS::Int32
    paramSHOW_PROGRESS_MESSAGES::Cchar
    paramSHOW_DEBUG_MESSAGES::Cchar
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
end

mutable struct Tracker_Handles
    frame::Int64 #currently active frame number
    win::Gtk.GtkWindowLeaf
    c::Gtk.GtkCanvasLeaf
    frame_slider::Gtk.GtkScaleLeaf
    adj_frame::Gtk.GtkAdjustmentLeaf
    trace_button::Gtk.GtkButtonLeaf

    plot_frame::Array{UInt32,2}
    hist_c::Gtk.GtkCanvasLeaf
    current_frame::Array{UInt8,2}

    woi_id::Int64 #Index in array of displayed whiskers which is whisker of interest.
    woi::Array{Whisker1,1} #Array of properties for whisker of interest for every frame
    woi_x_f::Float64 #last frame whisker follicle position
    woi_y_f::Float64 #last frame whisker follicle position
    woi_follicle::Array{Float64,2} #Array that stores manually curated points of follicle position
    auto_button::Gtk.GtkToggleButtonLeaf
    auto_mode::Bool
    erase_button::Gtk.GtkToggleButtonLeaf
    erase_mode::Bool

    track_attempt::Int64
    tracked::BitArray{1} #Array of true/false to specify if corresponding frame has been tracked

    delete_button::Gtk.GtkButtonLeaf
    combine_button::Gtk.GtkToggleButtonLeaf
    combine_mode::Int64
    partial::Whisker1
    background_button::Gtk.GtkCheckButtonLeaf
    background_mode::Bool
    contrast_min_slider::Gtk.GtkScaleLeaf
    adj_contrast_min::Gtk.GtkAdjustmentLeaf
    contrast_max_slider::Gtk.GtkScaleLeaf
    adj_contrast_max::Gtk.GtkAdjustmentLeaf

    save_button::Gtk.GtkButtonLeaf
    load_button::Gtk.GtkButtonLeaf
    start_frame::Int64
    cov1::Array{Int64,1}
    sharpen_button::Gtk.GtkCheckButtonLeaf
    sharpen_mode::Bool
    anisotropic_button::Gtk.GtkCheckButtonLeaf
    anisotropic_mode::Bool
    local_contrast_button::Gtk.GtkCheckButtonLeaf
    local_contrast_mode::Bool
    draw_button::Gtk.GtkToggleButtonLeaf
    draw_mode::Bool
    connect_button::Gtk.GtkButtonLeaf
    touch_button::Gtk.GtkToggleButtonLeaf
    touch_mode::Bool
    touch_mask::BitArray{2}
    touch_override::Gtk.GtkButtonLeaf
    touch_override_mode::Bool
    touch_frames::BitArray{1}
    woi_angle::Array{Float64,1}
    woi_curv::Array{Float64,1}
    jt_seed_thres_button::Gtk.GtkSpinButtonLeaf
    jt_seed_iterations_button::Gtk.GtkSpinButtonLeaf
    wt::Tracker
    cor_thres::Float64
    stop_flag::Bool
    overwrite_mode::Bool
    overwrite_button::Gtk.GtkCheckButtonLeaf

    discrete_draw::Bool
    discrete_auto_calc::Bool
    d_spacing::Int64

    d_widgets::discrete_widgets
end

ccall((Libdl.dlsym(libwhisk,:Load_Params_File)),Int32,(Cstring,),jt_parameters)
