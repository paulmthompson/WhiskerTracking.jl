
#=
Takes an array of Janelia whiskers and finds the angle and curvature using
their method
woi is array of whiskers
tracked specifies if a frame should be included or not
=#
function get_curv_and_angle(woi,tracked=trues(length(woi)),follicle=(400.0f0,50.0f0);face_axis='x')
    curv=zeros(Float64,length(woi))
    aa=zeros(Float64,length(woi))

    #Get angle and curvature from Janelia
    f1=round(Int32,follicle[1])
    f2=round(Int32,follicle[2])
    for i=1:length(woi)

        if (length(woi[i].x)>3)&(tracked[i])
            mymeas=JT_measure(woi[i],f1,f2,face_axis)
            curv[i]=unsafe_wrap(Array,mymeas.data,8)[4]
            aa[i]=unsafe_wrap(Array,mymeas.data,8)[3]

            if isnan(curv[i])|isnan(aa[i])
                tracked[i]=false
            end
        end
    end

    #Interpolate missing data points
    A_x = find(tracked)
    knots = (A_x,)

    itp_a = interpolate(knots, aa[tracked], Gridded(Linear()))
    itp_c = interpolate(knots, curv[tracked], Gridded(Linear()))

    for i=1:length(woi)

        if (!tracked[i])&((i>A_x[1])&(A_x[end]>i))
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

    (curv,aa)
end

#=
count along whisker to end
=#

function culm_dist(x::Array{T,1},y::Array{T,1},thres::Real,follicle_end=true) where T
    tot=0.0
    outind=1

    if follicle_end
        inds = (length(x)-1):-1:1
    else
        inds = 1:(length(x)-1)
    end
    
    for i in inds

        tot += sqrt((x[i]-x[i+1])^2+(y[i]-y[i+1])^2)

        if tot>thres
            outind=i
            break
        end
    end
    outind
end

#=
Get curvature of just particular segment of whisker (almost certainly a faster
not janelia way to do this)
-xx is array of x positions for each whisker
-yy is array of y positions for each whisker
-woi is the janelia array of whiskers
-tracked specifies of the whisker should be included or not.
  this variable will be modified to false if the curvature of the high SNR segment cannot be determined
=#
function get_ip_curv_array(xx,yy,woi,tracked,p1,p2)

    c_ip=zeros(Float64,length(xx))
    for i=1:length(xx)
        if tracked[i]
            c_ip[i]=get_ip_curv(xx[i],yy[i],woi[i],p1,p2)
            if isnan(c_ip[i])
                tracked[i]=false
                c_ip[i]=0.0
            end
        end
    end
    c_ip
end

function get_ip_curv(xx,yy,woi,p1,p2)

    ip_1=WhiskerTracking.culm_dist(xx,yy,p1)
    ip_2=WhiskerTracking.culm_dist(xx,yy,p2)

    new_wx=xx[ip_2:ip_1]
    new_wy=yy[ip_2:ip_1]

    new_mywhiskers=deepcopy(woi)
    new_mywhiskers.len=length(new_wx)
    new_mywhiskers.x=convert(Array{Float32,1},new_wx)
    new_mywhiskers.y=convert(Array{Float32,1},new_wy)
    new_mywhiskers.thick=ones(Float32,length(new_wx))
    new_mywhiskers.scores=ones(Float32,length(new_wx))

    mymeas=WhiskerTracking.JT_measure(new_mywhiskers,400.0f0,50.0f0)
    unsafe_wrap(Array,mymeas.data,8)[4]

end
