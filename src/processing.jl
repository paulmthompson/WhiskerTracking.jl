
export make_tracking, offline_tracking

function mean_image_uint8(han)
    round.(UInt8,squeeze(mean(han.wt.vid,3),3))
end

function mean_image(han)
    squeeze(mean(han.wt.vid,3),3)
end

function subtract_background(han)

    mydiff = han.wt.vid[:,:,han.frame] .- mean_image(han)
    new_diff = (mydiff - minimum(mydiff))
    new_diff = new_diff ./ maximum(new_diff)

    han.current_frame = round.(UInt8,new_diff .* 255)

    nothing
end

function sharpen_image(han)

    imgl = imfilter(han.current_frame, Kernel.Laplacian());
    newimg=imgl-minimum(imgl)
    newimg = newimg / maximum(newimg)
    han.current_frame = 255-round.(UInt8,newimg .* 255)

    nothing
end

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

function apply_roi(wt)

    keep=trues(length(wt.whiskers))

    for i=1:length(wt.whiskers)

        if sqrt((wt.pad_pos[1]-wt.whiskers[i].x[end])^2+(wt.pad_pos[2]-wt.whiskers[i].y[end])^2)>100.0
            keep[i]=false
        end
    end

    wt.whiskers=wt.whiskers[keep]

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

    (vid,start_frame)
end

function WT_length_constraint(wt)

    pass = trues(length(wt.whiskers))

    #length constraint
    for i=1:length(wt.whiskers)
        if wt.whiskers[i].len<wt.min_length
            pass[i]=false
        end
    end

    wt.whiskers=wt.whiskers[pass]

    nothing
end


function apply_mask(wt)

    remove_whiskers=Array{Int64}(0)

    for i=1:length(wt.whiskers)
        save_points=trues(length(wt.whiskers[i].x))
        for j=1:length(wt.whiskers[i].x)
            x_ind = round(Int64,wt.whiskers[i].y[j])
            y_ind = round(Int64,wt.whiskers[i].x[j])

            if x_ind<1
                x_ind=1
            elseif x_ind>480
                x_ind=480
            end

            if y_ind<1
                y_ind=1
            elseif y_ind>640
                y_ind=640
            end

            if wt.mask[x_ind,y_ind]
                save_points[j]=false
            end
        end

        wt.whiskers[i].x=wt.whiskers[i].x[save_points]
        wt.whiskers[i].y=wt.whiskers[i].y[save_points]
        wt.whiskers[i].thick=wt.whiskers[i].thick[save_points]
        wt.whiskers[i].scores=wt.whiskers[i].scores[save_points]
        wt.whiskers[i].len = length(wt.whiskers[i].x)

        #Sometimes whiskers are detected in mask of reasonable length, so they are completely deleted
        #In this step and will mess up later processing, so we should delete them after a length check
        if wt.whiskers[i].len < wt.min_length
            push!(remove_whiskers,i)
        end

    end

    deleteat!(wt.whiskers,remove_whiskers)

    nothing
end

function WT_reorder_whisker(wt)

    #order whiskers so that the last index is closest to the whisker pad
    for i=1:length(wt.whiskers)
        front_dist = (wt.whiskers[i].x[1]-wt.pad_pos[1])^2+(wt.whiskers[i].y[1]-wt.pad_pos[2])^2
        end_dist = (wt.whiskers[i].x[end]-wt.pad_pos[1])^2+(wt.whiskers[i].y[end]-wt.pad_pos[2])^2

        if front_dist < end_dist #
            wt.whiskers[i].x = flipdim(wt.whiskers[i].x,1)
            wt.whiskers[i].y = flipdim(wt.whiskers[i].y,1)
            wt.whiskers[i].scores = flipdim(wt.whiskers[i].scores,1)
            wt.whiskers[i].thick = flipdim(wt.whiskers[i].thick,1)
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

    wt=Tracker(vid,path,name,vid_name,whisk_path,meas_path,50,falses(480,640),Array{Whisker1}(0),
    (0.0,0.0),255,0,all_whiskers)
end

function offline_tracking(wt,max_whiskers=10)

    #Calculate background


    for i=1:size(wt.vid,3)

        #Adjust contrast
        wt.vid[:,:,i]=adjust_contrast(wt,i)

        #Sharpen

        #Background subtraction

        #reset whiskers for active frame
        wt.whiskers=Array{Whisker1}(0)

        #Need to transpose becuase row major in C vs column major in julia
        WT_trace(wt,i,wt.vid[:,:,i]')

        #Whisker number
        if length(wt.whiskers)>max_whiskers
            remove_bad_whiskers(wt,i,max_whiskers)
        end

        wt.all_whiskers[i]=deepcopy(wt.whiskers)
        println(string(i,"/",size(wt.vid,3)))
    end

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

function eliminate_redundant(wt,keep_thres=20.0)

    i=1

    while i<length(wt.whiskers)
        w2=[wt.whiskers[i].x[(end-19):end] wt.whiskers[i].y[(end-19):end]]

        mincor=10000.0
        w_id = 0;
        for j=1:length(wt.whiskers)

            if j != i
                w1=[wt.whiskers[j].x[(end-19):end] wt.whiskers[j].y[(end-19):end]]

                mycor=euclidean(w1,w2)
                if mycor < mincor
                    mincor=mycor
                    w_id = i
                end
            end
            if mincor<keep_thres
                w1_score=mean(wt.whiskers[j].scores)
                w2_score=mean(wt.whiskers[i].scores)

                if w1_score > w2_score
                    deleteat!(wt.whiskers,i)
                else
                    deleteat!(wt.whiskers,j)
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

function offline_tracking_multiple()




end
