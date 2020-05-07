

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
