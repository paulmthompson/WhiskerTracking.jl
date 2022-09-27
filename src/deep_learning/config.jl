
function training_from_config(filepath)

    (vid_name,frame_list,woi,pad_pos,training_path,epochs,data_path,nn,max_frames) = load_config(filepath)

    set_up_training(nn,vid_name,max_frames,woi,pad_pos,frame_list) #heatmaps, labels, normalize, augment
    save_training(training_path,frame_list,woi,nn)

    if !nn.use_existing_weights
        create_new_weights(han.nn)
    end

    if size(nn.labels,3) != features(nn.hg)
        StackedHourglass.change_hourglass_output(nn.hg,size(nn.labels,1),size(nn.labels,3))
        nn.features = features(nn.hg)
    end

    dtrn=make_training_batch(nn.imgs,nn.labels);

    myadam=Adam(lr=1e-3)
    run_training_no_gui(nn.hg,dtrn,myadam,nn.epochs,nn.losses)

    save_hourglass(string(data_path,"/weights.jld"),nn.hg)

end

function prediction_from_config(filepath)

    (vid_name,frame_list,woi,pad_pos,training_path,epochs,data_path,nn,max_frames) = load_config(filepath)

    config_path = string(data_path,"/weights.jld")
    load_hourglass_to_nn(nn,config_path)

    set_up_training(nn,vid_name,max_frames,woi,pad_pos,frame_list) #heatmaps, labels, normalize, augment
    save_training(training_path,frame_list,woi,nn)

    nn.predicted = calculate_whiskers(nn,vid_name,total_frames)

    #Save?
end

function read_training_config(filepath)
    file=jldopen(filepath,"r")
    training = read(file,"Training")
    close(file)
    training
end

function load_config(filepath)

    file=jldopen(filepath,"r")
    vid_name = read(file,"Video_Name")
    frame_list = read(file,"Tracking_Frames")
    woi=read(file,"WOI")
    pad_pos=read(file,"Pad_Pos")
    training_path=read(file,"Training_Path")
    epochs=read(file,"Epochs")
    data_path=read(file,"Data_Path")
    close(file)

    nn=NeuralNetwork()
    nn.epochs=epochs
    max_frames = get_max_frames(vid_name)

    (vid_name,frame_list,woi,pad_pos,training_path,epochs,data_path,nn,max_frames)
end
