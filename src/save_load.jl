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


function create_label_image(img::Array,w1,rad=0,interp=false)

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
Tracked whiskers

=#

function create_tracked_dictionary(w_x,w_y,w_loss,frame_list)

    tracked=Dict{Int,Tuple{Array{Float64,1},Array{Float64,1},Float64}}()

    for i=1:length(w_x)
        tracked[frame_list[i]] = (w_x[i],w_y[i],w_loss[i])
    end
    tracked
end

function load_whisker(path)

    file=jldopen(path)

    if haskey(file,"w_x")
        (w_x,w_y,w_loss,frame_list) = load_whisker_arrays(file)
        tracked = create_tracked_dictionary(w_x,w_y,w_loss,frame_list)
    elseif haskey(file,"tracked")
        tracked = load_whisker_dict(file)
    end

    close(file)

    tracked
end

function load_whisker_arrays(file)

    w_x=read(file,"w_x")
    w_y=read(file,"w_y")
    frame_list = read(file,"frame_list")
    w_loss = read(file, "loss")

    (w_x,w_y,w_loss,frame_list)
end

function load_whisker_dict(file)

    tracked = file["tracked"]
end

function save_tracked_whisker(path,tracked_w::Tracked_Whisker)

    tracked=Dict{Int,Tuple{Array{Float64,1},Array{Float64,1},Float64}}()

    for i=1:length(tracked_w.whiskers_x)

        if length(tracked_w.whiskers_x[i]) > 0
            tracked[i] = (tracked_w.whiskers_x[i],tracked_w.whiskers_y[i],tracked_w.whiskers_l[i])
        end
    end

    save_tracked_whisker(path,tracked)
end

function save_tracked_whisker(path,tracked::Dict{Int,Tuple{Array{Float64,1},Array{Float64,1},Float64}})

    jldopen(path, "w") do file
        file["tracked"] = tracked
    end

    nothing
end

function load_mask(filepath)
    file = jldopen(filepath)
    mask = read(file,"mask")
    close(file)
    mask
end

#=
HDF5 whisker methods
Tracked whisker is saved in folder with whisker name
=#

function save_tracked_whisker_hdf5(path::String,whisker_name::String,tracked::Dict{Int,Tuple{Array{Float64,1},Array{Float64,1},Float64}})



    for key in keys(tracked)


    end

end

#=
Save and Load manual class
=#

function save_manual_class(man::Manual_Class,path)

    file = jldopen(path,"w")
    write(file,"Max_Frames",man.max_frames)
    write(file,"Contact_Block",man.contact_block)
    write(file,"No_Contact_Block",man.no_contact_block)
    write(file,"Contact",man.contact)

    write(file,"Pro_Re",man.pro_re)
    write(file,"Pro_Re_Block",man.pro_re_block)

    write(file, "Exclude",man.exclude)
    write(file, "Exclude_Block",man.exclude_block)

    close(file)
    nothing
end

function load_manual_class(man::Manual_Class,path)

    file = jldopen(path,"r")
    man.max_frames = read(file,"Max_Frames")

    man.contact_block = read(file,"Contact_Block")
    man.no_contact_block = read(file,"No_Contact_Block")
    man.contact = read(file,"Contact")

    man.pro_re = read(file,"Pro_Re")
    man.pro_re_block = read(file,"Pro_Re_Block")

    man.exclude = read(file, "Exclude")
    man.exclude_block = read(file, "Exclude_Block")

    close(file)
    nothing
end

