


function distance_along(x::Array{T,1},y::Array{T,1},i::Int64) where T
    sqrt((y[i]-y[i-1])^2+(x[i]-x[i-1])^2)
end

function total_length(x::Array{T,1},y::Array{T,1}) where T
    s=0.0
    for i=2:length(x)
       s += distance_along(x,y,i)
    end
    s
end

#=
Given a whisker parameterized by points (x_1,y_1), (x_2,y_2), ... (x_n, y_n), 
This finds the first point (x_i,y_i) where the culmative path length along 
the whisker is greater than *thres*
It returns the index, i, of that point
=#
function get_ind_at_dist(x,y,thres)
    ind = length(x)
    s=0.0
    for i=2:length(x)
        s = WhiskerTracking.distance_along(x,y,i) + s
        if s > thres
            ind = i
            break
        end
    end
    ind
end

#=
Given a whisker parameterized by points (x_1,y_1), (x_2,y_2), ... (x_n, y_n), 
This finds the first point (x_i,y_i) where the culmative path length along 
the whisker is greater than *thres*

It then interpolates to find the exaction position (x_out,y_out) along the position
that is equal to *thres* path length and returns (x_out,y_out)
=#

function get_ind_at_dist_exact(x,y,thres)
    ind = length(x)
    s1=0.0
    s0=0.0
    x_out = x[end]
    y_out = y[end]
    for i=2:length(x)
        s1 = WhiskerTracking.distance_along(x,y,i) + s0
        if s1 > thres
            x_out = x[i-1] + (thres - s0) * (x[i] - x[i-1]) / (s1 - s0)
            y_out = y[i-1] + (thres - s0) * (y[i] - y[i-1]) / (s1 - s0)
            break
        end
        s0 = s1
    end
    (x_out,y_out)
end
