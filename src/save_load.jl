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

function read_whisker_hdf5(path; w_inds=[1,4,7,10,13],l_thres=0.5)

    #deeplabcut stores points as pandas dataframe
    #Assuming a whisker is labeled as a discrete set of points
    file=h5open(path)
    mytable=read(file,"df_with_missing")["table"];

    t1=1
    t2=length(mytable)

    #Each datapoint in an image of the pandas array is represented by values in 3 columns:
    #x,y and liklihood.
    #w_inds specifices the first index of each data point of interest


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
            if mydata[w_inds[j]+2]>l_thres

                xx[j,i]=this_x
                yy[j,i]=this_y

                ll[j,i]=true
            end
        end
    end

    close(file)

    #outlier removal
    #smooth with gaussian kernel
    #calculate residual distance threshold and set Threshold
    x_smooth=zeros(Float64,size(xx))
    y_smooth=zeros(Float64,size(yy))

    for i=1:size(xx,1)
        x_smooth[i,:]=smooth(xx[i,:],15)
        y_smooth[i,:]=smooth(yy[i,:],15)
    end

    dist_thres=50.0

    for i=1:size(xx,2)
        for j=1:length(w_inds)
            mydist=sqrt((xx[j,i]-x_smooth[j,i])^2+(yy[j,i]-y_smooth[j,i])^2)

            if mydist>dist_thres
                ll[j,i]=false
            end

        end
    end

    woi=[WhiskerTracking.Whisker1() for i=1:size(xx,2)]

    #Assuming is stored such that first data point centered on the follicle,
    #But Janelia assumes that the last point in the array is on the follicle, so we flip here
    #To take on the Janelia convention
    #Should probably be a flag for this
    for i=1:size(xx,2)
        inds=find(ll[:,i].==true)
        num_points=length(inds)

        w=WhiskerTracking.Whisker1(0,i,num_points,reverse(xx[inds,i]),reverse(yy[inds,i]),ones(Float64,num_points),ones(Float64,num_points))
        woi[i]=w
    end

    woi
end

function read_pole_hdf5(path,col_pos=1)

    file=h5open(path)
    mytable=read(file,"df_with_missing")["table"];

    p=zeros(Float64,length(mytable),2)

    for i=1:length(mytable)
        mydata=mytable[i].data[2]

        if mydata[col_pos+2]>0.1
            p[i,1]=mydata[col_pos]
            p[i,2]=mydata[col_pos+1]
        else
           p[i,1]=NaN
           p[i,2]=NaN
        end
    end

    close(file)

    p
end

function read_pole_and_whisker_hdf5(path,l_thres_in=0.5)

    woi=read_whisker_hdf5(path,l_thres=l_thres_in)
    p=read_pole_hdf5(path,16)

    (woi,p)
end
