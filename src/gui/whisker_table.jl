

function add_table_callbacks(b::Gtk.GtkBuilder,handles::Tracker_Handles)

    signal_connect(select_row_cb,b["frame_tree_view"],"row-activated",Void,(Ptr{TreePath},Ptr{TreeViewColumn}),false,(handles,))

    nothing
end

function update_table(han::Tracker_Handles)

    empty!(han.b["whisker_list_store"])

    frame_list = sort(collect(keys(han.woi)))
    for i=1:length(frame_list)
        push!(han.b["whisker_list_store"],(frame_list[i],true))
    end

end

function select_row_cb(w::Ptr,path::Ptr,col::Ptr,user_data::Tuple{Tracker_Handles})

    han, = user_data

    selmodel=Gtk.GAccessor.selection(han.b["frame_tree_view"])
    iter=Gtk.selected(selmodel)
    myind=parse(Int64,Gtk.get_string_from_iter(TreeModel(han.b["whisker_list_store"]), iter))+1
    frame = han.b["whisker_list_store"][myind][1]

    set_gtk_property!(han.b["adj_frame"],:value,frame)

    nothing
end
