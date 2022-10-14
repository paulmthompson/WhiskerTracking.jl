
function extend_mask(mask,dist)

    w = size(mask,1)
    h = size(mask,2)

    out_mask = zeros(Float64,size(mask))

    for i=1:h
        for j=1:w
            if (out_mask[j,i] == 0.0)
                for ii = -dist:dist
                    if ((i + ii) > 0) && ((i + ii) <= h)
                        for jj = -dist:dist 
                            if ((j + jj) > 0) && ((j + jj) <= w)
                                if mask[j+jj,i+ii] == 1.0
                                    d = sqrt((jj)^2 + (ii)^2)
                                    if (d < dist)
                                        out_mask[j,i] = 1.0
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    out_mask
end

function load_mask_into_tracker(wt::Tracker,path::String,extend=30)
    wt.mask = load_mask_png(path)
    wt.extended_mask = extend_mask(wt.mask,extend)
    nothing
end

function check_mask_bounds(x_ind,y_ind,mask)
    if (x_ind < 1) || (y_ind < 1)
        return false
    end
    if (y_ind > size(mask,1)) || (x_ind > size(mask,2))
        return false
    end
    return true
end

#=
Calculates the whisker angle at the intersection of the extended mask
=#

function find_angle_clipping(w_x,w_y,wt::WhiskerTracking.Tracker,angle_samples=5)
    find_angle_clipping(w_x,w_y,wt.extended_mask,angle_samples)
end

function find_angle_clipping(w_x,w_y,extended_mask,angle_samples=5)
    
    out_ind = 1
    x_ind = round(Int,w_x[1])
    y_ind = round(Int,w_y[1])
    for i=1:length(w_x)
        x_ind = round(Int,w_x[i])
        y_ind = round(Int,w_y[i])

        if !check_mask_bounds(x_ind,y_ind,extended_mask)
            out_ind = angle_samples
            break
        end

        if (!extended_mask[y_ind,x_ind]) #Find first index without a mask
            out_ind = i
            break
        end
    end

    if (out_ind == 1)
        out_ind = 2
    end

    n0=0
    n1=0
    v_x1 = 0.0
    v_y1 = 0.0
    v_x0 = 0.0
    v_y0 = 0.0

    for i=1:angle_samples
        if (out_ind + i) < length(w_x)
            v_y1 += (w_y[out_ind + i])
            v_x1 += (w_x[out_ind + i])
            n1 += 1
        end
        if (out_ind - i + 1) > 0
            v_y0 += w_y[out_ind - i + 1]
            v_x0 += w_x[out_ind - i + 1]
            n0 += 1
        end
    end

    yy = v_y1 / n1 - v_y0 / n0 
    xx = v_x1 / n1 - v_x0 / n0
    theta = atan(yy, xx)

    (theta,out_ind,xx,yy)
end

#=
Find first ind that is not masked in whisker
=#

function mask_tracked_whisker(w_x,w_y,wt::WhiskerTracking.Tracker,thres=30.0)

    (theta,out_ind,xx,yy) = find_angle_clipping(w_x,w_y,wt)

    mask_tracked_whisker(w_x,w_y,theta,out_ind,xx,yy,wt.mask,thres=30.0)
end

function mask_tracked_whisker(w_x,w_y,theta,out_ind,xx,yy,mask,thres=30.0)

    x = w_x[out_ind]
    y = w_y[out_ind]

    x_ind = round(Int,x)
    y_ind = round(Int,y)

    while (!mask[y_ind,x_ind]) #loop until we hit fur

        x += cos(theta + pi)
        y += sin(theta + pi)

        x_ind = round(Int,x)
        y_ind = round(Int,y)

        if !check_mask_bounds(x_ind,y_ind,mask)
            break
        end
    end

    d = 0.0
    x_0 = x
    y_0 = y
    while (d < thres)
        x += cos(theta)
        y += sin(theta)

        d = sqrt((x - x_0)^2 + (y-y_0)^2)
    end

    (out_ind,x_0,y_0,x,y)
end

function apply_mask(whiskers::Array{Whisker1,1},mask::BitArray{2},min_length::Int64)

    remove_whiskers=Array{Int64,1}()

    for i=1:length(whiskers)
        delete_points=Array{Int64,1}()

        #Start at the tip and work our way back to the follicle.
        #If the mask hits something, we should probably delete all points following
        for j=1:length(whiskers[i].x)
            x_ind = round(Int64,whiskers[i].y[j])
            y_ind = round(Int64,whiskers[i].x[j])

            if x_ind<1
                x_ind=1
            elseif x_ind>size(mask,1)
                x_ind=size(mask,1)
            end

            if y_ind<1
                y_ind=1
            elseif y_ind>size(mask,2)
                y_ind=size(mask,2)
            end

            if mask[x_ind,y_ind]
                for k=j:length(whiskers[i].x)
                    push!(delete_points,k)
                end
                break
            end
        end

        deleteat!(whiskers[i].x,delete_points)
        deleteat!(whiskers[i].y,delete_points)
        deleteat!(whiskers[i].thick,delete_points)
        deleteat!(whiskers[i].scores,delete_points)
        whiskers[i].len = length(whiskers[i].x)

        #Sometimes whiskers are detected in mask of reasonable length, so they are completely deleted
        #In this step and will mess up later processing, so we should delete them after a length check
        if whiskers[i].len < min_length
            push!(remove_whiskers,i)
        end

    end

    deleteat!(whiskers,remove_whiskers)

    nothing
end
