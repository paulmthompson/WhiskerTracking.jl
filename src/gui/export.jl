
function _make_export_gui()

    grid=Grid()

    grid[1,1] = Label("How is the animal oriented in your video?")

    face_axis_combo = ComboBoxText()
    for choice in ["Horizontal Animal (Whiskers are Vertical)"; "Vertical Animal (Whiskers are Horizontal)"]
        push!(face_axis_combo,choice)
    end
    setproperty!(face_axis_combo,:active,0)
    grid[2,1] = face_axis_combo

    grid[1,2] = Label("Select the variables to export")



    angle_button = CheckButton("Angle")
    setproperty!(angle_button,:active,true)
    grid[1,3] = angle_button

    curve_button = CheckButton("Curvature")
    setproperty!(curve_button,:active,true)
    grid[1,4] = curve_button

    phase_button = CheckButton("Phase")
    setproperty!(phase_button,:active,true)
    grid[1,5] = phase_button

    export_button = Button("Export!")
    grid[1,6] = export_button

    win = Window(grid)
    Gtk.showall(win)
    visible(win,false)

    e_widgets = export_widgets(win,face_axis_combo,angle_button,curve_button,phase_button,
    export_button)
end


function add_export_callbacks(w::export_widgets,handles::Tracker_Handles)

    signal_connect(export_angle_cb,w.angle_button,"clicked",Void,(),false,(handles,))
    signal_connect(export_curve_cb,w.curve_button,"clicked",Void,(),false,(handles,))
    signal_connect(export_phase_cb,w.phase_button,"clicked",Void,(),false,(handles,))

    signal_connect(export_button_cb,w.export_button,"clicked",Void,(),false,(handles,))

    nothing
end

function export_angle_cb(w::Ptr,user_data::Tuple{Tracker_Handles})

    nothing
end

function export_curve_cb(w::Ptr,user_data::Tuple{Tracker_Handles})

    nothing
end

function export_phase_cb(w::Ptr,user_data::Tuple{Tracker_Handles})

    nothing
end

function export_button_cb(w::Ptr,user_data::Tuple{Tracker_Handles})

    han, = user_data

    setproperty!(han.export_widgets.export_button,:label,"Exporting to MAT file...")

    e_angle = getproperty(han.export_widgets.angle_button,:active,Bool)

    e_curve = getproperty(han.export_widgets.curve_button,:active,Bool)

    e_phase = getproperty(han.export_widgets.phase_button,:active,Bool)

    #try
    myrange_i = (1,size(han.tracked_whiskers_x,2))
    interp_resolution=5.0

    (wx,wy,mytracked)=interpolate_dlc(han.tracked_whiskers_x,han.tracked_whiskers_y,
    han.tracked_whiskers_l,myrange_i,interp_resolution)

    #Convert to Janelia
    my_whiskers=convert_whisker_points_to_janelia(wx,wy,mytracked);

    face_axis_num=getproperty(han.export_widgets.face_axis,:active,Int64)

    if face_axis_num == 0
        (mycurv,myangles)=get_curv_and_angle(my_whiskers,mytracked,han.wt.pad_pos);
    else
        (mycurv,myangles)=get_curv_and_angle(my_whiskers,mytracked,han.wt.pad_pos,face_axis='y');
    end

    #Whisking phase calculation
    phase_low_band=8.0 #Band pass filter lower band
    phase_high_band=30.0 #Band pass filter upper band
    myphase=WhiskerTracking.get_phase(myangles,bp_l=phase_low_band,bp_h=phase_high_band);

    filepath=string(han.wt.data_path,"output.mat")
    file=matopen(filepath,"w")
        if e_angle
            write(file,"Angles",myangles)
        end
        if e_curve
            write(file,"Curvature",mycurv)
        end
        if e_phase
            write(file,"Phase",myphase)
        end
    write(file,"Tracked",mytracked)
    close(file)

    #catch
    #end

    setproperty!(han.export_widgets.export_button,:label,"Export")
    println("Export complete")

    nothing
end
