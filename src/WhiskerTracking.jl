
module WhiskerTracking

using Gtk.ShortNames, Cairo, Images, StatsBase, ImageFiltering, MAT, JLD

include("types.jl")
include("gui.jl")
include("janelia_tracker.jl")
include("processing.jl")

end
