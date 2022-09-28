
module WhiskerTracking

#Standard Library
using Statistics,Random,Distributed,SharedArrays,DelimitedFiles,LinearAlgebra, Libdl, Dates

#Deep Learning Libraries
#using CuArrays, CuArrays.CUFFT, CUDAnative, Knet
using CUDA, Knet

using Images, ImageFiltering, MAT, JLD2, Interpolations, DSP,
FFTW, IterTools, FFMPEG, StackedHourglass, Polynomials, StatsBase

include("config.jl")

function __init__()
    ccall((:Load_Params_File,libwhisk_path),Int32,(Cstring,),jt_parameters)
end

include("types.jl")

include("deep_learning/helper.jl")
include("deep_learning/save_load.jl")
include("deep_learning/prediction.jl")
include("deep_learning/config.jl")
include("deep_learning/training.jl")

include("janelia_tracker.jl")
include("processing.jl")
include("image_processing.jl")
include("analysis.jl")
include("save_load.jl")
include("discrete.jl")

include("analysis/follicle.jl")
include("analysis/kinematics.jl")
include("analysis/forces.jl")
include("analysis/touch.jl")
include("analysis/math.jl")

end
