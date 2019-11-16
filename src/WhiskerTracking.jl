if VERSION > v"0.7-"
    __precompile__(false)
else

end

module WhiskerTracking

using Gtk.ShortNames, Cairo, Images, StatsBase, ImageFiltering, MAT, JLD, Interpolations, Distances, DSP, Polynomials,
Pandas, HDF5, PyPlot, PyCall, LinearAlgebra

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

const dlc_module = PyNULL()
const dlc_py = PyNULL()
const sp = PyNULL()

include("config.jl")

function __init__()

    ccall((:Load_Params_File,libwhisk_path),Int32,(Cstring,),jt_parameters)

    if is_unix()
        copy!(dlc_module, pyimport("deeplabcut"))

        unshift!(PyVector(pyimport("sys")["path"]), "/home/wanglab/Programs/WhiskerTracking.jl/src")

        copy!(dlc_py,pyimport("dlc_python"))
        copy!(sp,pyimport("scipy"))
    else

        #I have descended into darkness
        myhome=homedir()
        py"""
        import os
        def change_path(x):
            os.environ["PATH"] += os.pathsep + x
        """
        py"change_path"(string(myhome,"\\.julia\\conda\\3"))
        py"change_path"(string(myhome,"\\.julia\\conda\\3\\Library\\mingw-w64\\bin"))
        py"change_path"(string(myhome,"\\.julia\\conda\\3\\Library\\usr\\bin"))
        py"change_path"(string(myhome,"\\.julia\\conda\\3\\Library\\bin"))
        py"change_path"(string(myhome,"\\.julia\\conda\\3\\Scripts"))
        py"change_path"(string(myhome,"\\.julia\\conda\\3\\bin"))
        py"change_path"(string(myhome,"\\.julia\\conda\\3\\condabin"))

        py"""
        import wx
        """

        copy!(dlc_module, pyimport("deeplabcut"))

        unshift!(PyVector(pyimport("sys")["path"]), "$(myhome)\\Documents\\WhiskerTracking.jl\\src")

        copy!(dlc_py,pyimport("dlc_python"))
        copy!(sp,pyimport("scipy"))

    end

end

include("types.jl")
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
include("gui/roi.jl")
include("gui/pole.jl")
include("gui/view.jl")
include("gui/tracing.jl")
include("gui/image.jl")
include("gui/janelia.jl")
include("gui/dlc.jl")
include("gui/export.jl")
include("gui/contact.jl")

include("analysis/forces.jl")
include("analysis/touch.jl")
include("analysis/math.jl")

end
