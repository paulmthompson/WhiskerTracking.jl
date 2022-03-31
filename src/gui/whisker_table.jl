

function update_table(han::Tracker_Handles)

    table_list=ListStore(Int32,Bool)

    for i=1:length(han.frame_list)
        push!(table_list,(han.frame_list[i],true))
    end

    han.b["whisker_list_store"] = table_list
end
