
module WhiskerTracking

using Gtk.ShortNames, Cairo, Images, StatsBase, ImageFiltering, MAT, JLD, Interpolations, Distances, DSP, Polynomials,
Pandas, HDF5, PyPlot

if VERSION > v"0.7-"
    using SharedArrays, Libdl
    const Void = Nothing
    const setproperty! = set_gtk_property!
    const getproperty = get_gtk_property
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
include("analysis/forces.jl")
include("analysis/touch.jl")
include("analysis/math.jl")

end
