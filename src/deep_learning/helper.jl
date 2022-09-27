
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

function ffmpeg_cmd(st,vid_name,num_frames,temp_file)
`$(FFMPEG.ffmpeg) -y -loglevel panic -ss $(st) -i $(vid_name) -frames:v $(num_frames) -f rawvideo -pix_fmt gray $(temp_file)`
end

#=
Convert Discrete points to heatmap for deep learning
=#

function make_heatmap_labels(woi,pad_pos,real_w=640,real_h=480,label_img_size=64)

    d_points=make_discrete_all_whiskers(woi,pad_pos)

    labels=zeros(Float32,label_img_size,label_img_size,size(d_points,1),size(woi,1))

    for i=1:size(labels,4)
        for j=1:size(labels,3)
            this_x = d_points[j,1,i] / real_w * label_img_size
            this_y = d_points[j,2,i] / real_h * label_img_size

            if (this_x !=0.0)&(this_y != 0.0)
                labels[:,:,j,i] = StackedHourglass.gaussian_2d(1.0:1.0:label_img_size,1.0:1.0:label_img_size,this_y,this_x)
                labels[:,:,j,i] = labels[:,:,j,i] ./ maximum(labels[:,:,j,i])
            end
        end
    end

    labels
end


function get_labeled_frames(vid_name,frame_list,out_hw=256)

    (w,h,frame_rate)=get_vid_dims(vid_name)

    imgs=zeros(Float32,out_hw,out_hw,1,length(frame_list))

    temp=zeros(UInt8,w,h)
    for i=1:length(frame_list)
        frame_time = frame_list[i] / frame_rate
        load_single_frame(frame_time,temp,vid_name)
        imgs[:,:,1,i]=Images.imresize(temp',(out_hw,out_hw))
    end
    imgs
end
