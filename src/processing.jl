
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

    myimg[myimg.>max_val]=255
    myimg[myimg.<min_val]=0

    wt.mask=myimg.==0

    nothing
end

function adjust_contrast_gui(han)

    han.current_frame=adjust_contrast(han.wt,han.frame)

    nothing
end

function apply_roi(whiskers,pad_pos)

    remove_whiskers=Array{Int64}(0)

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

    myimg[myimg.>wt.contrast_max]=255
    myimg[myimg.<wt.contrast_min]=0

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

function get_follicle(han)
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

#I should interpolate or something here to compare similiar sections of each whisker
function whisker_similarity(han,prev)
    w2=[han.woi[han.frame-prev].x[(end-9):end] han.woi[han.frame-prev].y[(end-9):end]]
    mincor=10000.0
    w_id = 0;
    for i=1:length(han.wt.whiskers)
        w1=[han.wt.whiskers[i].x[(end-9):end] han.wt.whiskers[i].y[(end-9):end]]
        mycor=euclidean(w1,w2)
        if mycor < mincor
            mincor=mycor
            w_id = i
        end
    end
    (mincor,w_id)
end

whisker_similarity(han) = whisker_similarity(han,1)

function smooth(x::Vector, window_len::Int=7, window::Symbol=:lanczos)
    w = getfield(DSP.Windows, window)(window_len)
    return DSP.filtfilt(w ./ sum(w), [1.0], x)
end

function calc_woi_angle(han,x,y)

    this_angle=atan2(y[end-5] - y[end], x[end-5] - x[end])
    han.woi_angle[han.frame]=rad2deg(this_angle)
    nothing
end

function calc_woi_curv(han,x,y)
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

function assign_woi(han)

    han.woi[han.frame] = deepcopy(han.wt.whiskers[han.woi_id])

    x=smooth(han.woi[han.frame].x)
    y=smooth(han.woi[han.frame].y)

    calc_woi_angle(han,x,y)
    calc_woi_curv(han,x,y)

    nothing
end

#=

=#
function load_video(vid_name,frame_range = (false,0.0,0))

    if !frame_range[1]

        xx=open(`$(ffmpeg_path) -i $(vid_name) -f image2pipe -vcodec rawvideo -pix_fmt gray -`);

        temp=zeros(UInt8,640,480)
        yy=read(`mediainfo --Output="Video;%FrameCount%" $(vid_name)`)
        vid_length=parse(Int64,convert(String,yy[1:(end-1)]))

        vid=zeros(UInt8,480,640,vid_length)
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
        vid=zeros(UInt8,480,640,vid_length)

        temp=zeros(UInt8,640,480)

        for i=1:vid_length
            read!(xx[1],temp)
            vid[:,:,i]=temp'
        end
        close(xx[1])

        start_frame = frame_range[2] * 25
        vid = reshape(vid,480,640,vid_length)
    end

    vid = convert(SharedArray{UInt8,3},vid)

    (vid,start_frame)
end

function WT_length_constraint(whiskers,min_length)

    remove_whiskers=Array{Int64}(0)

    #length constraint
    for i=1:length(whiskers)
        if whiskers[i].len<min_length
            push!(remove_whiskers,i)
        end
    end

    deleteat!(whiskers,remove_whiskers)

    nothing
end

function apply_mask(whiskers,mask,min_length)

    remove_whiskers=Array{Int64}(0)

    for i=1:length(whiskers)
        save_points=trues(length(whiskers[i].x))
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
                save_points[j]=false
            end
        end

        whiskers[i].x=whiskers[i].x[save_points]
        whiskers[i].y=whiskers[i].y[save_points]
        whiskers[i].thick=whiskers[i].thick[save_points]
        whiskers[i].scores=whiskers[i].scores[save_points]
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

function WT_reorder_whisker(whiskers,pad_pos)

    #order whiskers so that the last index is closest to the whisker pad
    for i=1:length(whiskers)
        front_dist = (whiskers[i].x[1]-pad_pos[1])^2+(whiskers[i].y[1]-pad_pos[2])^2
        end_dist = (whiskers[i].x[end]-pad_pos[1])^2+(whiskers[i].y[end]-pad_pos[2])^2

        if front_dist < end_dist #
            reverse!(whiskers[i].x,1)
            reverse!(whiskers[i].y,1)
            reverse!(whiskers[i].scores,1)
            reveres!(whiskers[i].thick,1)
        end
    end

    nothing
end

function make_tracking(path,name; frame_range = (false,0.0,0))

    vid_name = string(path,name)
    whisk_path = string(path,name,".whiskers")
    meas_path = string(path,name,".measurements")

    (vid,start_frame)=load_video(vid_name,frame_range)
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

    pmap(t->image_preprocessing(wt.vid,t),1:size(wt.vid,3))
    #pmap(t->image_preprocessing(wt.vid,t),1:10)
    println("Preprocessing complete")

    wt.all_whiskers=pmap(t->WT_trace(t,wt.vid[:,:,t]',wt.min_length,wt.pad_pos,wt.mask),1:size(wt.vid,3))
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

    keep=Array{Int64,1}(0)

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

function eliminate_redundant(whiskers,keep_thres=20.0)

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
function reorder_whiskers(wt)

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

function offline_tracking_multiple()




end
