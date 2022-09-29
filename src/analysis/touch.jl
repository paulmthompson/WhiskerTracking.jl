#=
Analysis methods for finding pole positions and touch locations
=#
#Distance to pole
#(or other landmark)
function calc_p_dist(wx::Array{T,1},wy::Array{T,1},p_x::Real,p_y::Real) where T

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

function calc_p_dist_interp(wx::Array{T,1},wy::Array{T,1},px::Real,py::Real) where T



end

function interpolate_whisker(x::Array{T,1},y::Array{T,1},interp_res = 1.0) where T

    s_t=WhiskerTracking.total_length(x,y)
    s_out = 1.0:interp_res:s_t
    s_in = zeros(Float64,length(x))
    for i=2:length(x)
        s_in[i] = WhiskerTracking.distance_along(x,y,i) + s_in[i-1]
    end

    x_out = zeros(Float64,length(s_out))
    y_out = zeros(Float64,length(s_out))

    x_out[1] = x[1]
    y_out[1] = y[1]
    x_out[end] = x[end]
    y_out[end] = y[end]

    interp_x = interpolate((s_in,),x,Gridded(Linear()))
    interp_y = interpolate((s_in,),y,Gridded(Linear()))


    for i = 2:(length(s_out)-1)
        x_out[i] = interp_x(s_out[i])
        y_out[i] = interp_y(s_out[i])
    end
    (x_out,y_out)
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
    pos_x=Array{Float64,1}()
    pos_y=Array{Float64,1}()

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
            pos_labels[pos_labels.==i] .= 0
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

            pos_labels[pos_labels.==i] .= 0

        end
    end

    non_zero_labels=unique(pos_labels)
    non_zero_labels=non_zero_labels[non_zero_labels.!=0]

    (pos_labels, pos_x[non_zero_labels], pos_y[non_zero_labels])
end

#=
C is a boolean array of contact assigned to each frame. true = contact
exclude is a boolean list of frames to exclude. Exclude = true
c_dur_min is the minimum number of frames to count as a contact
=#

function get_contact_indexes(c,exclude,c_dur_min = 4)

    c_ind=Array{Int64,1}()
    c_off=Array{Int64,1}()

    i=1
    while (i < length(c) - c_dur_min)

        if exclude[i] != true
            if ((c[i] - c[i+1])==-1)
                push!(c_ind,i)
                myoff=findnext(c.==false,i+1)
                if typeof(myoff) == Nothing #single frame contact
                    myoff = i+1
                end

                push!(c_off,myoff)

                i=myoff + 1
            else
                i+=1
            end
        else
            i+= 1
        end
    end

    keep=trues(length(c_ind))
    for i=1:length(c_ind)
        if (c_off[i] - c_ind[i]) < c_dur_min
            keep[i] = false
        end
    end

    (c_ind[keep], c_off[keep])
end
