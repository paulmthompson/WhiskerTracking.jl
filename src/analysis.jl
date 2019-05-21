
#=
Finds the phase over time for a given angle vs time array
using the Hilbert Transform

Kleinfeld and Deschenes 2011
=#
function get_phase(aa)
    responsetype = Bandpass(8.0,30.0; fs=500.0)
    designmethod=Butterworth(4)
    df1=digitalfilter(responsetype,designmethod)
    myfilter=DF2TFilter(df1)
    filter_aa=filt(myfilter,aa) #filtfilt?

    hh=hilbert(filter_aa)

    angle.(hh)
end

#Polynomial smoothing with the Savitsky Golay filters
#
# Sources
# ---------
# Theory: http://www.ece.rutgers.edu/~orfanidi/intro2sp/orfanidis-i2sp.pdf
# Python Example: http://wiki.scipy.org/Cookbook/SavitzkyGolay
# Modified from https://github.com/BBN-Q/Qlab.jl/blob/master/src/SavitskyGolay.jl
function savitsky_golay(x::Vector, windowSize::Integer, polyOrder::Integer; deriv::Integer=0)

#Some error checking
    @assert isodd(windowSize) "Window size must be an odd integer."
    @assert polyOrder < windowSize "Polynomial order must me less than window size."

    halfWindow = round(Int64,(windowSize-1)/2)

    #Setup the S matrix of basis vectors.
    S = zeros(windowSize, polyOrder+1)
    for ct = 0:polyOrder
        S[:,ct+1] = collect(-halfWindow:halfWindow).^(ct)
    end

    #Compute the filter coefficients for all orders
    #From the scipy code it seems pinv(S) and taking rows should be enough
    G = S*pinv(S'*S)

    #Slice out the derivative order we want
    filterCoeffs = G[:,deriv+1] * factorial(deriv);


    #Pad the signal with the endpoints and convolve with filter
    paddedX = [x[1]*ones(halfWindow); x; x[end]*ones(halfWindow)]
    y = conv(filterCoeffs[end:-1:1], paddedX)

    #Return the valid midsection
    return y[2*halfWindow+1:end-2*halfWindow]

end

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

#
function get_p_distances(wx,wy,p::Array{T,2}) where T
    pd=1000.0.*ones(Float64,length(wx))

    for i=1:length(wx)
        pd[i]=WhiskerTracking.calc_p_dist(wx[i],wy[i],p[i,1],p[i,2])[1]
    end

    pd
end

function calc_force(x,y,theta_f,curv,ii,i_p,curv_0=0.0)
    #x, y - whisker coordinates
    #theta_f - whisker angle
    #curv - whisker curvature
    #ii - index of contact
    #i_p - index of high SNR point - we should use the second DLC point for this (as long as it isn't past pole)

    E = 1.0 #Elastic Modulus of Whisker
    I_p = 1.0 #Moment of inertia of whisker at point p
    #curv_0 intrinsic curvature of the whisker
    delta_kappa = curv - curv_0 #Change in curvature

    theta_f = theta_f / 180 * pi

    #x_f, y_f follicle x and y
    x_f = x[end]
    y_f = y[end]

    #x_c, y_c contact x and y
    x_c = x[ii]
    y_c = y[ii]

    #x_p, y_p point_p x and y
    x_p = x[i_p]
    y_p = y[i_p]

    theta_contact = contact_angle(x,y,ii)#Angle that the whisker is pointing at point of contact

    theta_0 = atan2((y_c - y_f),(x_c - x_f)) #
    r_0 = sqrt((x_c - x_f)^2 + (y_c - y_f)^2)

    theta_p = atan2((y_c - y_p),(x_c - x_p))
    r_p = sqrt((x_c - x_p)^2 + (y_c - y_p)^2)

    #Contact force
    F = delta_kappa * E * I_p / (r_p * cos(theta_p - theta_contact))

    M_0 = r_0 * F * cos(theta_0 - theta_contact)

    F_ax = F * sin(theta_f - theta_contact)
    F_lat = F * cos(theta_f - theta_contact)

    (M_0,F_ax,F_lat)
end

function contact_angle(x,y,ii)
    #x whisker coordinates
    #y whisker coordinates
    #ii index of whisker contact

    atan2((y[ii]-y[ii+1]),(x[ii]-x[ii+1]))
end

function get_curv_and_angle(woi,follicle=(400.0f0,50.0f0))
    curv=zeros(Float64,length(woi))
    aa=zeros(Float64,length(woi))
    tracked=falses(length(woi))


    #Get angle and curvature from Janelia
    for i=1:length(woi)

        if length(woi[i].x)>3
            mymeas=JT_measure(woi[i],follicle[1],follicle[2])
            curv[i]=unsafe_wrap(Array,mymeas.data,8)[4]
            aa[i]=unsafe_wrap(Array,mymeas.data,8)[3]

            if isnan(curv[i])|isnan(aa[i])
            else
                tracked[i]=true
            end
        end

    end


    #Interpolate missing data points
    A_x = find(tracked)
    knots = (A_x,)

    itp_a = interpolate(knots, aa[tracked], Gridded(Linear()))
    itp_c = interpolate(knots, curv[tracked], Gridded(Linear()))

    for i=1:length(woi)

        if !tracked[i]
            curv[i]=itp_c(i)
            aa[i]=itp_a(i)
        end

    end

    for i=1:length(woi)
        if isnan(curv[i])
            curv[i]=itp_c(i)
        end
        if isnan(aa[i])
            aa[i]=itp_a(i)
        end

    end

    (curv,aa,tracked)
end
