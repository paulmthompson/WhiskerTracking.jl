
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
function dlc_smooth_liklihood(xx::Array{Float64,2},yy::Array{Float64,2},kernel_size,ll,dist_thres)

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

function convert_discrete_to_janelia(preds::Array,conf_thres::Float64,pad_pos::Tuple)
    woi=[WhiskerTracking.Whisker1() for i=1:size(preds,3)]
    tracked=trues(size(preds,3))

    myinds=falses(size(preds,1))
    for i=1:size(preds,3)
        num_points=0
        myinds[:]=falses(size(preds,1))
        for j=1:size(preds,1)
            if preds[j,3,i]>conf_thres
                myinds[j]=true
                num_points+=1
            end
        end

        woi[i]=WhiskerTracking.Whisker1(0,i,num_points,preds[myinds,1,i],preds[myinds,2,i],ones(Float64,num_points),ones(Float64,num_points))

        if num_points<5
            tracked[i]=false
        end

        #Points need to have a nearest neighbor at least 20 pixels away, otherwise they are just assumed
        #to be stray noise.
        for j=2:length(woi[i].x)
            if sqrt((woi[i].x[j]-woi[i].x[j-1])^2+(woi[i].y[j]-woi[i].y[j-1])^2) > 20.0
                tracked[i]=false
                break
            end
        end

        if tracked[i]
            WhiskerTracking.WT_reorder_whisker(woi[i],pad_pos)
        end
    end

    (woi,tracked)
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

#=
Snapshot
=#
function save_single_image(han::Tracker_Handles,path=han.paths.images,use_contrast=false)
    save_single_image(han,han.current_frame,han.displayed_frame,path,use_contrast)
end

function save_single_image(han::Tracker_Handles,img::AbstractArray,num::Int,path=han.paths.images,use_contrast=false)

    img_name = name_img(han,"img",num)

    save_img_with_dir_change(han,img_name,img,path,use_contrast)

    nothing
end

function save_label_image(han::Tracker_Handles,path=han.paths.images,interp=false)

    img_name = name_img(han,"w",han.displayed_frame)

    img = create_label_image(han,0,interp)

    save_img_with_dir_change(han,img_name,img,path)

    nothing
end

function save_follicle_image(han::Tracker_Handles,path=han.paths.images)

    img_name = name_img(han,"w",han.displayed_frame)

    img = create_follicle_image(han)

    save_img_with_dir_change(han,img_name,img,path)

    nothing
end

function save_img_with_dir_change(han::Tracker_Handles,img_name::String,img::AbstractArray,path=han.paths.images,use_contrast=false)
    my_wd=pwd()
    cd(path)
    if use_contrast
        img2 = deepcopy(img)
        adjust_contrast(img2,han.contrast_min,han.contrast_max)
        Images.save(img_name,img2)
    else
        Images.save(img_name, img)
    end
    cd(my_wd)
end

function name_img(han::Tracker_Handles,name_prefix,num)

    #Deeplabcut needs left padded zeros
    max_dig=length(digits(han.max_frames))
    img_name = string(name_prefix,lpad(num,max_dig,"0"),".png")
end

function create_label_image(han::Tracker_Handles,rad=0,interp=false)

    img = zeros(UInt8,size(han.current_frame))

    w1=han.woi[han.displayed_frame]

    #Janelia whiskers are 0 in
    new_x = w1.x .+ 1
    new_y = w1.y .+ 1

    if interp
        (new_x, new_y) = interpolate_whisker(new_x,new_y,0.2)
    end

    for i=1:length(new_x)
        x=round(Int64,new_x[i])
        y=round(Int64,new_y[i])

        img[y,x] = 255 #Backbone

        for xx=-1*rad:rad
            for yy=-1*rad:rad
                if !(((y+yy)<1)|(y+yy>size(img,1))|((x+xx)<1)|(x+xx>size(img,2)))
                     img[y+yy,x+xx]=255
                end
            end
        end

    end
    img
end

#=
function create_follicle_image(han::Tracker_Handles,rad=5)

    img = zeros(UInt8,size(han.current_frame))

    x0 = han.woi[han.displayed_frame].x[1]]
    y0 = han.woi[han.displayed_frame].y[1]]

end
=#

function load_whisker_into_gui(han,whiskers::Array{Float64,2})

    han.tracked_whiskers = whiskers

    nothing
end
