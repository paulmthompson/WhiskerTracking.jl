function save_single_image(han::Tracker_Handles,path=han.paths.images,use_contrast=false; flip_x=false,flip_y=false)
    save_single_image(han,han.current_frame,han.displayed_frame,path,use_contrast,flip_x=flip_x,flip_y=flip_y)
end

function save_single_image(han::Tracker_Handles,img::AbstractArray,num::Int,path=han.paths.images,use_contrast=false; flip_x=false,flip_y=false)

    img_name = name_img(han,"img",num)

    save_img_with_dir_change(han,img_name,img,path,use_contrast,flip_x,flip_y)

    nothing
end

function save_label_image(han::Tracker_Handles,path=han.paths.images,interp=false; flip_x=false, flip_y=false)

    img_name = name_img(han,"w",han.displayed_frame)

    img = create_label_image(han,0,interp)

    save_img_with_dir_change(han,img_name,img,path,false,flip_x,flip_y)

    nothing
end

function save_follicle_image(han::Tracker_Handles,path=han.paths.images)

    img_name = name_img(han,"w",han.displayed_frame)

    img = create_follicle_image(han)

    save_img_with_dir_change(han,img_name,img,path)

    nothing
end

function save_img_with_dir_change(han::Tracker_Handles,img_name::String,img::AbstractArray,path=han.paths.images,use_contrast=false,flip_x=false,flip_y=false)
    my_wd=pwd()
    cd(path)
    out_img = deepcopy(img)
    if use_contrast
        img2 = deepcopy(out_img)
        adjust_contrast(img2,han.contrast_min,han.contrast_max)
        out_img = img2
    end

    if flip_x
        reverse!(out_img,dims=1)
    end
    if flip_y
        reverse!(out_img, dims=2)
    end

    Images.save(img_name, out_img)

    cd(my_wd)
end

function name_img(han::Tracker_Handles,name_prefix,num)

    #Deeplabcut needs left padded zeros
    max_dig=length(digits(han.max_frames))
    img_name = string(name_prefix,lpad(num,max_dig,"0"),".png")
end

function create_label_images(han::Tracker_Handles,rad=0,interp=false)
    imgs=zeros(Float32,64,64,1,length(han.woi))

    i=1
    for woi in han.woi
        img = zeros(UInt8,size(han.current_frame))
        imgs[:,:,1,i] = StackedHourglass.low_pass_pyramid(create_label_image(img,woi[2],rad,interp),(64,64))
        i+=1
    end
    imgs
end

function create_label_image(han::Tracker_Handles,rad=0,interp=false)
    img = zeros(UInt8,size(han.current_frame))

    w1=han.woi[han.displayed_frame]

    create_label_image(img,w1,rad,interp)
end

function load_whisker_into_gui(han,path)

    tracked = load_whisker(path)

    han.tracked_w=Tracked_Whisker(han.max_frames)

    for key in keys(tracked)
        if key != 0
            han.tracked_w.whiskers_x[key] = tracked[key][1]
            han.tracked_w.whiskers_y[key] = tracked[key][2]
            han.tracked_w.whiskers_l[key] = tracked[key][3]
        end
    end

    han.tracked_w.path = path

    nothing
end

function write_mask(han,filepath)
    jldopen(filepath, "w") do file
        file["mask"] = han.mask
    end
end