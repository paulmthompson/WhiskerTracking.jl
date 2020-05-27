
function pixel_mse(truth::KnetArray{Float32,4},pred::Union{KnetArray{Float32,4},AutoGrad.Result{KnetArray{Float32,4}}})
    loss = sum((pred .- truth).^2)
    loss / (size(pred,3) * size(pred,4))
end

function myfree(x::AutoGrad.Result)
    #myfree(x.value)
end

function myfree(x::KnetArray)
    Knet.freeKnetPtr(x.ptr)
end

gaussian_2d(x,y,x0,y0)=[1/sqrt.(2 .* pi) .* exp.(-1 .* ((xi .- x0).^2 + (yi .- y0).^2)) for xi in x, yi in y]

function create_padded_kernel(size_x,size_y,kl)
    kernel = gaussian_2d(collect(-kl:1:kl),collect(-kl:1:kl),0,0)
    kernel = kernel ./ maximum(kernel)
    kernel_pad = zeros(Float32,size_x,size_y)
    kernel_pad[(div(size_x,2)-kl):(div(size_x,2)+kl),(div(size_y,2)-kl):(div(size_y,2)+kl)] = kernel
    kernel_pad
end

function image_augmentation(im,ll)

    im_out = zeros(Float32,size(im,1),size(im,2),size(im,3),size(im,4)*8)
    l_out = zeros(Float32,size(ll,1),size(ll,2),size(ll,3),size(ll,4)*8)

    count=1

    for i=1:size(im,4)
        im_out[:,:,:,count] = im[:,:,:,i]
        l_out[:,:,:,count] = ll[:,:,:,i]
        count += 1
        #rotations
        for j in [pi/6, pi/2, pi, 3*pi/2, -pi/6]
            for k=1:size(im,3)
                im_out[:,:,k,count] = imrotate(im[:,:,k,i],j,Reflect())[1:size(im,1),1:size(im,2)]
            end
            for k=1:size(ll,3)
                l_out[:,:,k,count] = imrotate(ll[:,:,k,i],j,Reflect())[1:size(ll,1),1:size(ll,2)]
            end
            count += 1
        end

        #Flip x
        im_out[:,:,:,count] = reverse(im[:,:,:,i],dims=1)
        l_out[:,:,:,count] = reverse(ll[:,:,:,i],dims=1)
        count+=1

        #Flip Y
        im_out[:,:,:,count] = reverse(im[:,:,:,i],dims=2)
        l_out[:,:,:,count] = reverse(ll[:,:,:,i],dims=2)
        count+=1

        # 0.75 Scale (zoom in)

        #1.25 Scale (Reflect around places where image is empty)
    end

    #Shuffle Positions
    myinds=Random.shuffle(collect(1:size(im_out,4)));
    im_out=im_out[:,:,:,myinds]
    l_out=l_out[:,:,:,myinds]

    (im_out,l_out)
end

function augment_images(im,ll)

    total_augmentations = 6

    im_out = zeros(Float32,size(im,1),size(im,2),size(im,3),size(im,4)*total_augmentations)
    l_out = zeros(Float32,size(ll,1),size(ll,2),size(ll,3),size(ll,4)*total_augmentations)

    count=1

    for i=1:size(im,4)
        im_out[:,:,:,count] = im[:,:,:,i]
        l_out[:,:,:,count] = ll[:,:,:,i]
        count += 1
        #rotations
        for j in [pi/12, pi/6, -pi/12, -pi/6]
            for k=1:size(im,3)
                im_out[:,:,k,count] = imrotate(im[:,:,k,i],j,Reflect())[1:size(im,1),1:size(im,2)]
            end
            for k=1:size(ll,3)
                l_out[:,:,k,count] = imrotate(ll[:,:,k,i],j,Reflect())[1:size(ll,1),1:size(ll,2)]
            end
            count += 1
        end

        #additive noise
        im_out[:,:,:,count] = im[:,:,:,i] .+ 0.1*rand(Float32,size(im_out,1),size(im_out,2),size(im_out,3))
        l_out[:,:,:,count] = ll[:,:,:,i]
        count += 1

        #Set group of pixels to random value x times
    end

    #Shuffle Positions
    myinds=Random.shuffle(collect(1:size(im_out,4)));
    im_out=im_out[:,:,:,myinds]
    l_out=l_out[:,:,:,myinds]

    (im_out,l_out)
end


function normalize_images(ii)

    mean_img = mean(ii,dims=4)[:,:,:,1]
    std_img = std(ii,dims=4)[:,:,:,1]
    std_img[std_img .== 0.0] .= 1

    ii = (ii .- mean_img) ./ std_img

    min_ref = minimum(ii)
    ii = ii .- min_ref

    max_ref = maximum(ii)
    ii = ii ./ max_ref

    (mean_img,std_img,min_ref,max_ref)
end

function ffmpeg_cmd(st,vid_name,num_frames,temp_file)
`$(FFMPEG.ffmpeg) -y -loglevel panic -ss $(st) -i $(vid_name) -frames:v $(num_frames) -f rawvideo -pix_fmt gray $(temp_file)`
end

function normalize_new_images(ii::KnetArray,mean_img::Array,std_img,min_ref,max_ref)
    normalize_new_images(ii,convert(KnetArray,mean_img),convert(KnetArray,std_img),min_ref,max_ref)
end

function normalize_new_images(ii,mean_img)
    ii = ii ./ 255
    ii = ii .- mean_img
end

#=
Convert Discrete points to heatmap for deep learning
=#
function make_heatmap_labels(han,real_w=640,real_h=480,label_img_size=64)

    d_points=make_discrete_all_whiskers(han)

    labels=zeros(Float32,label_img_size,label_img_size,size(d_points,1),size(han.woi,1))

    for i=1:size(labels,4)
        for j=1:size(labels,3)
            this_x = d_points[j,1,i] / real_w * label_img_size
            this_y = d_points[j,2,i] / real_h * label_img_size

            if (this_x !=0.0)&(this_y != 0.0)
                labels[:,:,j,i] = WhiskerTracking.gaussian_2d(1.0:1.0:label_img_size,1.0:1.0:label_img_size,this_y,this_x)
                labels[:,:,j,i] = labels[:,:,j,i] ./ maximum(labels[:,:,j,i])
            end
        end
    end

    labels
end

function get_labeled_frames(han,out_hw=256,h=480,w=640,frame_rate=25)

    imgs=zeros(Float32,out_hw,out_hw,1,length(han.frame_list))

    temp=zeros(UInt8,w,h)
    for i=1:length(han.frame_list)
        frame_time = han.frame_list[i] / frame_rate
        WhiskerTracking.load_single_frame(frame_time,temp,han.wt.vid_name)
        imgs[:,:,1,i]=Images.imresize(temp',(out_hw,out_hw))
    end
    imgs
end
