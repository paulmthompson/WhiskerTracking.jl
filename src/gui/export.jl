
function add_export_callbacks(b::Gtk.GtkBuilder,handles::Tracker_Handles)

    signal_connect(export_button_cb,b["export_button"],"clicked",Void,(),false,(handles,))

    nothing
end

function export_button_cb(w::Ptr,user_data::Tuple{Tracker_Handles})

    han, = user_data

    setproperty!(han.b["export_button"],:label,"Exporting to MAT file...")

    e_angle = getproperty(han.b["angle_export_button"],:active,Bool)
    e_curve = getproperty(han.b["curvature_export_button"],:active,Bool)
    e_phase = getproperty(han.b["phase_export"],:active,Bool)
    e_whisker = getproperty(han.b["whisker_export"],:active,Bool)

    #Convert to Janelia
    (my_whiskers,mytracked)=convert_discrete_to_janelia(han.nn.predicted,han.nn.confidence_thres,han.wt.pad_pos);

    face_axis_num=getproperty(han.b["face_axis_combo"],:active,Int64)

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
        if e_whisker
            write(file,"Whisker",han.nn.predicted)
        end
    write(file,"Tracked",mytracked)
    close(file)

    setproperty!(han.b["export_button"],:label,"Export")
    println("Export complete")

    nothing
end
