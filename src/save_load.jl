

function load_dlc(path,f_start,f_end)
    dlc_csv=read_csv(path)
    myout=Array(dlc_csv);

    inds_to_track=f_start:f_end

    xx=[Array{Float64,1}(0) for i=1:length(inds_to_track)]
    yy=[Array{Float64,1}(0) for i=1:length(inds_to_track)]

    for i=1:length(inds_to_track)

        for j=[0,3,6,9,12]
            ll=myout[inds_to_track[i]+2,4+j]
            if typeof(ll)==String
                ll=parse(Float64,myout[inds_to_track[i]+2,4+j])
            end
            if ll>0.6
                myx=myout[inds_to_track[i]+2,2+j]
                if typeof(myx)==String
                    myx=parse(Float64,myx)
                end
                push!(xx[i],myx)

                myy=myout[inds_to_track[i]+2,3+j]
                if typeof(myy)==String
                    myy=parse(Float64,myy)
                end
                push!(yy[i],myy)
            end
        end
    end

    woi=[WhiskerTracking.Whisker1() for i=1:length(xx)]

    for i=1:length(xx)
        w=Whisker1(0,f_start+i-1,length(xx[i]),xx[i],yy[i],ones(Float64,length(xx[i])),ones(Float64,length(xx[i])))
        woi[i]=w
    end

    woi
end
