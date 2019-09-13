#=
Analysis methods for finding pole positions and touch locations
=#
#Distance to pole
#(or other landmark)
function calc_p_dist(wx,wy,p_x,p_y)

    p_dist=1000.0
    p_id=1

    for i=1:length(wx)

        mydist = sqrt((wx[i]-p_x)^2 + (wy[i]-p_y)^2)
        if mydist < p_dist
            p_dist = mydist
            p_id=i
        end

    end
    (p_dist,p_id)
end

function get_p_distances(wx,wy,p::Array{T,2}) where T
    pd=1000.0.*ones(Float64,length(wx))

    for i=1:length(wx)
        pd[i]=WhiskerTracking.calc_p_dist(wx[i],wy[i],p[i,1],p[i,2])[1]
    end

    pd
end


#Finds the number of unique pole positions (pole positions within threshold radius)
function get_p_pos(p,new_thres=50.0)

    pos_labels=zeros(Int64,size(p,1))

    num_labels=0
    pos_x=Array{Float64}(0)
    pos_y=Array{Float64}(0)

    for i=1:size(p,1)
        if !isnan(p[i,1])

            new_label_flag=true

            for j=1:num_labels

                if sqrt((p[i,1]-pos_x[j])^2+(p[i,2]-pos_y[j])^2) < new_thres
                    new_label_flag=false
                    pos_labels[i] = j
                    break
                end
            end

            if new_label_flag
                num_labels += 1
                push!(pos_x,p[i,1])
                push!(pos_y,p[i,2])
                pos_labels[i]=num_labels
            end
        else

            pos_labels[i]=0

        end
    end

    for i=1:num_labels
        if length(find(pos_labels.==i))<1000
            pos_labels[pos_labels.==i] = 0
        end
    end

    for i=unique(pos_labels)

        max_in_a_row=0
        temp_in_a_row=0
        in_a_row=false

        for j=1:length(pos_labels)-1

            if pos_labels[j]==i

                if in_a_row
                    temp_in_a_row += 1

                else
                    temp_in_a_row = 1
                    in_a_row = true
                end

            elseif in_a_row

                in_a_row = false
                if temp_in_a_row > max_in_a_row
                    max_in_a_row = temp_in_a_row
                end

            end
        end

        if max_in_a_row < 500

            pos_labels[pos_labels.==i] = 0

        end
    end

    non_zero_labels=unique(pos_labels)
    non_zero_labels=non_zero_labels[non_zero_labels.!=0]

    (pos_labels, pos_x[non_zero_labels], pos_y[non_zero_labels])
end
