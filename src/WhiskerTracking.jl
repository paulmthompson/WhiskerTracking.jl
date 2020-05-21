
module WhiskerTracking

#Standard Library
using StatsBase,Random,Distributed,SharedArrays,DelimitedFiles,LinearAlgebra

#Deep Learning Libraries
using CuArrays, CUDAnative, Knet

using Gtk.ShortNames, Cairo, Images, ImageFiltering, MAT, JLD, Interpolations, Distances, DSP, Polynomials,
Pandas, HDF5, PyPlot, PyCall, ScikitLearn, FFMPEG, FFTW, IterTools

@sk_import ensemble: RandomForestClassifier

if VERSION > v"0.7-"
    using SharedArrays, Libdl, Dates
    const Void = Nothing
    const setproperty! = set_gtk_property!
    const getproperty = get_gtk_property
    const unshift! = pushfirst!
    const is_windows() = Sys.iswindows()
    const is_unix() = Sys.isunix()
    const find = findall
    const indmax = argmax
end

const sp = PyNULL()

include("config.jl")

function __init__()

    ccall((:Load_Params_File,libwhisk_path),Int32,(Cstring,),jt_parameters)
    copy!(sp,pyimport("scipy"))
end

include("types.jl")

include("deep_learning/helper.jl")
include("deep_learning/load.jl")
include("deep_learning/subpixel.jl")
include("deep_learning/cuda_files.jl")

include("gui.jl")
include("janelia_tracker.jl")
include("processing.jl")
include("image_processing.jl")
include("analysis.jl")
include("save_load.jl")
include("dlc.jl")
include("plotting.jl")
include("discrete.jl")

include("gui/whisker_pad.jl")
include("gui/discrete.jl")
include("gui/mask.jl")
include("gui/pole.jl")
include("gui/view.jl")
include("gui/tracing.jl")
include("gui/image.jl")
include("gui/janelia.jl")
include("gui/dlc.jl")
include("gui/export.jl")
include("gui/contact.jl")
include("gui/deeplearning.jl")

include("drawing_tools/draw.jl")
include("drawing_tools/erase.jl")

include("analysis/forces.jl")
include("analysis/touch.jl")
include("analysis/math.jl")

end
