
module WhiskerTracking

using Gtk.ShortNames, Cairo, Images, StatsBase, ImageFiltering, MAT, JLD, Interpolations

include("types.jl")
include("gui.jl")
include("janelia_tracker.jl")
include("processing.jl")

end
