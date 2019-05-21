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

function read_whisker_hdf5(path)

    #deeplabcut stores points as pandas dataframe
    #Assuming a whisker is labeled as a discrete set of points
    file=h5open(path)
    mytable=read(file,"df_with_missing")["table"];

    t1=1
    t2=length(mytable)

    #Each datapoint in an image of the pandas array is represented by values in 3 columns:
    #x,y and liklihood.
    #w_inds specifices the first index of each data point of interest
    w_inds=[1,4,7,10,13]

    xx=zeros(Float64,length(w_inds),length(mytable))
    yy=zeros(Float64,length(w_inds),length(mytable))
    ll=falses(length(w_inds),length(mytable))

    v_x=zeros(Float64,5)
    v_y=zeros(Float64,5)
    l=zeros(Float64,5)

    w_x=zeros(Float64,5)
    w_y=zeros(Float64,5)

    for i=t1:t2
        mydata=mytable[i].data[2]

        for j=1:length(w_inds)

            this_x=mydata[w_inds[j]]
            this_y=mydata[w_inds[j]+1]

            #We can set a liklihood threshold
            if mydata[w_inds[j]+2]>0.1

                xx[j,i]=this_x
                yy[j,i]=this_y

                ll[j,i]=true
            end
        end
    end

    close(file)

    #smoothing

    dist_thres=50.0

    for i=2:size(xx,2)-1

        for j=1:length(w_inds)

            if (ll[j,i])&(ll[j,i-1])
                mydist=sqrt((xx[j,i]-xx[j,i-1])^2+(yy[j,i]-yy[j,i-1])^2)

                if mydist>dist_thres
                    ll[j,i]=false
                end
            end
        end
    end

    woi=[WhiskerTracking.Whisker1() for i=1:size(xx,2)]

    for i=1:size(xx,2)
        inds=find(ll[:,i].==true)
        num_points=length(inds)

        w=WhiskerTracking.Whisker1(0,i,num_points,reverse(xx[inds,i]),reverse(yy[inds,i]),ones(Float64,num_points),ones(Float64,num_points))
        woi[i]=w
    end

    woi
end

function read_pole_hdf5(path)

    file=h5open(path)
    mytable=read(file,"df_with_missing")["table"];

    p=zeros(Float64,length(mytable),2)

    for i=1:length(mytable)
        mydata=mytable[i].data[2]

        if mydata[3]>0.1
            p[i,1]=mydata[1]
            p[i,2]=mydata[2]
        else
           p[i,1]=NaN
           p[i,2]=NaN
        end
    end

    close(file)

    p
end
