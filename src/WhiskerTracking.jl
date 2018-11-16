
module WhiskerTracking

using Gtk.ShortNames, Cairo, Images, StatsBase, ImageFiltering

include("types.jl")
include("gui.jl")
include("janelia_tracker.jl")
include("processing.jl")

end
