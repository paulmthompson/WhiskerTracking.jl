
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

function upload_mask(han,mask_file)

    han.wt.mask=reinterpret(UInt8,load(string(han.wt.data_path,mask_file)))[1,:,:].==0

    nothing
end

function generate_mask(han,min_val,max_val,frame_id)

    myimg = han.wt.vid[:,:,frame_id]

    myimg[myimg.>max_val]=255
    myimg[myimg.<min_val]=0

    han.wt.mask=myimg.==0

    nothing
end

function adjust_contrast_gui(han)

    han.current_frame=adjust_contrast(han.wt,han.frame)

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

function load_video(vid_name,frame_range = (false,(0,0,0),(0,0,0)))

    if !frame_range[1]

        xx=open(`$(ffmpeg_path) -i $(vid_name) -f image2pipe -vcodec rawvideo -pix_fmt gray -`);

        vid=zeros(UInt8,0)

        temp=zeros(UInt8,640,480)
        yy=read(`mediainfo --Output="Video;%FrameCount%" $(vid_name)`)
        vid_length=parse(Int64,convert(String,yy[1:(end-1)]))

        vid=zeros(480,640,vid_length)
        for i=1:vid_length
            read!(xx[1],temp)
            vid[:,:,i]=temp'
        end
        start_frame = 1
        #Specific range to track
    else
        start_time=string(frame_range[2][1],":",frame_range[2][2],":",frame_range[2][3])
        xx=open(`$(ffmpeg_path) -ss $(start_time) -i $(vid_name) -f image2pipe -vcodec rawvideo -pix_fmt gray -`);

        tt1=Base.Dates.Time(frame_range[2]...)
        tt2=Base.Dates.Time(frame_range[3]...)
        vid_length = frames_between(tt1,tt2,25)

        vid=zeros(UInt8,0)
        temp=zeros(UInt8,640,480)

        for i=1:vid_length
            read!(xx[1],temp)
            append!(vid,temp'[:])
        end
        close(xx[1])

        start_frame = total_frames(tt1,25)
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
                y_ind=540
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
