
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
        s = WhiskerTracking.distance_along(x,y,i) + s
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
function get_angle(x::Array{T,1},y::Array{T,1},start_dist=0.0,angle_dist=30.0) where T

    s=0.0
    myangle = 0.0
    j = 1
    for i=2:length(x)
        s = distance_along(x,y,i) + s

        if s > start_dist
            j = i - 1
            break
        end
    end

    s = 0.0
    for i=2:length(x)
        s = distance_along(x,y,i) + s

        if s>angle_dist
            myangle = atan(y[i]-y[j],x[i]-x[j])
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

function bootstrap_ip_curv(w_x,w_y,ip_min,ip_max,min_length,n)

    aa = get_angle(w_x,w_y,30.0)

    if ip_max > total_length(w_x,w_y)
        ip_max = total_length(w_x,w_y)
    end

    w_x_p = (w_x .- w_x[1]) .* cos(aa) .+ (w_y .- w_y[1]) .* sin(aa) .+ w_x[1]
    w_y_p = (w_x .- w_x[1]) .* -1 .* sin(aa) .+ (w_y .- w_y[1]) .* cos(aa) .+ w_y[1]

    out=zeros(Float64,n)

    for i=1:n

        (ip1,ip2) = generate_ip(ip_min,ip_max,min_length)

        (x_1,y_1) = make_whisker_segment(w_x_p,w_y_p,ip_1,ip_2)

        out[i] = least_squares_quad(x_1,y_1)
    end
    out
end

function segment_curvature_with_angle(w_x::Array{T,1},w_y::Array{T,1},ip1::Real,ip2::Real,aa=get_angle(w_x,w_y)) where T
    (ix_p,iy_p) = make_whisker_segment(w_x,w_y,ip1,ip2)
    curvature_with_angle(ix_p,iy_p,aa)
end

function curvature_with_angle(w_x::Array{T,1},w_y::Array{T,1},aa::Real) where T
    w_x_p = (w_x .- w_x[1]) .* cos(aa) .+ (w_y .- w_y[1]) .* sin(aa) .+ w_x[1]
    w_y_p = (w_x .- w_x[1]) .* -1 .* sin(aa) .+ (w_y .- w_y[1]) .* cos(aa) .+ w_y[1]

    least_squares_quad(w_x_p,w_y_p)
end

function generate_ip(ip_min,ip_max,min_length)
    ip1 = rand(ip_min:(ip_max-min_length))
    ip2 = rand((ip1+min_length):ip_max)
    (ip1,ip2)
end

#=
New curvature 3/12/2022
=#

function rotate_by_angle(w_x,w_y,aa,wx0=w_x[1],wy0=w_y[1])
    w_x_p = (w_x .- wx0) .* cos(aa) .+ (w_y .- wy0) .* sin(aa) .+ wx0
    w_y_p = (w_x .- wx0) .* -1 .* sin(aa) .+ (w_y .- wy0) .* cos(aa) .+ wy0

    (w_x_p,w_y_p)
end

function parabola_fit(x::AbstractArray{T,1},y::AbstractArray{T,1}) where T

    x_mat = zeros(Float64,size(x,1),3)
    for i=1:size(x,1)
        x_mat[i,1] = x[i] * x[i]
        x_mat[i,2] = x[i]
        x_mat[i,3] = 1.0
    end
    coeffs = x_mat \ y

    error = sum((coeffs[1] .* x.^2 .+ coeffs[2] .* x .+ coeffs[3] .- y).^2) ./ length(x)

    (coeffs, error)
end

function curvature(x,a,b)
   kappa = 2 * a / (1 + (2*a*x + b)^2)^(3/2)
end

function best_fit_parabola(x::AbstractArray{T,1},y::AbstractArray{T,1},ind1,ind2) where T

    (mycoeffs,myerror) = parabola_fit(x[ind1:ind2],y[ind1:ind2])

    min_error = myerror
    min_coeffs = deepcopy(mycoeffs)
    out_angle = 0.0

    for i=0.0:pi/24:pi

        (x1,y1) = rotate_by_angle(x,y,i)

        (mycoeffs,myerror) = parabola_fit(x1[ind1:ind2],y1[ind1:ind2])

        if myerror < min_error
            min_error = myerror
            out_angle = i
            min_coeffs = deepcopy(mycoeffs)
        end
    end
    (min_coeffs,out_angle)
end

#Gives parabolic fit in original coordinate system using parabola fit from coordinate system rotated at arbitrary angle rot_angle
function get_parabola_fit(x::AbstractArray{T,1},y::AbstractArray{T,1},coeffs,rot_angle) where T
    (x1,y1) = rotate_by_angle(x,y,rot_angle)
    y2 = coeffs[1].* x1.^2 .+ coeffs[2] .* x1 .+ coeffs[3]
    (x2,y2) = rotate_by_angle(x1,y2,-rot_angle,x[1],y[1])
end

# This will convert a whisker from being described with x,y positions to be described by the angles between head to tail segments of the whisker
#spaced apart by magnitudes given in d_vec_abs
function convert_to_angular_coordinates(x,y,d_vec_abs)

    x_p2 = 0.0
    y_p2 = 0.0
    x_p1 = 0.0
    y_p1 = 0.0
    
    w_dx2 = 0.0
    w_dx1 = 0.0
    w_dy2 = 0.0
    w_dy1 = 0.0

    w_theta = zeros(Float64,length(d_vec_abs))
    
    for j=1:length(d_vec_abs)
    
        ind = WhiskerTracking.get_ind_at_dist(x,y,d_vec_abs[j])
        x_p2 = x[ind]
        y_p2 = y[ind]
        
        if j==1
            w_dx2 = x_p2 - x[1]
            w_dy2 = y_p2 - y[1]
            w_theta[j] = atan(w_dy2,w_dx2)
        else
            w_dx2 = x_p2 - x_p1
            w_dy2 = y_p2 - y_p1
            
            a_mag = sqrt(w_dx2^2 + w_dy2^2)
            b_mag = sqrt(w_dx1^2 + w_dy1^2)
            w_theta[j] = acos(dot([w_dx2;w_dy2],[w_dx1;w_dy1]) / (a_mag * b_mag))
        end
        x_p1 = x_p2; y_p1 = y_p2;
        w_dx1 = w_dx2; w_dy1 = w_dy2;
    end
    w_theta
end
