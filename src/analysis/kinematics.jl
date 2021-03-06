
#=
Finds the phase over time for a given angle vs time array
using the Hilbert Transform

Kleinfeld and Deschenes 2011
=#
function get_phase(aa;bp_l=8.0,bp_h=30.0,sampling_rate=500.0)
    responsetype = Bandpass(bp_l,bp_h; fs=sampling_rate)
    designmethod=Butterworth(4)
    df1=digitalfilter(responsetype,designmethod)

    #Zero lag filtering to make sure there is no phase shift.
    filter_aa=filtfilt(df1,aa)

    hh=hilbert(filter_aa)

    angle.(hh)
end

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

function get_ind_at_dist(x,y,thres)
    ind = length(x)
    s=0.0
    for i=2:length(x)
        s=WhiskerTracking.distance_along(x,y,i) + s
        if s > thres
            ind = i
            break
        end
    end
    ind
end

#=
Angle Calculation
=#
function get_angle(x::Array{T,1},y::Array{T,1},angle_dist=30.0) where T

    s=0.0
    myangle = 0.0
    for i=2:length(x)
        s = distance_along(x,y,i) + s

        if s>angle_dist
            myangle = atan(y[i]-y[1],x[i]-x[1])
            break
        end
    end
    myangle
end

#=
Curvature
=#

function get_curvature(x::Array{T,1},y::Array{T,1},points = 2.0:2.0:(total_length(x,y)-1)) where T

    s_i = zeros(Float64,length(x))
    for i=2:length(x)
       s_i[i]=distance_along(x,y,i) + s_i[i-1]
    end

    itp_x = interpolate((s_i,), x, Gridded(Linear()));
    itp_y = interpolate((s_i,), y, Gridded(Linear()));

    curv = zeros(Float64,length(points))

    for i=1:length(curv)

        x_0 = itp_x(points[i]-1)
        y_0 = itp_y(points[i]-1)

        x_1 = itp_x(points[i])
        y_1 = itp_y(points[i])

        x_2 = itp_x(points[i]+1)
        y_2 = itp_y(points[i]+1)

        num = abs(c_diff(x_2,x_0) * c_diff_2(y_0,y_1,y_2) - (c_diff(y_2,y_0)*c_diff_2(x_0,x_1,x_2)))

        denom = ((c_diff(x_2,x_0))^2 + (c_diff(y_2,y_0))^2) ^(3/2)

        curv[i]=num / denom
    end
    curv
end

function make_whisker_segment(x::Array{T,1},y::Array{T,1},ip1::Real,ip2::Real) where T

    (new_x, new_y) = WhiskerTracking.interpolate_whisker(x,y)

    ip_1 = WhiskerTracking.get_ind_at_dist(new_x,new_y,ip1)
    ip_2 = WhiskerTracking.get_ind_at_dist(new_x,new_y,ip2)

    x_part = new_x[ip_1:ip_2]
    y_part = new_y[ip_1:ip_2]

    (x_part,y_part)
end

function least_squares_quad(x::AbstractArray{T,1},y::AbstractArray{T,1}) where T

    x_mat = zeros(Float64,size(x,1),3)
    for i=1:size(x,1)
        x_mat[i,1] = x[i] * x[i]
        x_mat[i,2] = x[i]
        x_mat[i,3] = 1.0
    end
    coeffs = x_mat \ y
    coeffs[1]
end

function least_squares_quad_rot(x::AbstractArray{T,1},y::AbstractArray{T,1}) where T
   (my_in, rot_mat) = rotate_cov_eigen(x,y)
   sign_out = sign(cross([rot_mat[:,1]; 0.0],[rot_mat[:,2]; 0.0])[3])
   least_squares_quad(my_in[:,1],my_in[:,2])
end

function rotate_cov_eigen(x::AbstractArray{T,1},y::AbstractArray{T,1}) where T

    my_in = [x y]
    cov_mat = cov(my_in)
    rot_mat = eigvecs(cov_mat)
    eig_val = eigvals(cov_mat)

    max_eig = findmax(eig_val)[2]
    min_eig = findmin(eig_val)[2]

    (my_in * rot_mat[:,[max_eig,min_eig]], rot_mat[:,[max_eig,min_eig]])
end

function c_diff(x::Array{T,1},i::Int64) where T
   c_diff(x[i+1],x[i-1])
end

function c_diff(x_2::Float64,x_0::Float64)
   (x_2 - x_0)/2
end

function c_diff_2(x::Array{T, 1},i::Int64) where T
   c_diff_2(x[i-1],x[i],x[i+1])
end

function c_diff_2(x_0::Float64,x_1::Float64,x_2::Float64)
   x_0 - 2*x_1 + x_2
end

function remove_nan_whiskers(xx::Array,yy::Array)

    for i=1:length(xx)
        nan_inds = findall(isnan.(xx[i]).|isnan.(yy[i]))

        deleteat!(xx[i],nan_inds)
        deleteat!(yy[i],nan_inds)
    end
    nothing
end
