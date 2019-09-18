
#=
DLC import Methods
=#

#=
Read data table and return julia arrays for x position, y position, and liklihood for each whisker point
=#
function dlc_hd5_to_array(path,l_thres,pole=true)

    #deeplabcut stores points as pandas dataframe
    #Assuming a whisker is labeled as a discrete set of points
    file=h5open(path)
    mytable=read(file,"df_with_missing")["table"];


    w_ind_length=length(mytable[1].data[2])
    if pole
        w_inds=collect(1:3:w_ind_length-3)
    else
        w_inds=collect(1:3:w_ind_length)
    end

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

    (xx,yy,ll)
end

#=
Updates liklihood matrix to false if points jump past
distance threshold from smoothed temporal traces
=#
function dlc_smooth_liklihood(xx,yy,kernel_size,ll,dist_thres)

    #outlier removal
    #smooth with gaussian kernel
    #calculate residual distance threshold and set Threshold
    x_smooth=zeros(Float64,size(xx))
    y_smooth=zeros(Float64,size(yy))

    for i=1:size(xx,1)
        x_smooth[i,:]=smooth(xx[i,:],kernel_size)
        y_smooth[i,:]=smooth(yy[i,:],kernel_size)
    end

    for i=1:size(xx,2)
        for j=1:size(xx,1)
            mydist=sqrt((xx[j,i]-x_smooth[j,i])^2+(yy[j,i]-y_smooth[j,i])^2)

            if mydist>dist_thres
                ll[j,i]=false
            end

        end
    end

    nothing
end

function convert_whisker_points_to_janelia(xx,yy,tracked)

    woi=[WhiskerTracking.Whisker1() for i=1:length(xx)]

    #Assuming is stored such that first data point centered on the follicle,
    #But Janelia assumes that the last point in the array is on the follicle, so we flip here
    #To take on the Janelia convention
    #Should probably be a flag for this
    for i=1:length(xx)
        num_points=length(xx[i])

        w=WhiskerTracking.Whisker1(0,i,num_points,xx[i],yy[i],ones(Float64,num_points),ones(Float64,num_points))
        woi[i]=w
    end

    woi
end

function read_whisker_hdf5(path;l_thres=0.5,pole=true)

    (xx,yy,ll)=dlc_hd5_to_array(path,l_thres,pole)

    dlc_smooth_liklihood(xx,yy,15,ll,50.0)

    convert_whisker_points_to_janelia(xx,yy,ll)
end

function read_pole_hdf5(path)

    file=h5open(path)
    mytable=read(file,"df_with_missing")["table"];

    #Assumple pole is at the end of the array
    col_pos=length(mytable[1].data[2]) - 2

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

function save_single_image(han,img,num)

    my_wd=pwd()
    cd(han.paths.images)
    #Deeplabcut needs left padded zeros
    max_dig=length(digits(han.max_frames))
    img_name = string("img",lpad(num,max_dig,"0"),".png")

    #I think deeplabcut expects 24-bit png
    #You create 24 bit png files with ImageMagick as follows
    Images.save(string("png24:",img_name), img)

    cd(my_wd)

    nothing
end

function load_whisker_into_gui(han,whiskers::Array{Float64,2})

    han.tracked_whiskers = whiskers

    nothing
end
