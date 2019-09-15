
#=
Force calculations according to Pammer OConner 2013
where force magnitude is estimated based on the degree of bending
in the same section of whisker in every frame selected to be high
SNR (Point P)

=#

function calc_force(x,y,theta_f,curv,ii,i_p,curv_0=0.0; I_p = 1.0, E=1.0)
    #x, y - whisker coordinates
    #theta_f - whisker angle
    #curv - whisker curvature
    #ii - index of contact
    #i_p - index of high SNR point - we should use the second DLC point for this (as long as it isn't past pole)
    # E - Elastic Modulus of Whisker
    # I_p - Moment of inertia of whisker at point p I_p = 1.0

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

#Decompose force into x and y components
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

    (f_t * cos(t_n), f_t * sin(t_n),t_n)
end

function get_ax_lat_angles(aa,t_n)

    n_x=cos(t_n)
    n_y=sin(t_n)

    a_x=cosd(aa)
    a_y=sind(aa)

    theta_ax=aa

    #I am only using force magnitudes, so find the direction where the axial force component is
    #positive.
    if dot([n_x; n_y],[a_x; a_y]) < 0
        theta_ax = aa + 180
        a_x = cosd(theta_ax)
        a_y = sind(theta_ax)
    end

    #Project the force vector onto the axial component and subtract from the force vector to get the lateral component
    n_a_x = dot([n_x; n_y],[cosd(theta_ax); sind(theta_ax)]) .* [a_x; a_y]

    theta_lat=atan2(n_y-n_a_x[2],n_x-n_a_x[1])

    (theta_lat/pi * 180, theta_ax)
end

function get_force_signs(xx,yy,tracked,p,F_t,t_c,aa,c)
    F_lat_sign=zeros(Int64,length(xx))
    F_ax_sign=zeros(Int64,length(xx))
    for i=1:length(xx)

        if (tracked[i])&(c[i])
            ii=calc_p_dist(xx[i],yy[i],p[i,1],p[i,2])[2]

            (F_t_x,F_t_y,theta_n) = contact_force_x_y(F_t[i],t_c[i],
                p[i,1],p[i,2],xx[i][ii],yy[i][ii])

            (t_lat,t_ax) = get_ax_lat_angles(aa[i],theta_n)

            if abs(t_ax - aa[i]) < 10
                F_ax_sign[i] = -1
            else
                F_ax_sign[i] = 1
            end

            if (t_lat < aa[i]) & (t_lat > aa[i]-180)
                F_lat_sign[i] = 1
            else
                F_lat_sign[i] = -1
            end
        end
    end
    (F_lat_sign,F_ax_sign)
end

function calculate_all_forces(xx,yy,p,c,aa,curv,tracked=trues(length(c)); i_p_loc=50.0,E_in=1.0,moment_of_inertia_p=1.0)

    F_ax=zeros(Float64,length(c))
    F_lat=zeros(Float64,length(c))
    M=zeros(Float64,length(c))
    F_t=zeros(Float64,length(c))
    theta_c = zeros(Float64,length(c))
    F_calc=falses(length(c))

    for i=1:length(c)
        if ((c[i])&(length(xx[i])>1))&(tracked[i])

            #ii - index of contact
            ii=calc_p_dist(xx[i],yy[i],p[i,1],p[i,2])[2]

            #i_p - index of high SNR point
            #We can use 50 units of length from whisker follicle
            #This is only accurate if the fit up to 50 units is accurate
            i_p=culm_dist(xx[i],yy[i],i_p_loc)

            if (i_p>ii) #Don't want our high SNR point past the point of contact
                try
                    (M[i],F_ax[i],F_lat[i],F_t[i],theta_c[i])=calc_force(xx[i],yy[i],aa[i],curv[i],ii,i_p,E=E_in,I_p=moment_of_inertia_p)
                    F_calc[i]=true
                catch
                end
            end
        end
    end

    A_x = find(F_calc)
    knots = (A_x,)

    itp_fx = interpolate(knots, F_ax[F_calc], Gridded(Linear()))
    itp_fy = interpolate(knots, F_lat[F_calc], Gridded(Linear()))
    itp_m = interpolate(knots, M[F_calc], Gridded(Linear()))
    itp_ft = interpolate(knots, F_t[F_calc], Gridded(Linear()))
    itp_tc = interpolate(knots, theta_c[F_calc], Gridded(Linear()))

    for i=1:length(c)

        if (c[i])&(!F_calc[i])
            F_ax[i]=itp_fx[i]
            F_lat[i]=itp_fy[i]
            M[i]=itp_m[i]
            F_t[i]=itp_ft[i]
            theta_c[i]=itp_tc[i]
        end
    end


    (F_ax,F_lat,M,F_t,theta_c)
end
