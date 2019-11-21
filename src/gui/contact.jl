
function _make_contact_gui()

    grid=Grid()

    training_frame = Frame("Training Data")
    training_grid = Grid()
    push!(training_frame,training_grid)
    grid[1,1]=training_frame

    training_grid[1,1]=Label("Total Training Frames: ")
    training_num_label=Label("1")
    training_grid[2,1]=training_num_label

    tracked_frame = Frame("Predicted Data")
    tracked_grid = Grid()
    push!(tracked_frame,tracked_grid)
    grid[1,2]=tracked_frame

    tracked_load_button = Button("Load Predicted Contact and Pole")
    tracked_grid[1,1] = tracked_load_button

    classifier_frame = Frame("Classifier")
    classifier_grid = Grid()
    push!(classifier_frame, classifier_grid)
    grid[1,3]=classifier_frame

    predictors_box=Box(:v)
    push!(predictors_box,Label("Predictors: "))

    pred_pole_button = CheckButton("Distance to Pole")
    push!(predictors_box,pred_pole_button)

    pred_pole_position = CheckButton("Pole Position")
    push!(predictors_box,pred_pole_position)

    pred_curv = CheckButton("Curvature")
    push!(predictors_box,pred_curv)

    classifier_grid[1,1]=predictors_box

    fit_button = Button("Fit Classifier")
    classifier_grid[1,2]=fit_button

    n_estimators_button = SpinButton(1:1000)
    setproperty!(n_estimators_button,:value,100)
    classifier_grid[2,2] = n_estimators_button

    classifier_grid[3,2] = Label("Number of Estimators")

    forest_depth_button = SpinButton(1:100)
    setproperty!(forest_depth_button,:value,10)
    classifier_grid[4,2] = forest_depth_button

    classifier_grid[5,2] = Label("Forest Depth")

    classifier_grid[1,3] = Label("Cross-validation prediction accuracy: ")
    cv_label = Label("")
    classifier_grid[2,3] = cv_label


    win = Window(grid)
    Gtk.showall(win)
    visible(win,false)

    c_widgets=contact_widgets(win,training_num_label,fit_button,tracked_load_button,
    n_estimators_button,forest_depth_button,cv_label,pred_pole_button,
    pred_pole_position,pred_curv)
end

function add_contact_callbacks(w,handles)

    signal_connect(contact_fit_cb,w.fit_button,"clicked",Void,(),false,(handles,))
    signal_connect(contact_load_predicted_cb,w.load_predicted_button,"clicked",Void,(),false,(handles,))

    signal_connect(contact_estimators_cb,w.n_estimators_button,"value-changed",Void,(),false,(handles,))
    signal_connect(contact_depth_cb,w.forest_depth_button,"value-changed",Void,(),false,(handles,))

    nothing
end

function contact_fit_cb(w::Ptr,user_data::Tuple{Tracker_Handles})

    han, = user_data

    han.class.clf=RandomForestClassifier(n_estimators=han.class.n_estimators,max_depth=han.class.forest_depth,random_state=0)

    #Select which variables to use
    if getproperty(han.c_widgets.pred_pole_button,:active,Bool)

    end

    if getproperty(han.c_widgets.pred_pole_position,:active,Bool)

    end

    if getproperty(han.c_widgets.pred_curv,:active,Bool)

    end
    
    #Remove NaNs
    #han.class.predictors[isnan.(han.class.predictors)] .= 0.0

    #Create prediction
    #ScikitLearn.fit!(han.class.clf,han.class.predictors,han.tracked_contact)

    #Cross validation
    #cross_val_rf=mean(cross_val_score(han.class.clf, han.class.predictors, han.tracked_contact, cv=10))

    #setproperty!(han.c_widgets.cv_label,:label,han.class.cv)

    nothing
end

#Cross validate function

#Predict Function

function contact_estimators_cb(w::Ptr,user_data::Tuple{Tracker_Handles})

    han, = user_data

    han.class.n_estimators=getproperty(han.c_widgets.n_estimators_button,:value,Int64)

    nothing
end

function contact_depth_cb(w::Ptr,user_data::Tuple{Tracker_Handles})

    han, = user_data

    han.class.forest_depth=getproperty(han.c_widgets.forest_depth_button,:value,Int64)

    nothing
end

#Load labels
function load_contact_cb(w::Ptr,user_data::Tuple{Tracker_Handles})

    han, = user_data

    filepath = open_dialog("Load Contact Data",han.win)

    if filepath != ""
        file = matopen(filepath,"r")
        if MAT.exists(file,"Touch_Inds")
            touch_inds = read(file,"Touch_Inds")
            han.touch_frames_i = touch_inds
            setproperty!(han.contact_widgets.training_num_label,:label,string(length(han.touch_frames_i)))
        end
        if MAT.exists(file,"Touch")
            touch = read(file,"Touch")
            han.touch_frames = convert(BitArray{1},touch)
        end
        close(file)
    end

    nothing
end

function save_contact_cb(w::Ptr,user_data::Tuple{Tracker_Handles})

    han, = user_data

    filepath = save_dialog("Save Contact Data",han.win)

    if filepath != ""
        if filepath[end-3:end]==".mat"
        else
            filepath=string(filepath,".mat")
        end

        file=matopen(filepath,"w")
        write(file,"Touch_Inds",han.touch_frames_i)
        write(file,"Touch",convert(Array{Int64,1},han.touch_frames))
        close(file)
    end

    nothing
end

function contact_load_predicted_cb(w::Ptr,user_data::Tuple{Tracker_Handles})

    han, = user_data

    #Load Contact
    filepath = open_dialog("Load Predicted Labels",han.win)

    if filepath != ""

        file = matopen(filepath,"r")
        if MAT.exists(file,"Contact")
            contact = read(file,"Contact")
            han.tracked_contact = contact
        end
    end

    filepath = open_dialog("Load Tracked Pole",han.win)

    if filepath != ""

        p=read_pole_hdf5(filepath)
        han.tracked_pole = p
    end

    nothing
end

# Mark Contact Training Frame or not training frame
function touch_override_cb(w::Ptr,user_data::Tuple{Tracker_Handles,Int64})

    han, contact = user_data

    #Check if this frame is already in the contact list
    if isempty(find(han.touch_frames_i.==han.displayed_frame))

        push!(han.touch_frames_i,han.displayed_frame)
        push!(han.touch_frames,contact)

        setproperty!(han.contact_widgets.training_num_label,:label,string(length(han.touch_frames_i)))

        #Do we need to sort these here?

    else #Change existing entry

        ind=find(han.touch_frames_i.==han.displayed_frame)[1]
        han.touch_frames[ind] = contact
    end

    draw_touch(han)

    nothing
end
