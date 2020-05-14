
function _make_deeplearning_gui()

    grid = Grid()

    network_frame = Frame("Options")
    grid[1,1] = network_frame
    network_grid = Grid()
    push!(network_frame,network_grid)

    network_grid[1,1]=Label("Model Type: ")
    network_grid[1,2]=Label("Stacked Hourglass, \n 64 Channel")

    network_grid[2,1] = Label("Model Weights: ")
    model_weights_label = Label("Train from scratch")
    network_grid[2,2] = model_weights_label
    load_weights_button = Button("Load Weights")
    network_grid[2,3] = load_weights_button

    network_grid[3,1] = Label("Training Dataset: ")
    model_labels_label = Label("Use labels in this video")
    network_grid[3,2] = model_labels_label
    load_labels_button = Button("Load Existing Labels")
    network_grid[3,3] = load_labels_button

    create_training_button = Button("Create Model")
    network_grid[1,4] = create_training_button

    training_frame = Frame("Training")
    grid[1,2] = training_frame
    training_grid=Grid()
    push!(training_frame,training_grid)

    training_grid[1,1] = Label("Adjust values for training your model")

    training_button = Button("Train!")
    training_grid[1,2] = training_button

    prog = ProgressBar();
    training_grid[2:3,2] = prog

    epochs_sb = SpinButton(1:10000)
    setproperty!(epochs_sb,:value,10)
    training_grid[1,3] = epochs_sb
    training_grid[2,3] = Label("Epochs")

    prediction_frame = Frame("Prediction")
    grid[1,3] = prediction_frame
    prediction_grid = Grid()
    push!(prediction_frame,prediction_grid)

    prediction_grid[1,1] = Label("Adjust parameters for \n predicting with trained model")

    confidence_sb = SpinButton(0.1:0.1:0.9)
    setproperty!(confidence_sb,:value,0.5)
    prediction_grid[1,2] = confidence_sb
    prediction_grid[2,2] = Label("Confidence Threshold")


    win = Window(grid)
    Gtk.showall(win)
    visible(win,false)

    c_widgets=deep_learning_widgets(win,prog,create_training_button, load_weights_button, false, model_weights_label,
    load_labels_button, false, model_labels_label,
    training_button,epochs_sb,confidence_sb)
end

function add_deeplearning_callbacks(w,handles)

    signal_connect(load_weights_cb,w.load_weights_button,"clicked",Void,(),false,(handles,))
    signal_connect(load_labels_cb,w.load_labels_button,"clicked",Void,(),false,(handles,))

    signal_connect(create_training_cb,w.create_button,"clicked",Void,(),false,(handles,))

    signal_connect(training_button_cb,w.train_button,"clicked",Void,(),false,(handles,))
    signal_connect(epochs_sb_cb,w.epochs_sb,"value-changed",Void,(),false,(handles,))
    signal_connect(confidence_sb_cb,w.confidence_sb,"value-changed",Void,(),false,(handles,))

    nothing
end

function load_weights_cb(w::Ptr,user_data::Tuple{Tracker_Handles})

    han, = user_data

    config_path = open_dialog("Load Previous Weights",han.win)

    if config_path != ""

        try
            han.nn.weight_path = config_path
            hg=HG2(64,1,4); #Dummy Numbers
            load_hourglass(han.nn.weight_path,hg)
            han.nn.hg = hg
            setproperty!(han.dl_widgets.weights_label,:label,config_path)
            han.dl_widgets.use_existing_weights = true
            han.nn.features=features(hg)
        catch
            println("Could not load weights")
        end
    end

    nothing
end

function load_labels_cb(w::Ptr,user_data::Tuple{Tracker_Handles})

    han, = user_data

    config_path = open_dialog("Load Previous Labels",han.win)

    if config_path != ""

        try
            load_training(han,config_path)
            setproperty!(han.dl_widgets.labels_label,:label,config_path)
            han.dl_widgets.use_existing_labels = true
        catch
            println("Could not load labeled data")
        end

        println("Previous Session Loaded")
    end

    nothing
end

function create_training_cb(w::Ptr,user_data::Tuple{Tracker_Handles})

    han, = user_data

    if !han.dl_widgets.use_existing_labels
        set_up_training(han) #heatmaps, labels, normalize, augment
        save_training(han)
    else
        set_up_training(han,false)
        save_training(han)
    end

    if !han.dl_widgets.use_existing_weights
        hg=HG2(size(han.nn.labels,1),size(han.nn.labels,3),4);
        load_hourglass(han.nn.weight_path,hg)
        change_hourglass(hg,size(han.nn.labels,1),1,size(han.nn.labels,3))
        han.nn.features=features(hg)
        han.nn.hg = hg
    end

    nothing
end

function save_training(han)

    file = jldopen(string(han.paths.backup,"/labels.jld"), "w")
    write(file, "frame_list",han.frame_list)
    write(file, "woi",han.woi)
    write(file, "mean_img",han.nn.norm.mean_img)
    write(file, "std_img",han.nn.norm.std_img)

    close(file)

    nothing
end

function load_training(han,path)

    file = jldopen(path, "r")
    han.frame_list = read(file, "frame_list")
    han.woi = read(file, "woi")
    han.nn.norm.mean_img = read(file, "mean_img")
    han.nn.norm.std_img = read(file, "std_img")

    Gtk.GAccessor.range(han.frame_advance_sb,1,length(han.frame_list))
    han.tracked=trues(length(han.frame_list))

    han.pole_present=falses(length(han.frame_list))
    han.pole_loc=zeros(Float32,length(han.frame_list),2)

    close(file)

end

function training_button_cb(w::Ptr,user_data::Tuple{Tracker_Handles})

    han, = user_data

    dtrn=make_training_batch(han.nn.imgs,han.nn.labels);

    myadam=Adam(lr=1e-3)
    @async begin
        run_training(han.nn.hg,dtrn,myadam,han.dl_widgets.prog,han.nn.epochs,han.nn.losses)
    end
    #save_hourglass(string(han.paths.backup,"weights.jld"),han.nn.hg)

    nothing
end

function epochs_sb_cb(w::Ptr,user_data::Tuple{Tracker_Handles})

    han, = user_data

    han.nn.epochs=getproperty(han.dl_widgets.epochs_sb,:value,Int)

    nothing
end

function confidence_sb_cb(w::Ptr,user_data::Tuple{Tracker_Handles})

    han, = user_data

    han.nn.confidence_thres=getproperty(han.dl_widgets.confidence_sb,:value,Float64)

    nothing
end

function mean_std_video_gpu(han::Tracker_Handles,total_frame_num)
    mean_std_video_gpu(han.wt.vid_name,total_frame_num)
end

function mean_std_video_gpu(vid_name::String,total_frame_num,w=640,h=480,max_intensity=255,loading_size=500)
    load_number = div(total_frame_num, loading_size)-1

    temp_frames=zeros(UInt8,w,h,loading_size)

    temp_frames2 = convert(KnetArray,zeros(Float32,w,h,loading_size))

    running_mean = convert(KnetArray,zeros(Float32,w,h,1))
    running_mean_i = convert(KnetArray,zeros(Float32,w,h,1))

    running_std = convert(KnetArray,zeros(Float32,w,h,1))
    running_std_i = convert(KnetArray,zeros(Float32,w,h,1))

    run(WhiskerTracking.ffmpeg_cmd(0,vid_name,loading_size,"test5.yuv"))
    read!("test5.yuv",temp_frames)

    temp_frames2[:]=convert(KnetArray{Float32,3},temp_frames)
    running_mean_i[:,:,1] = mean(temp_frames2,dims=3) ./ max_intensity

    for i=1:load_number
        run(WhiskerTracking.ffmpeg_cmd(i*loading_size / 25,vid_name,loading_size,"test5.yuv"))
        read!("test5.yuv",temp_frames)
        temp_frames2[:]=convert(KnetArray{Float32,3},temp_frames)

        x_k = mean(temp_frames2,dims=3) ./ max_intensity

        running_mean = running_mean_i .+ (x_k .- running_mean_i) ./ (i+1)

        running_std = running_std_i .+ (x_k .- running_mean_i).*(x_k - running_mean)

        running_mean_i = running_mean
        running_std_i = running_std
    end

    rm("test5.yuv")

    (convert(Array,running_mean), convert(Array,running_std))
end

function set_up_training(han,get_mean=true)

    if get_mean
        (mean_img,std_img)=mean_std_video_gpu(han,han.max_frames)
        han.nn.norm.min_ref = 0
        han.nn.norm.max_ref = 255
        han.nn.norm.mean_img = mean_img
        han.nn.norm.std_img = std_img

        #Rotate and Reshape to 256 256
        han.nn.norm.mean_img = reshape(imresize(han.nn.norm.mean_img[:,:,1]',(256,256)),(256,256,1))
    end

    han.nn.labels=make_heatmap_labels(han)
    han.nn.imgs=get_labeled_frames(han);

    #Normalize
    han.nn.imgs=normalize_new_images(han.nn.imgs,han.nn.norm.mean_img);

    (han.nn.imgs,han.nn.labels)=WhiskerTracking.augment_images(han.nn.imgs,han.nn.labels);
end

function make_training_batch(img,ll,batch_size=8)
    dtrn=minibatch(img,ll,batch_size,xtype=KnetArray,ytype=KnetArray)
end


function run_training(hg,trn::Knet.Data,this_opt,p,epochs=100,ls=Array{Float64,1}())

    total_length=length(trn) * epochs
    minimizer = Knet.minimize(hg,ncycle(trn,epochs),this_opt)
    last_update = 0.0
    count=0
    Gtk.set_gtk_property!(p, :fraction, 0)
    sleep(0.0001)

        for x in takenth(minimizer,1)
            push!(ls,x)
            count+=1
            complete=round(count/total_length,digits=2)
            if complete > last_update
                Gtk.set_gtk_property!(p, :fraction, complete)
                last_update = complete
                sleep(0.0001)
                reveal(p,true)
            end
        end


    ls
end

function predict_single_frame(han)

    k_mean = convert(KnetArray,han.nn.norm.mean_img)
    k_std = convert(KnetArray,han.nn.norm.std_img)
    temp_frame = convert(KnetArray{Float32,4},reshape(han.current_frame,(size(han.current_frame,1),size(han.current_frame,2),1,1)))
    temp_frame = my_imresize(temp_frame,256,256)

    temp_frame = normalize_new_images(temp_frame,k_mean)

    set_testing(han.nn.hg,false) #Turn off batch normalization for prediction
    myout=han.nn.hg(temp_frame)[4]
    set_testing(han.nn.hg,true) #Turn back on

    hi=argmax(myout,dims=(1,2))
    preds=zeros(Float32,2,han.nn.features)
    confidences=zeros(Float32,han.nn.features)

    for kk=1:size(hi,3)
        confidences[kk] = myout[hi[1,1,kk,1][1],hi[1,1,kk,1][2],kk,1]
    end

    kernel_pad = create_padded_kernel(size(myout,1),size(myout,2),1)
    #kernel_pad = convert(CuArray,kernel_pad)

    k_fft = fft(kernel_pad)
    #myout = CuArray(myout)
    input=fft(convert(Array,myout),(1:2))

    for i=1:size(myout,3)

        preds[:,i]=subpixel(input[:,:,i,1],k_fft,4) .+ 32.0
    end

    (preds', confidences)
end

function draw_predictions(han)

    (preds,confidences) = predict_single_frame(han)

    circ_rad=5.0

    ctx=Gtk.getgc(han.c)
    Cairo.set_source_rgb(ctx,0,1,0)
    num_points = size(preds,1)

    for i=1:num_points
        if confidences[i] > han.nn.confidence_thres
            Cairo.arc(ctx, preds[i,1] / 64 * 640,preds[i,2] / 64 * 480, circ_rad, 0, 2*pi);
            Cairo.stroke(ctx);
        end
    end
    reveal(han.c)
end
