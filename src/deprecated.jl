#=
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
=#
function image_preprocessing(vid,i)

    temp_img = zeros(Float64,size(vid,1),size(vid,2))
    temp_img2=zeros(Float64,size(vid,1),size(vid,2))

    #Adjust contrast

    for j=1:size(vid,1)
        for k=1:size(vid,2)
            temp_img[j,k] = convert(Float64,vid[j,k,i])
        end
    end

    local_contrast_enhance!(temp_img,temp_img)

    #anisotropic diffusion to smooth while perserving edges
    anisodiff!(temp_img, 20,20.0,0.05,1,temp_img2)

    for j=1:size(vid,1)
        for k=1:size(vid,2)
            vid[j,k,i] = round(UInt8,temp_img[j,k])
        end
    end

    nothing
end

function mean_image_uint8(han::Tracker_Handles)
    #round.(UInt8,squeeze(mean(han.wt.vid,3),3)) #These should use the normalized from teh whole video
end

function mean_image(han::Tracker_Handles)
    #squeeze(mean(han.wt.vid,3),3) #These should use the normalized from the whole video
end
