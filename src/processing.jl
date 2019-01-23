
function mean_image_uint8(han)
    round.(UInt8,squeeze(mean(han.vid,3),3))
end

function mean_image(han)
    squeeze(mean(han.vid,3),3)
end

function subtract_background(han)

    mydiff = han.vid[:,:,han.frame] .- mean_image(han)
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

    han.mask=reinterpret(UInt8,load(string(han.data_path,mask_file)))[1,:,:].==0

    nothing
end

function adjust_contrast(han)

    myimg = han.vid[:,:,han.frame]

    myimg[myimg.>han.contrast_max]=255
    myimg[myimg.<han.contrast_min]=0

    han.current_frame = myimg

    nothing
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
    for i=1:length(han.whiskers)
        w1=[han.whiskers[i].x[(end-9):end] han.whiskers[i].y[(end-9):end]]
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

    han.woi[han.frame] = deepcopy(han.whiskers[han.woi_id])

    x=smooth(han.woi[han.frame].x)
    y=smooth(han.woi[han.frame].y)

    calc_woi_angle(han,x,y)
    calc_woi_curv(han,x,y)

    nothing
end
