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

function read_whisker_hdf5(path,w_inds=[1,4,7,10,13])

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

function read_pole_and_whisker_hdf5(path)

    woi=read_whisker_hdf5(path)
    p=read_pole_hdf5(path,16)

    (woi,p)
end

function get_woi_x_y(w,w_id,follicle=(400.0f0,50.0f0))

    #We need to center the follicle on 0,0 for good fitting
    cent_x=w[w_id].x[end]
    cent_y=w[w_id].y[end]

    #Determine the best axis for whisker fitting by calculating a vector from follicle to tip
    v_x=w[w_id].x[1]-w[w_id].x[end]
    v_y=w[w_id].y[1]-w[w_id].y[end]

    skip=false

    if allequal_1(sign.(diff(w[w_id].y))) #Check if y dimension is monotonically increasing or decreasing

        #3rd order polynomial fit

        if length(w[w_id].y)>3
            mypoly=polyfit(w[w_id].y-cent_y,w[w_id].x-cent_x,3)
        elseif length(w[w_id].y)>2
            mypoly=polyfit(w[w_id].y-cent_y,w[w_id].x-cent_x,2)
        else
            skip=true
        end

        if skip
            yy=w[w_id].y
            xx=w[w_id].x
        else
            if w[w_id].y[1]<w[w_id].y[end]
                yy = collect(w[w_id].y[1]:w[w_id].y[end])
            else
                yy = collect(w[w_id].y[end]:w[w_id].y[1])
            end
            xx=mypoly(yy-cent_y)+cent_x
        end

    else

        #3rd order polynomial fit
        if length(w[w_id].x)>3
            mypoly=polyfit(w[w_id].x-cent_x,w[w_id].y-cent_y,3)
        elseif length(w[w_id].x)>2
            mypoly=polyfit(w[w_id].x-cent_x,w[w_id].y-cent_y,2)
        else
            skip=true
        end

        if skip
            yy=w[w_id].y
            xx=w[w_id].x
        else
            if w[w_id].x[1]<w[w_id].x[end]
                xx = collect(w[w_id].x[1]:w[w_id].x[end])
            else
                xx = collect(w[w_id].x[end]:w[w_id].x[1])
            end
            yy=mypoly(xx-cent_x)+cent_y
        end
    end

    #Flip to make sure the right side is near the follicle

    dist_1=sqrt((xx[1]-follicle[1])^2+(yy[1]-follicle[2])^2)
    dist_2=sqrt((xx[end]-follicle[1])^2+(yy[end]-follicle[2])^2)

    if dist_1 < dist_2
        reverse!(xx)
        reverse!(yy)
    end

    (xx,yy)
end

allequal_1(x) = all(y->y==x[1],x)
