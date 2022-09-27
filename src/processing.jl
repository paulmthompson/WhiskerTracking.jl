function total_frames(tt,fps)
    h=Base.Dates.hour(tt)
    m=Base.Dates.minute(tt)
    s=Base.Dates.second(tt)
    (h*3600+m*60+s)*fps + 1
end

function frames_between(tt1,tt2,fps)
    total_frames(tt2,fps)-total_frames(tt1,fps)
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
