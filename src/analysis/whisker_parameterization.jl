
dist(x1,y1,x2,y2) = sqrt((y2 - y1) * (y2 - y1) + (x2 - x1) *  (x2 - x1))

function distance_along(x::Array{T,1},y::Array{T,1},i::Int64) where T
    dist(x[i-1],y[i-1],x[i],y[i])
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
that is equal to *thres* path length and returns (x_out,y_out), along with *ind* 
which is the first index of the whisker where the path length is greater than *thres*

The user may also supply the starting culmative distance s0, as well as the starting index, which
can be useful for things like masked whiskers
=#

function get_ind_at_dist_exact(x::Array{T,1},y::Array{T,1},thres; s0 = 0.0, start_ind = 2) where T
    ind = length(x)
    s1=0.0
    x_out = x[end]
    y_out = y[end]
    for i=start_ind:length(x)
        s1 = WhiskerTracking.distance_along(x,y,i) + s0
        if s1 > thres
            x_out = x[i-1] + (thres - s0) * (x[i] - x[i-1]) / (s1 - s0)
            y_out = y[i-1] + (thres - s0) * (y[i] - y[i-1]) / (s1 - s0)
            ind = i
            break
        end
        s0 = s1
    end
    (x_out,y_out,ind)
end


#=
Given a whisker parameterized by points (x_1,y_1), (x_2,y_2), ... (x_n, y_n), 
This finds the nearest interpolated point, (x_i,y_i) that is closest to 
the point not on the whisker (x_p,y_p)

https://math.stackexchange.com/questions/2193720/find-a-point-on-a-line-segment-which-is-the-closest-to-other-point-not-on-the-li
=#

function find_nearest_on_whisker(x::Array{T,1},y::Array{T,1},x_p,y_p) where T

    x_closest = x[1]
    y_closest = y[1]
    ind = 1

    closest_dist = dist(x[1],y[1],x_p,y_p)

    A_dist = closest_dist

    for i=2:length(x)

        Ax = x[i - 1]
        Ay = y[i - 1]
        Bx = x[i]
        By = y[i]
        B_dist = dist(Bx,By,x_p,y_p)

        vx = Bx - Ax 
        vy = By - Ay 

        ux = Ax - x_p 
        uy = Ay - y_p 

        t = -1 * (vx * ux + vy * uy) / (vx * vx + vy * vy)

        if (t > 0) & (t < 1)
            t_x = (1-t) * Ax + t * Bx
            t_y = (1-t) * Ay + t * By

            min_dist = dist(t_x,t_y,x_p,y_p)

            if (min_dist < closest_dist)
                closest_dist = min_dist 
                x_closest = t_x 
                y_closest = t_y
                ind = i
            end
        else
            if (B_dist < closest_dist) 
                closest_dist = B_dist 
                x_closest = Bx 
                y_closest = By
                ind = i
            end
        end

        A_dist = B_dist
    end

    (x_closest,y_closest,ind)
end

#=
on whisker described by w_x,w_y at index *out_ind*, move forward and backward by 
*angle_samples* to determine the angle at (w_x[out_ind],w_y[out_ind])
=#

function find_incident_angle(w_x,w_y,out_ind,angle_samples)

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

    (theta,xx,yy)
end