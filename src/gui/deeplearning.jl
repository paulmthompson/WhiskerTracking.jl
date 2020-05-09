
function _make_deeplearning_gui()

    grid = Grid()

    create_button = Button("Create Model")
    grid[1,1] = create_button

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

    prediction_grid[1,1] = Label("Adjust parameters for predicting with trained model")

    confidence_sb = SpinButton(0.1:0.1:0.9)
    setproperty!(confidence_sb,:value,0.5)
    prediction_grid[1,2] = confidence_sb
    prediction_grid[2,2] = Label("Confidence Threshold")


    win = Window(grid)
    Gtk.showall(win)
    visible(win,false)

    c_widgets=deep_learning_widgets(win,prog,create_button,training_button,epochs_sb,confidence_sb)
end

function add_deeplearning_callbacks(w,handles)
    signal_connect(create_button_cb,w.create_button,"clicked",Void,(),false,(handles,))
    signal_connect(training_button_cb,w.train_button,"clicked",Void,(),false,(handles,))
    signal_connect(epochs_sb_cb,w.epochs_sb,"value-changed",Void,(),false,(handles,))
    signal_connect(confidence_sb_cb,w.confidence_sb,"value-changed",Void,(),false,(handles,))

    nothing
end

function create_button_cb(w::Ptr,user_data::Tuple{Tracker_Handles})

    han, = user_data

    set_up_training(han) #heatmaps, labels, normalize, augment

    hg=HG2(size(han.nn.labels,1),size(han.nn.labels,3),4);

    han.nn.losses=zeros(Float32,0)

    load_hourglass("quad_hourglass_64.mat",hg)
    change_hourglass(hg,size(han.nn.labels,1),1,size(han.nn.labels,3))

    han.nn.hg = hg

    nothing
end

function training_button_cb(w::Ptr,user_data::Tuple{Tracker_Handles})

    han, = user_data

    dtrn=make_training_batch(han.nn.imgs,han.nn.labels);

    myadam=Adam(lr=1e-3)
    @async run_training(han.nn.hg,dtrn,myadam,han.dl_widgets.prog,han.nn.epochs,han.nn.losses)

    nothing
end

function epochs_sb_cb(w::Ptr,user_data::Tuple{Tracker_Handles})

    han, = user_data

    han.nn.epochs=getproperty(han.dl_widgets.epochs_sb,:value,Int)

    nothing
end

function confidence_sb_cb(w::Ptr,user_data::Tuple{Tracker_Handles})

    han, = user_data

    han.nn.confidence_thres=getproperty(han.dl_widgets.confidence_sb,:value,Int)

    nothing
end

function set_up_training(han)
    han.nn.labels=WhiskerTracking.make_heatmap_labels(han)
    han.nn.imgs=WhiskerTracking.get_labeled_frames(han);

    (mean_img,std_img,min_ref,max_ref)=WhiskerTracking.normalize_images(han.nn.imgs);
    han.nn.norm.mean_img = mean_img
    han.nn.norm.std_img = std_img
    han.nn.norm.min_ref = min_ref
    han.nn.norm.max_ref = max_ref

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
        end
    end

    ls
end
