
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

    han.mask=reinterpret(UInt8,load(string(han.data_path,"mask.tif")))[1,:,:].==0

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
