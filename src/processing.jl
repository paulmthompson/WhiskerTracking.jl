
function adjust_contrast_gui(han::Tracker_Handles)
    han.current_frame=adjust_contrast(han.current_frame,han.wt.contrast_min,han.wt.contrast_max)
    nothing
end

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

#Need to optimize this significantly
#Really we want this to be such that the length of each line is equal.
#Probably can do this by interpolating along each segment or something
#I also need to reverse these

whisker_similarity(han) = whisker_similarity(han,1)

function whisker_similarity(han::Tracker_Handles,prev)

    cor_length=20

    w2_x=han.woi[han.frame-prev].x
    w2_y=han.woi[han.frame-prev].y
    mincor=10000.0.*ones(length(han.wt.whiskers))
    w_id = 0;
    for i=1:length(han.wt.whiskers)
        w1_x=han.wt.whiskers[i].x
        w1_y=han.wt.whiskers[i].y

        for j=1:(size(w1_x,1)-cor_length)
            for k=1:(size(w2_x,1)-cor_length)
                mycor=w_dist(w1_x,w2_x,w1_y,w2_y,j,k,cor_length)
                if mycor < mincor[i]
                    mincor[i]=mycor
                end
            end
        end
    end
    findmin(mincor)
end

function w_dist(x1,x2,y1,y2,i1,i2,cor_length)

    mysum=0.0
    for jj=1:cor_length
        mysum += sqrt((x2[i2+jj] - x1[i1+jj]) ^ 2 + (y2[i2+jj] - y1[i1+jj]) ^2)
    end
    mysum
end

function smooth(x, window_len=7)
    w = getfield(DSP.Windows, :lanczos)(window_len)
    DSP.filtfilt(w ./ sum(w), [1.0], x)
end

function assign_woi(han::Tracker_Handles)

    han.woi[han.displayed_frame] = deepcopy(han.wt.whiskers[han.woi_id])

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

#Order anterior to posterior
function reorder_whiskers(wt::Tracker)

    for i=1:length(wt.all_whiskers)

        xpos=[wt.all_whiskers[i][j].x[end] for j=1:length(wt.all_whiskers[i])]
        wt.all_whiskers[i]=wt.all_whiskers[i][sortperm(xpos)]
    end

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
