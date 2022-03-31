

function update_table(han::Tracker_Handles)

    empty!(han.b["whisker_list_store"])

    frame_list = sort(collect(keys(han.woi)))
    for i=1:length(frame_list)
        push!(han.b["whisker_list_store"],(frame_list[i],true))
    end

end
