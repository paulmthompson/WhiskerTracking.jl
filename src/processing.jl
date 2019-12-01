
export make_tracking, offline_tracking

function upload_mask(wt,mask_file)

    #Load mask
    myimg = reinterpret(UInt8,load(string(wt.data_path,mask_file)))

    if size(myimg,3) == 1
        wt.mask = myimg.==0
    else
        wt.mask=myimg[1,:,:].==0
    end

    nothing
end

function generate_mask(wt,min_val,max_val,frame_id)

    myimg = wt.vid[:,:,frame_id]

    if VERSION > v"0.7-"
        myimg[myimg.>max_val] .= 255
        myimg[myimg.<min_val] .= 0
    else
        myimg[myimg.>max_val] = 255
        myimg[myimg.<min_val] = 0
    end
    wt.mask=myimg.==0

    #Find connected Regions
    comp=label_components(wt.mask)

    if maximum(comp)>1
        total_counts=zeros(Int64,maximum(comp))
        for i=1:length(total_counts)
            total_counts[i]=length(find(comp.==i))
        end

        max_comp=indmax(total_counts)

        for i=1:length(wt.mask)
            if comp[i] != max_comp
                wt.mask[i] = false
            end
        end
    end

    nothing
end

function adjust_contrast_gui(han::Tracker_Handles)

    han.current_frame=adjust_contrast(han.wt,han.frame)

    nothing
end

#=
Only Whiskers are identified that are inside a region of interest (ROI)
That ROI is a circle centered on the whisker pad of radius 100
=#

function apply_roi(whiskers::Array{Whisker1,1},pad_pos::Tuple{Float32,Float32})

    remove_whiskers=Array{Int64,1}()

    for i=1:length(whiskers)

        if sqrt((pad_pos[1]-whiskers[i].x[end])^2+(pad_pos[2]-whiskers[i].y[end])^2)>100.0
            push!(remove_whiskers,i)
        end
    end

    deleteat!(whiskers,remove_whiskers)

    nothing
end

function adjust_contrast(wt,iFrame)

    myimg = wt.vid[:,:,iFrame]

    if VERSION > v"0.7-"
        myimg[myimg.>wt.contrast_max] .= 255
        myimg[myimg.<wt.contrast_min] .= 0
    else
        myimg[myimg.>wt.contrast_max]=255
        myimg[myimg.<wt.contrast_min]=0
    end

    myimg
end

function total_frames(tt,fps)
    h=Base.Dates.hour(tt)
    m=Base.Dates.minute(tt)
    s=Base.Dates.second(tt)
    (h*3600+m*60+s)*fps + 1
end

function frames_between(tt1,tt2,fps)
    total_frames(tt2,fps)-total_frames(tt1,fps)
end

function get_follicle(han::Tracker_Handles)
    x=0.0
    y=0.0
    count=0

    for i=1:length(han.tracked)
        if han.tracked[i]
            x+=han.woi[i].x[end]
            y+=han.woi[i].y[end]
            count+=1
        end
    end
    x=x/count
    y=y/count
    (x,y)
end

#Need to optimize this significantly
#Really we want this to be such that the length of each line is equal.
#Probably can do this by interpolating along each segment or something
#I also need to reverse these
function whisker_similarity(han::Tracker_Handles,prev)

    cor_length=20

    w2_x=han.woi[han.frame-prev].x
    w2_y=han.woi[han.frame-prev].y
    mincor=10000.0.*ones(length(han.wt.whiskers))
    w_id = 0;
    for i=1:length(han.wt.whiskers)
        w1_x=han.wt.whiskers[i].x
        w1_y=han.wt.whiskers[i].y

        for j=1:(size(w1_x,1)-cor_length)
            for k=1:(size(w2_x,1)-cor_length)
                mycor=w_dist(w1_x,w2_x,w1_y,w2_y,j,k,cor_length)
                if mycor < mincor[i]
                    mincor[i]=mycor
                end
            end
        end
    end
    findmin(mincor)
end

function w_dist(x1,x2,y1,y2,i1,i2,cor_length)

    mysum=0.0
    for jj=1:cor_length
        mysum += sqrt((x2[i2+jj] - x1[i1+jj]) ^ 2 + (y2[i2+jj] - y1[i1+jj]) ^2)
    end
    mysum
end

whisker_similarity(han) = whisker_similarity(han,1)

function smooth(x, window_len=7)
    w = getfield(DSP.Windows, :lanczos)(window_len)
    DSP.filtfilt(w ./ sum(w), [1.0], x)
end

function calc_woi_angle(han::Tracker_Handles,x,y)

    this_angle=atan(y[end-5] - y[end], x[end-5] - x[end])
    han.woi_angle[han.frame]=rad2deg(this_angle)
    nothing
end

function calc_woi_curv(han::Tracker_Handles,x,y)
    han.woi_curv[han.frame]=get_curv(x,y)
    nothing
end

function get_curv(xdata,ydata)

    a=[xdata ydata]
    m=size(a,1)
    A = [2a -ones(m)]
    b=[]
    for i=1:m
        b=[b; norm(a[i,:])^2]
    end
    y=inv(A'*A)*A'*b
    x=y[1:end-1]
    R=y[end]
    r=sqrt(norm(x)^2-R)

    v1x=xdata[1]-xdata[end]
    v1y=ydata[1]-ydata[end]

    v2x=x[1]-xdata[end]
    v2y=x[2]-ydata[end]

    mydot = v1x * -v2y + v1y * v2x

    mycurv=1/r

    if mydot > 0
        mycurv *= -1
    end

    mycurv
end

function assign_woi(han::Tracker_Handles)

    han.woi[han.frame] = deepcopy(han.wt.whiskers[han.woi_id])

    if han.discrete_auto_calc
        make_discrete(han.wt.w_p,han.frame,han.woi[han.frame],han.d_spacing)
    end

    #=
    These don't work for some reason
    =#
    #x=smooth(han.woi[han.frame].x)
    #y=smooth(han.woi[han.frame].y)
    x=han.woi[han.frame].x
    y=han.woi[han.frame].y

    calc_woi_angle(han,x,y)
    calc_woi_curv(han,x,y)

    nothing
end

#=
Put the Loading steps in try/catch blocks in case there is some error calculating frames

Is there a way with ffmpeg to determine the number of frames?
=#
function load_video(vid_name::String,frame_range = (false,0.0,0))

    if !frame_range[1]

        yy=read(`$(ffprobe_path) -v error -select_streams v:0 -show_entries stream=nb_frames -of default=nokey=1:noprint_wrappers=1 $(vid_name)`)

        if is_windows()
            vid_length=parse(Int64,String(yy[1:(end-2)]))
        else
            vid_length=parse(Int64,String(yy[1:(end-1)]))
        end

        xx=open(`$(ffmpeg_path) -i $(vid_name) -f image2pipe -vcodec rawvideo -pix_fmt gray -`);

        temp=zeros(UInt8,640,480)


        vid=SharedArray{UInt8}(480,640,vid_length)
        for i=1:vid_length
            read!(xx[1],temp)
            vid[:,:,i]=temp'
        end
        start_frame = 1
        #Specific range to track
    else
        start_time=frame_range[2]
        xx=open(`$(ffmpeg_path) -ss $(start_time) -i $(vid_name) -f image2pipe -vcodec rawvideo -pix_fmt gray -`);

        vid_length = frame_range[3]
        vid=SharedArray{UInt8}(480,640,vid_length)

        temp=zeros(UInt8,640,480)

        for i=1:vid_length
            read!(xx[1],temp)
            vid[:,:,i]=temp'
        end
        close(xx[1])

        start_frame = frame_range[2] * 25
        vid = reshape(vid,480,640,vid_length)
    end

    println("Video loaded.")

    (vid,start_frame,vid_length)
end

function WT_length_constraint(whiskers::Array{Whisker1,1},min_length::Int)

    remove_whiskers=Array{Int64,1}()

    #length constraint
    for i=1:length(whiskers)
        if whiskers[i].len<min_length
            push!(remove_whiskers,i)
        end
    end

    deleteat!(whiskers,remove_whiskers)

    nothing
end

function apply_mask(whiskers::Array{Whisker1,1},mask::BitArray{2},min_length::Int64)

    remove_whiskers=Array{Int64,1}()

    for i=1:length(whiskers)
        delete_points=Array{Int64,1}()

        #Start at the tip and work our way back to the follicle.
        #If the mask hits something, we should probably delete all points following
        for j=1:length(whiskers[i].x)
            x_ind = round(Int64,whiskers[i].y[j])
            y_ind = round(Int64,whiskers[i].x[j])

            if x_ind<1
                x_ind=1
            elseif x_ind>size(mask,1)
                x_ind=size(mask,1)
            end

            if y_ind<1
                y_ind=1
            elseif y_ind>size(mask,2)
                y_ind=size(mask,2)
            end

            if mask[x_ind,y_ind]
                for k=j:length(whiskers[i].x)
                    push!(delete_points,k)
                end
                break
            end
        end

        deleteat!(whiskers[i].x,delete_points)
        deleteat!(whiskers[i].y,delete_points)
        deleteat!(whiskers[i].thick,delete_points)
        deleteat!(whiskers[i].scores,delete_points)
        whiskers[i].len = length(whiskers[i].x)

        #Sometimes whiskers are detected in mask of reasonable length, so they are completely deleted
        #In this step and will mess up later processing, so we should delete them after a length check
        if whiskers[i].len < min_length
            push!(remove_whiskers,i)
        end

    end

    deleteat!(whiskers,remove_whiskers)

    nothing
end

function WT_reorder_whisker(whiskers::Array{Whisker1,1},pad_pos::Tuple{Float32,Float32})

    #order whiskers so that the last index is closest to the whisker pad
    for i=1:length(whiskers)
        front_dist = (whiskers[i].x[1]-pad_pos[1])^2+(whiskers[i].y[1]-pad_pos[2])^2
        end_dist = (whiskers[i].x[end]-pad_pos[1])^2+(whiskers[i].y[end]-pad_pos[2])^2

        if front_dist < end_dist #
            reverse!(whiskers[i].x,1)
            reverse!(whiskers[i].y,1)
            reverse!(whiskers[i].scores,1)
            reverse!(whiskers[i].thick,1)
        end
    end

    nothing
end

function load_image_stack(path)

    myfiles=readdir(path)
    frame_list=Array{Int64,1}()

    count=0

    for i=1:length(myfiles)

        if (myfiles[i][1:3])=="img" #this should be a variable
            count+=1
        end
    end

    vid=SharedArray{UInt8}(480,640,count)
    count=1
    for i=1:length(myfiles)

        if (myfiles[i][1:3])=="img"
            if VERSION > v"0.7-"
                vid[:,:,count]=reinterpret(UInt8,load(string(path,myfiles[i])))[1:3:end,:]
            else
                vid[:,:,count]=reinterpret(UInt8,load(string(path,myfiles[i])))[1,:,:]
            end
            count+=1
            push!(frame_list,parse(Int64,myfiles[i][4:(end-4)]))
        end
    end

    (vid,1,count-1,frame_list)
end

function make_tracking(path,name; frame_range = (false,0.0,0),image_stack=false)

    vid_name = string(path,name)
    whisk_path = string(path,name,".whiskers")
    meas_path = string(path,name,".measurements")

    if !image_stack
        (vid,start_frame)=load_video(vid_name,frame_range)
    else
        (vid, start_frame)=load_image_stack(string(path,name))
    end
    vid_length=size(vid,3)

    all_whiskers=[Array{Whisker1}(0) for i=1:vid_length]

    tracker_name=vid_name[1:(end-4)]

    wt=Tracker(vid,path,name,vid_name,whisk_path,meas_path,path,tracker_name,50,falses(480,640),Array{Whisker1}(0),
    (0.0,0.0),255,0,all_whiskers)
end

function offline_tracking(wt,max_whiskers=10)

    for i=1:size(wt.vid,3)
        image_preprocessing(wt.vid,i)
    end

    for i=1:size(wt.vid,3)
        #Need to transpose becuase row major in C vs column major in julia
        wt.all_whiskers[i]=WT_trace(i,wt.vid[:,:,i]',wt.min_length,wt.pad_pos,wt.mask)
        println(string(i,"/",size(wt.vid,3)))
    end

    reorder_whiskers(wt)

    nothing
end

function offline_tracking_parallel(wt,max_whiskers=10)

    pmap(t->image_preprocessing(wt.vid,t),1:size(wt.vid,3),batch_size=ceil(Int,size(wt.vid,3)/nworkers()))
    #pmap(t->image_preprocessing(wt.vid,t),1:10)
    println("Preprocessing complete")

    wt.all_whiskers=pmap(t->WT_trace(t,wt.vid[:,:,t]',wt.min_length,wt.pad_pos,wt.mask),1:size(wt.vid,3),
    batch_size=ceil(Int,size(wt.vid,3)/nworkers()))
    #wt.all_whiskers=pmap(t->WT_trace(t,wt.vid[:,:,t]',wt.min_length,wt.pad_pos,wt.mask),1:10)

    reorder_whiskers(wt)

    nothing
end

function remove_bad_whiskers(wt,i,imax_whiskers)

    if i>1
        whisker_prev_frame(wt,i)
    else
        wt.whiskers=wt.whiskers[1:max_whiskers]
    end

    nothing
end

function whisker_prev_frame(wt,iFrame,keep_thres=20.0)

    keep=Array{Int64,1}()

    for i=1:length(wt.whiskers)
        w2=[wt.whiskers[i].x[(end-9):end] wt.whiskers[i].y[(end-9):end]]
        mincor=10000.0
        w_id = 0;
        for j=1:length(wt.all_whiskers[iFrame-1])
            w1=[wt.all_whiskers[iFrame-1][j].x[(end-9):end] wt.all_whiskers[iFrame-1][j].y[(end-9):end]]

            mycor=euclidean(w1,w2)
            if mycor < mincor
                mincor=mycor
                w_id = i
            end
        end
        if mincor<keep_thres
            push!(keep,i)
        end
    end

    wt.whiskers=wt.whiskers[keep]

    nothing
end

function eliminate_redundant(whiskers::Array{Whisker1,1},keep_thres=20.0)

    i=1

    while i<length(whiskers)
        w2=[whiskers[i].x[(end-19):end] whiskers[i].y[(end-19):end]]

        mincor=10000.0
        w_id = 0;
        for j=1:length(whiskers)

            if j != i
                w1=[whiskers[j].x[(end-19):end] whiskers[j].y[(end-19):end]]

                mycor=euclidean(w1,w2)
                if mycor < mincor
                    mincor=mycor
                    w_id = i
                end
            end
            if mincor<keep_thres
                w1_score=mean(whiskers[j].scores)
                w2_score=mean(whiskers[i].scores)

                if w1_score > w2_score
                    deleteat!(whiskers,i)
                else
                    deleteat!(whiskers,j)
                end

                i=1
                break
            end
        end
        i+=1
    end

    nothing
end

#Order anterior to posterior
function reorder_whiskers(wt::Tracker)

    for i=1:length(wt.all_whiskers)

        xpos=[wt.all_whiskers[i][j].x[end] for j=1:length(wt.all_whiskers[i])]
        wt.all_whiskers[i]=wt.all_whiskers[i][sortperm(xpos)]

    end

    nothing
end

function extend_whisker(whisker,mask)

    extend=true

    v_y=whisker.y[end] - whisker.y[end-1]
    v_x=whisker.x[end] - whisker.x[end-1]

    new_x=[whisker.x[end]; whisker.x[end]+v_x]
    new_y=[whisker.y[end]; whisker.y[end]+v_y]

    while (extend)
        x_ind = round(Int64,new_y[end])
        y_ind = round(Int64,new_x[end])

        if x_ind<1
            x_ind=1
        elseif x_ind>size(mask,1)
            x_ind=size(mask,1)
        end

        if y_ind<1
            y_ind=1
        elseif y_ind>size(mask,2)
            y_ind=size(mask,2)
        end

        if mask[x_ind,y_ind]
            break
            extend=false
        elseif (x_ind<5)|(y_ind<5)|(x_ind>size(mask,1)-5)|(y_ind>size(mask,2)-5)
            break
            extend=false
        else
            v_y=new_y[end] - new_y[end-1]
            v_x=new_x[end] - new_x[end-1]

            push!(new_x,new_x[end]+v_x)
            push!(new_y,new_y[end]+v_y)
        end
    end

    if length(new_y)>2

        append!(whisker.x,new_x[3:end])
        append!(whisker.y,new_y[3:end])
        whisker.len += (length(new_y)-2)
        append!(whisker.scores,0.0)
        append!(whisker.thick,0.0)

    end

    nothing
end

function find_intersecting(whiskers)

    myoverlap=Array{Tuple{Int64,Int64},1}(0)
    overlap_i=Array{Tuple{Int64,Int64},1}(0)

    for i=1:length(whiskers)

        w1_x=whiskers[i].x
        w1_y=whiskers[i].y
        for j=(i+1):length(whiskers)

                w2_x=whiskers[j].x
                w2_y=whiskers[j].y

                for ii=2:length(w1_x), jj = 2:length(w2_x)
                    if WhiskerTracking.intersect(w1_x[ii-1],w1_x[ii],w2_x[jj-1],w2_x[jj],
                            w1_y[ii-1],w1_y[ii],w2_y[jj-1],w2_y[jj])
                            push!(myoverlap,(i,j))
                            push!(overlap_i,(ii,jj))
                            break
                    end
                end

        end

    end
    (myoverlap,overlap_i)
end

function offline_tracking_multiple()




end
