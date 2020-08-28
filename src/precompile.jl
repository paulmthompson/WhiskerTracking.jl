
function _precompile()

    precompile(Tuple{Tracker_Handles})
    precompile(Tuple{Tracker_Handles,Int})

    han = make_gui();
    add_callbacks(han.b,han)

    nothing
end
