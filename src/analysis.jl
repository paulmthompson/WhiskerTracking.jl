

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

#=
Get curvature of just particular segment of whisker (almost certainly a faster
not janelia way to do this)
=#
function get_ip_curv_array(xx,yy,woi,tracked)

    c_ip=zeros(Float64,length(xx))
    for i=1:length(xx)
        if tracked[i]
            c_ip[i]=get_ip_curv(xx[i],yy[i],woi[i])
            if isnan(c_ip[i])
                tracked[i]=false
                c_ip[i]=0.0
            end
        end
    end
    c_ip
end

function get_ip_curv(xx,yy,woi)

    ip_1=WhiskerTracking.culm_dist(xx,yy,30.0)
    ip_2=WhiskerTracking.culm_dist(xx,yy,70.0)

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
