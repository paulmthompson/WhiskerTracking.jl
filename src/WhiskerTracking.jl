
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

module GUI
    using ..WhiskerTracking
    using Gtk.ShortNames, Cairo, FFMPEG, StackedHourglass
    import ..WhiskerTracking: Whisker1, Tracker, Tracked_Whisker, classifier, NeuralNetwork,
        Manual_Class
    #export WhiskerTracking
    include("gui/types.jl")
    include("gui/save_load.jl")
    include("gui/gui.jl")
    include("gui/manual.jl")
    include("gui/analog.jl")
    include("gui/whisker_pad.jl")
    include("gui/discrete.jl")
    include("gui/mask.jl")
    include("gui/pole.jl")
    include("gui/view.jl")
    include("gui/tracing.jl")
    include("gui/image.jl")
    include("gui/janelia.jl")
    include("gui/export.jl")
    include("gui/contact.jl")
    include("gui/deeplearning.jl")
    include("gui/zoom.jl")
    include("gui/whisker_table.jl")

    include("drawing_tools/draw.jl")
    include("drawing_tools/erase.jl")
    include("drawing_tools/shapes.jl")
end
using .GUI
#include("precompile.jl")
#_precompile()

end
