
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
