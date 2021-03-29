
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
