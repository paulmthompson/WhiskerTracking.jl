
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