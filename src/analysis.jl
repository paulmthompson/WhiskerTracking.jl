
#=
Finds the phase over time for a given angle vs time array
using the Hilbert Transform

Kleinfeld and Deschenes 2011
=#
function get_phase(aa)
    responsetype = Bandpass(8.0,30.0; fs=500.0)
    designmethod=Butterworth(4)
    df1=digitalfilter(responsetype,designmethod)
    #myfilter=DF2TFilter(df1)
    filter_aa=filtfilt(df1,aa)

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

    #Contact force magnitude
    F = abs(delta_kappa * E * I_p / (r_p * cos(theta_p - theta_contact)))

    M_0 = r_0 * F * cos(theta_0 - theta_contact)

    F_ax = F * sin(theta_f - theta_contact)
    F_lat = F * cos(theta_f - theta_contact)

    (M_0,F_ax,F_lat,F,theta_contact)
end

function contact_angle(x,y,ii)
    #x whisker coordinates
    #y whisker coordinates
    #ii index of whisker contact

    atan2((y[ii]-y[ii+1]),(x[ii]-x[ii+1]))
end

#Decompose for into x and y components
function contact_force_x_y(f_t,t_c,px,py,wx,wy)

    #Force of contact is normal to the contact angle.
    t_c_x = cos(t_c - pi/2)
    t_c_y = sin(t_c - pi/2)

    mag_v = sqrt((wx-px)^2 + (wy-py)^2)

    vx = (wx - px) / mag_v
    vy = (wy - py) / mag_v

    t_n = t_c - pi/2

    if dot([t_c_x; t_c_y],[vx;vy])>0
    else
        t_n = t_n + pi
    end

    (f_t * cos(t_n), f_t * sin(t_n))
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

function calculate_all_forces(xx,yy,p,c,aa,curv,tracked=trues(length(c)))

    F_x=zeros(Float64,length(c))
    F_y=zeros(Float64,length(c))
    M=zeros(Float64,length(c))
    F_t=zeros(Float64,length(c))
    theta_c = zeros(Float64,length(c))
    F_calc=falses(length(c))

    for i=1:length(c)
        if ((c[i])&(length(xx[i])>1))&(tracked[i])

            #ii - index of contact
            ii=WhiskerTracking.calc_p_dist(xx[i],yy[i],p[i,1],p[i,2])[2]

            #i_p - index of high SNR point
            #We can use 50 units of length from whisker follicle
            #This is only accurate if the fit up to 50 units is accurate
            i_p=culm_dist(xx[i],yy[i],50.0)

            if (i_p>ii) #Don't want our high SNR point past the point of contact
                try
                    (M[i],F_x[i],F_y[i],F_t[i],theta_c[i])=WhiskerTracking.calc_force(xx[i],yy[i],-1.*aa[i],curv[i],ii,i_p)
                    F_calc[i]=true
                catch
                end
            end
        end
    end

    A_x = find(F_calc)
    knots = (A_x,)

    itp_fx = interpolate(knots, F_x[F_calc], Gridded(Linear()))
    itp_fy = interpolate(knots, F_y[F_calc], Gridded(Linear()))
    itp_m = interpolate(knots, M[F_calc], Gridded(Linear()))
    itp_ft = interpolate(knots, F_t[F_calc], Gridded(Linear()))
    itp_tc = interpolate(knots, theta_c[F_calc], Gridded(Linear()))

    for i=1:length(c)

        if (c[i])&(!F_calc[i])
            F_x[i]=itp_fx[i]
            F_y[i]=itp_fy[i]
            M[i]=itp_m[i]
            F_t[i]=itp_ft[i]
            theta_c[i]=itp_tc[i]
        end
    end


    (F_x,F_y,M,F_t,theta_c)
end

function culm_dist(x,y,thres)
    tot=0.0
    outind=1
    for i=(length(x)-1):-1:1

        tot += sqrt((x[i]-x[i+1])^2+(y[i]-y[i+1])^2)

        if tot>thres
            outind=i
            break
        end
    end
    outind
end

function outlier_removal_min(cov1,min_ex,ind_range=(1,length(cov1)))

    cov2=cov1[ind_range[1]:ind_range[2]]

    outlier_inds=cov2.<percentile(cov2,min_ex)

    itp_out = interpolate((find(.!outlier_inds),), cov2[.!outlier_inds], Gridded(Linear()))

    for i in find(outlier_inds)
        cov2[i] = itp_out[i]
    end

    cov1[ind_range[1]:ind_range[2]]=cov2
    nothing
end

function outlier_removal_max(cov1,max_ex,ind_range=(1,length(cov1)))

    cov2=cov1[ind_range[1]:ind_range[2]]

    outlier_inds=cov2.>percentile(cov2,max_ex)

    itp_out = interpolate((find(.!outlier_inds),), cov2[.!outlier_inds], Gridded(Linear()))

    for i in find(outlier_inds)
        cov2[i] = itp_out[i]
    end

    cov1[ind_range[1]:ind_range[2]]=cov2
    nothing
end
function outlier_removal_twosided(cov1,min_ex,max_ex,ind_range=(1,length(cov1)))

    cov2=cov1[ind_range[1]:ind_range[2]]

    outlier_inds1=cov2.<percentile(cov2,min_ex)
    outlier_inds2=cov2.>percentile(cov2,max_ex)

    outlier_inds = outlier_inds1 .| outlier_inds2

    itp_out = interpolate((find(.!outlier_inds),), cov2[.!outlier_inds], Gridded(Linear()))

    for i in find(outlier_inds)
        cov2[i] = itp_out[i]
    end

    cov1[ind_range[1]:ind_range[2]]=cov2
    nothing
end

#Finds the number of unique pole positions

function get_p_pos(p)

    pos_labels=zeros(Int64,size(p,1))

    num_labels=0
    pos_x=Array{Float64}(0)
    pos_y=Array{Float64}(0)

    new_thres=50.0

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
