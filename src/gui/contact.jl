
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

    

    fit_button = Button("Fit Classifier")
    classifier_grid[1,1]=fit_button


    win = Window(grid)
    Gtk.showall(win)
    visible(win,false)

    c_widgets=contact_widgets(win,training_num_label,fit_button,tracked_load_button)
end

function add_contact_callbacks(w,handles)

    signal_connect(contact_fit_cb,w.fit_button,"clicked",Void,(),false,(handles,))

    signal_connect(contact_load_predicted_cb,w.load_predicted_button,"clicked",Void,(),false,(handles,))

    nothing
end

function contact_fit_cb(w::Ptr,user_data::Tuple{Tracker_Handles})

    han, = user_data

    nothing
end

function load_contact_cb(w::Ptr,user_data::Tuple{Tracker_Handles})

    han, = user_data

    filepath = open_dialog("Load Contact Data",han.win)

    if filepath != ""
        file = matopen(filepath,"r")
        if MAT.exists(file,"Touch_Inds")
            touch_inds = read(file,"Touch_Inds")
            han.touch_frames_i = touch_inds
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

        #Do we need to sort these here?

    else #Change existing entry

        ind=find(han.touch_frames_i.==han.displayed_frame)[1]
        han.touch_frames[ind] = contact
    end

    draw_touch(han)

    nothing
end
