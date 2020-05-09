
function _make_deeplearning_gui()

    grid = Grid()

    training_button = Button("Train!")
    grid[1,2] = training_button

    create_button = Button("Create Model")
    grid[1,1] = create_button

    prog = ProgressBar();
    grid[2:3,2] = prog

    win = Window(grid)
    Gtk.showall(win)
    visible(win,false)

    c_widgets=deep_learning_widgets(win,prog,create_button,training_button)
end

function add_deeplearning_callbacks(w,handles)
    signal_connect(create_button_cb,w.create_button,"clicked",Void,(),false,(handles,))
    signal_connect(training_button_cb,w.train_button,"clicked",Void,(),false,(handles,))

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
