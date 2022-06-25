
#=
Only Whiskers are identified that are inside a region of interest (ROI)
That ROI is a circle centered on the whisker pad of radius 100
=#

function apply_roi(whiskers::Array{Whisker1,1},pad_pos::Tuple{Float32,Float32})

    remove_whiskers=Array{Int64,1}()

    #for i=1:length(whiskers)

        #if sqrt((pad_pos[1]-whiskers[i].x[end])^2+(pad_pos[2]-whiskers[i].y[end])^2)>100.0
            #push!(remove_whiskers,i)
        #end
    #end

    #deleteat!(whiskers,remove_whiskers)

    nothing
end

function total_frames(tt,fps)
    h=Base.Dates.hour(tt)
    m=Base.Dates.minute(tt)
    s=Base.Dates.second(tt)
    (h*3600+m*60+s)*fps + 1
end

function frames_between(tt1,tt2,fps)
    total_frames(tt2,fps)-total_frames(tt1,fps)
end

function get_follicle(han::Tracker_Handles)
    x=0.0
    y=0.0
    count=0

    for i=1:length(han.tracked)
        if han.tracked[i]
            x+=han.woi[i].x[end]
            y+=han.woi[i].y[end]
            count+=1
        end
    end
    x=x/count
    y=y/count
    (x,y)
end

function smooth(x, window_len=7)
    w = getfield(DSP.Windows, :lanczos)(window_len)
    DSP.filtfilt(w ./ sum(w), [1.0], x)
end

function assign_woi(han::Tracker_Handles)

    han.woi[han.displayed_frame] = deepcopy(han.wt.whiskers[han.woi_id])

    if get_gtk_property(han.b["tracked_whisker_toggle"],:active,Bool)
        han.tracked_w.whiskers_x[han.displayed_frame] = deepcopy(han.woi[han.displayed_frame].x)
        han.tracked_w.whiskers_y[han.displayed_frame] = deepcopy(han.woi[han.displayed_frame].y)

        han.tracked_w.whiskers_l[han.displayed_frame] = 1.0 # Manual assignment is a loss of zero

        correct_follicle(han.tracked_w.whiskers_x[han.displayed_frame],han.tracked_w.whiskers_y[han.displayed_frame],han.tracked_w.whisker_pad...)

        x = han.tracked_w.whiskers_x[han.displayed_frame]
        y = han.tracked_w.whiskers_y[han.displayed_frame]

        if get_gtk_property(han.b["contact_angle_check"],:active,Bool)
            ii = calc_p_dist(x,y,han.tracked_w.pole_x[han.displayed_frame],han.tracked_w.pole_y[han.displayed_frame])[2]
            han.tracked_w.contact_angle[han.displayed_frame] = get_theta_contact(x,y,ii,true)

            update_normal_angle(han,han.displayed_frame)
        end

        if get_gtk_property(han.b["follicle_location_check"],:active,Bool)
            han.tracked_w.follicle_x[han.displayed_frame] = x[1]
            han.tracked_w.follicle_y[han.displayed_frame] = y[1]
        end

        if get_gtk_property(han.b["follicle_angle_check"],:active,Bool)
            han.tracked_w.follicle_angle[han.displayed_frame] = get_angle(x,y,10.0,30.0)
        end
    end

    update_table(han)

    nothing
end

function get_frame_list(han::Tracker_Handles)
    sort(collect(keys(han.woi)))
end

function get_woi_array(han::Tracker_Handles)
    [han.woi[i] for i in get_frame_list(han)]
end

function get_frame_index(woi,frame_num)
    findfirst(sort(collect(keys(woi))).==frame_num)
end

function WT_length_constraint(whiskers::Array{Whisker1,1},min_length::Int)

    remove_whiskers=Array{Int64,1}()

    #length constraint
    for i=1:length(whiskers)
        if whiskers[i].len<min_length
            push!(remove_whiskers,i)
        end
    end

    deleteat!(whiskers,remove_whiskers)

    nothing
end

function WT_reorder_whisker(whiskers::Array{Whisker1,1},pad_pos::Tuple{Float32,Float32})

    #order whiskers so that the last index is closest to the whisker pad
    for i=1:length(whiskers)
        WT_reorder_whisker(whiskers[i],pad_pos)
    end

    nothing
end

function WT_reorder_whisker(whisker::Whisker1,pad_pos::Tuple{Float32,Float32})

    front_dist = (whisker.x[1]-pad_pos[1])^2+(whisker.y[1]-pad_pos[2])^2
    end_dist = (whisker.x[end]-pad_pos[1])^2+(whisker.y[end]-pad_pos[2])^2

    if front_dist < end_dist #
        reverse!(whisker.x,1)
        reverse!(whisker.y,1)
        reverse!(whisker.scores,1)
        reverse!(whisker.thick,1)
    end
    nothing
end

function eliminate_redundant(whiskers::Array{Whisker1,1},keep_thres=20.0)

    i=1

    while i<length(whiskers)
        w2=[whiskers[i].x[(end-19):end] whiskers[i].y[(end-19):end]]

        mincor=10000.0
        w_id = 0;
        for j=1:length(whiskers)

            if j != i
                w1=[whiskers[j].x[(end-19):end] whiskers[j].y[(end-19):end]]

                mycor=euclidean(w1,w2)
                if mycor < mincor
                    mincor=mycor
                    w_id = i
                end
            end
            if mincor<keep_thres
                w1_score=mean(whiskers[j].scores)
                w2_score=mean(whiskers[i].scores)

                if w1_score > w2_score
                    deleteat!(whiskers,i)
                else
                    deleteat!(whiskers,j)
                end

                i=1
                break
            end
        end
        i+=1
    end

    nothing
end
