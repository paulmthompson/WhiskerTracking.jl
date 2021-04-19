
#=
Force calculations according to Pammer OConner 2013
where force magnitude is estimated based on the degree of bending
in the same section of whisker in every frame selected to be high
SNR (Point P)

=#

function calc_force(x::Array{Float64,1},y::Array{Float64,1},theta_f::Float64,curv::Float64,ii::Int,i_p::Int,curv_0=0.0; I_p = 1.0, E=1.0)
    #x, y - whisker coordinates
    #theta_f - whisker angle (radians)
    #curv - whisker curvature
    #ii - index of contact
    #i_p - index of high SNR point - we should use the second DLC point for this (as long as it isn't past pole)
    # E - Elastic Modulus of Whisker
    # I_p - Moment of inertia of whisker at point p I_p = 1.0

    #curv_0 intrinsic curvature of the whisker
    delta_kappa = curv - curv_0 #Change in curvature

    #x_f, y_f follicle x and y
    x_f = x[end]
    y_f = y[end]

    #x_c, y_c contact x and y
    x_c = x[ii]
    y_c = y[ii]

    #x_p, y_p point_p x and y
    x_p = x[i_p]
    y_p = y[i_p]

    c_i = get_contact_ind(x,y,ii,30.0,false)
    theta_contact = contact_angle(x[ii],x[c_i],y[ii],y[c_i])

    (theta_0,r_0) = calc_r_theta(x_f,x_c,y_f,y_c)
    (theta_p,r_p) = calc_r_theta(x_p,x_c,y_p,y_c)

    (F, M_0) = force_moment(delta_kappa,r_p,r_0,theta_p,theta_0,theta_contact,I_p = I_p, E = E)

    (F_ax, F_lat) = decompose_force(F,theta_f,theta_contact)

    (M_0,F_ax,F_lat,F,theta_contact)
end

#=
Calculate Force and Moment
delta_kappa - change in curvature from intrinsic
r_p - distance from point of contact to point p (pixels)
r_0 - distance from follicle to point of contact (pixels)
theta_p - angle from point_p to point of contact (radians)
theta_0 - angle from follicle to point of contact (radians)
theta_contact - angle that whisker is pointing at point of contact (radians)
=#
function force_moment(delta_kappa::Real,r_p::Real,r_0::Real,theta_p::Real,
    theta_0::Real,theta_contact::Real;I_p = 1.0, E=1.0)

    F = abs(delta_kappa * E * I_p / (r_p * cos(theta_p - theta_contact)))

    M_0 = r_0 * F * cos(theta_0 - theta_contact)

    (F, M_0)
end

#=
F - Total Contact Force
theta_f - whisker angle (radians)
theta_contact - angle of contact (radians)
=#
function decompose_force(F::Real,theta_f::Real,theta_contact::Real)
    F_ax = F * sin(theta_f - theta_contact)
    F_lat = F * cos(theta_f - theta_contact)
    (F_ax,F_lat)
end

function calc_r_theta(x1::Real,x2::Real,y1::Real,y2::Real)

    theta_p = atan((y2 - y1),(x2 - x1))
    r_p = sqrt((x2 - x1)^2 + (y2 - y1)^2)
    (theta_p,r_p)
end


function contact_angle(x1::Real,x2::Real,y1::Real,y2::Real)
    atan(y2-y1,x2-x1)
end

function get_contact_ind(x::Array{T,1},y::Array{T,1},ii,s_thres = 10.0,forward_dir=true) where T
    s = 0.0

    x_0 = x[ii]
    y_0 = y[ii]

    i = ii
    while(s < s_thres)

        s = sqrt((x[i] - x_0)^2 + (y[i] - y_0)^2)

        if forward_dir
            i = i + 1
        else
            i = i - 1
        end
    end
    i
end


#=
Decompose force into x and y components
f_t - contact force
t_c - angle of contact (radians)
px, py - pole x and y coordinates
wx, wy - x and y coordinate of closest whisker point
=#
function contact_force_x_y(f_t::Real,t_c::Real,px::Real,py::Real,wx::Real,wy::Real)

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

    a_x=cos(aa)
    a_y=sin(aa)

    theta_ax=aa

    #I am only using force magnitudes, so find the direction where the axial force component is
    #positive.
    if dot([n_x; n_y],[a_x; a_y]) < 0
        theta_ax = aa + pi
        a_x = cos(theta_ax)
        a_y = sin(theta_ax)
    end

    #Project the force vector onto the axial component and subtract from the force vector to get the lateral component
    n_a_x = dot([n_x; n_y],[cos(theta_ax); sin(theta_ax)]) .* [a_x; a_y]

    theta_lat=atan(n_y-n_a_x[2],n_x-n_a_x[1])

    (theta_lat, theta_ax)
end

function get_force_signs(xx,yy,tracked,p,F_t,t_c,aa,c)
    F_lat_sign=zeros(Int64,length(xx))
    F_ax_sign=zeros(Int64,length(xx))
    for i=1:length(xx)

        if (tracked[i])&(c[i])

            (new_x, new_y) = interpolate_whisker(xx[i],yy[i])
            ii=calc_p_dist(new_x,new_y,p[i,1],p[i,2])[2]

            #Find normal angle, which determines if

            (F_t_x,F_t_y,theta_n) = contact_force_x_y(F_t[i],t_c[i],
                p[i,1],p[i,2],new_x[ii],new_y[ii])

            (t_lat,t_ax) = get_ax_lat_angles(aa[i],theta_n)

            if abs(t_ax - aa[i]) < (10 / 180 * pi)
                F_ax_sign[i] = -1
            else
                F_ax_sign[i] = 1
            end

            if (t_lat < aa[i]) & (t_lat > aa[i]-pi)
                F_lat_sign[i] = 1
            else
                F_lat_sign[i] = -1
            end
        end
    end
    (F_lat_sign,F_ax_sign)
end

#=

=#
function calculate_all_forces(xx,yy,p,c,aa,curv,tracked=trues(length(c)); i_p_loc=50.0,E_in=1.0,moment_of_inertia_p=1.0)

    F_ax=zeros(Float64,length(c))
    F_lat=zeros(Float64,length(c))
    M=zeros(Float64,length(c))
    F_t=zeros(Float64,length(c))
    theta_c = zeros(Float64,length(c))
    F_calc=falses(length(c))

    for i=1:length(c)
        if ((c[i])&(length(xx[i])>1))&(tracked[i])

            (new_x, new_y) = interpolate_whisker(xx[i],yy[i])

            #ii - index of contact
            ii=calc_p_dist(new_x,new_y,p[i,1],p[i,2])[2]

            #i_p - index of high SNR point
            i_p=culm_dist(new_x,new_y,i_p_loc)

            if (i_p>ii) #Don't want our high SNR point past the point of contact
                try
                    (M[i],F_ax[i],F_lat[i],F_t[i],theta_c[i])=calc_force(new_x,new_y,aa[i],curv[i],ii,i_p,E=E_in,I_p=moment_of_inertia_p)
                    F_calc[i]=true
                catch
                end
            end
        end
    end

    (F_ax,F_lat,M,F_t,theta_c,F_calc)
end
