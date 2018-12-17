
const libwhisk_path = "/home/wanglab/Programs/whisk/build/libwhisk.so"
jt_parameters = "/home/wanglab/Programs/whisk/build/default.parameters"
libwhisk = Libdl.dlopen(libwhisk_path)
const ffmpeg_path = "/home/wanglab/Programs/ffmpeg/ffmpeg"


type WT_Image
    kind::Int32 #bytes per pixel
    width::Int32
    height::Int32
    text::Cstring #NULL for TIFF
    array::Ptr{UInt8} #data
end

type Whisker1
    id::Int32
    time::Int32
    len::Int32
    x::Array{Float32,1}
    y::Array{Float32,1}
    thick::Array{Float32,1}
    scores::Array{Float32,1}
end

Whisker1()=Whisker1(0,0,0,Array{Float32}(0),Array{Float32}(0),Array{Float32}(0),Array{Float32}(0))

type Whisker2
    id::Int32
    time::Int32
    len::Int32
    x::Ptr{Float32}
    y::Ptr{Float32}
    thick::Ptr{Float32}
    scores::Ptr{Float32}
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

type JT_Params
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

type Tracker_Handles
    data_path::String
    file_name::String
    vid_name::String
    whisk_path::String
    meas_path::String
    win::Gtk.GtkWindowLeaf
    c::Gtk.GtkCanvasLeaf
    vid::Array{UInt8,3}
    frame::Int64
    frame_slider::Gtk.GtkScaleLeaf
    adj_frame::Gtk.GtkAdjustmentLeaf
    trace_button::Gtk.GtkButtonLeaf
    whiskers::Array{Whisker1,1}
    plot_frame::Array{UInt32,2}
    hist_c::Gtk.GtkCanvasLeaf
    current_frame::Array{UInt8,2}
    min_length::Int64 #In pixels
    woi_id::Int64
    woi::Array{Whisker1,1}
    woi_x_f::Float64
    woi_y_f::Float64
    auto_button::Gtk.GtkToggleButtonLeaf
    auto_mode::Bool
    erase_button::Gtk.GtkToggleButtonLeaf
    erase_mode::Bool
    mask::BitArray{2}
    track_attempt::Int64
    tracked::BitArray{1}
    pad_pos::Tuple{Float32,Float32}
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
    contrast_max::Int64
    contrast_min::Int64
    save_button::Gtk.GtkButtonLeaf
    load_button::Gtk.GtkButtonLeaf
    start_frame::Int64
end

ccall((Libdl.dlsym(libwhisk,:Load_Params_File)),Int32,(Cstring,),jt_parameters)
