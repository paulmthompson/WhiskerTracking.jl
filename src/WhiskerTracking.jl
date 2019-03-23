
module WhiskerTracking

using Gtk.ShortNames, Cairo, Images, StatsBase, ImageFiltering, MAT, JLD, Interpolations, Distances, DSP

if VERSION > v"0.7-"
    using SharedArrays, Libdl
    const Void = Nothing
end

include("types.jl")
include("gui.jl")
include("janelia_tracker.jl")
include("processing.jl")
include("image_processing.jl")
include("analysis.jl")

end
