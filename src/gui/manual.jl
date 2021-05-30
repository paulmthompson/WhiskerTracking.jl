
function add_contact_mark_callbacks(b,handles)

    signal_connect(contact_onset_cb,b["contact_block_button"],"toggled",Void,(),false,(handles,))
    signal_connect(no_contact_cb,b["no_contact_block_button"],"toggled",Void,(),false,(handles,))

    signal_connect(contact_select_cb,b["contact_spin"],"value-changed",Void,(),false,(handles,))

    signal_connect(pro_re_cb,b["protraction_button"],"clicked",Void,(),false,(handles,1))
    signal_connect(pro_re_cb,b["retraction_button"],"clicked",Void,(),false,(handles,2))

    signal_connect(exclude_cb,b["exclude_button"],"toggled",Void,(),false,(handles,))

    nothing
end

function pro_re_cb(w::Ptr,user_data::Tuple{Tracker_Handles,Int})

    han, con_type = user_data

    han.man.pro_re[han.displayed_frame]=con_type

    update_pro_re_block(han.man)

    nothing
end

function update_pro_re_block(man::Manual_Class)

    #https://stackoverflow.com/questions/29848734/is-it-possible-to-sort-a-dictionary-in-julia
    sorted_pro_re=sort(collect(man.pro_re), by=x->x[1])

    for i=1:(length(sorted_pro_re)-1)
        man.pro_re_block[sorted_pro_re[i][1]] = sorted_pro_re[i][2]

        if sorted_pro_re[i+1][2] == sorted_pro_re[i][2]
            man.pro_re_block[sorted_pro_re[i][1]:sorted_pro_re[i+1][1]] .= sorted_pro_re[i][2]
        end
    end

    nothing
end

function contact_onset_cb(w::Ptr,user_data::Tuple{Tracker_Handles})
    han, = user_data

    onset = get_gtk_property(han.b["contact_block_button"],:active,Bool)

    if onset

        han.man.partial_contact = han.displayed_frame

        set_gtk_property!(han.b["contact_block_button"],:label,"Mark Contact Offset")
    else

        if han.displayed_frame > han.man.partial_contact
            push!(han.man.contact_block,(han.man.partial_contact,han.displayed_frame))
            update_contact_block(han.man)
            calc_contact_block(han)
        else
            println("error: start with beginning of contact block")
        end
        set_gtk_property!(han.b["contact_block_button"],:label,"Mark Contact Onset")
    end

    nothing
end

function update_contact_block(man::Manual_Class)

    myrange = make_range(man.contact_block[end])

    man.contact[myrange] .= 2 #Contact

    man.contact_block = sort(man.contact_block, by=x->x[1])

    nothing
end

function no_contact_cb(w::Ptr,user_data::Tuple{Tracker_Handles})
    han, = user_data

    onset = get_gtk_property(han.b["no_contact_block_button"],:active,Bool)

    if onset

        han.man.partial_contact = han.displayed_frame

        set_gtk_property!(han.b["no_contact_block_button"],:label,"Mark End of Block")
    else

        if han.displayed_frame > han.man.partial_contact
            push!(han.man.no_contact_block,(han.man.partial_contact,han.displayed_frame))
            update_no_contact_block(han.man)
            calc_contact_block(han)
        else
            println("error: start with beginning of contact block")
        end
        set_gtk_property!(han.b["no_contact_block_button"],:label,"Mark No Contact")
    end
    nothing
end

function update_no_contact_block(man::Manual_Class)

    myrange = make_range(man.no_contact_block[end])

    man.contact[myrange] .= 1 #No Contact

    man.no_contact_block = sort(man.no_contact_block, by=x->x[1])
end

function exclude_cb(w::Ptr,user_data::Tuple{Tracker_Handles})

    han, = user_data

    onset = get_gtk_property(han.b["exclude_button"],:active,Bool)

    if onset

        han.man.partial_contact = han.displayed_frame

        set_gtk_property!(han.b["exclude_button"],:label,"Mark End of Block")
    else

        if han.displayed_frame > han.man.partial_contact
            push!(han.man.exclude,(han.man.partial_contact,han.displayed_frame))
            update_exclude(han.man)
        else
            println("error: start with beginning of contact block")
        end
        set_gtk_property!(han.b["exclude_button"],:label,"Start Exclude")
    end

    nothing
end

function update_exclude(man::Manual_Class)

    myrange = make_range(man.exclude[end])

    man.exclude_block[myrange] .= true #Exclude Frames

    man.exclude = sort(man.exclude, by=x->x[1])

    nothing
end

function save_manual_class(man::Manual_Class,path)

    file = jldopen(path,"w")
    write(file,"Max_Frames",man.max_frames)
    write(file,"Contact_Block",man.contact_block)
    write(file,"No_Contact_Block",man.no_contact_block)
    write(file,"Contact",man.contact)

    write(file,"Pro_Re",man.pro_re)
    write(file,"Pro_Re_Block",man.pro_re_block)

    write(file, "Exclude",man.exclude)
    write(file, "Exclude_Block",man.exclude_block)

    close(file)
    nothing
end

function load_manual_class(man::Manual_Class,path)

    file = jldopen(path,"r")
    man.max_frames = read(file,"Max_Frames")

    man.contact_block = read(file,"Contact_Block")
    man.no_contact_block = read(file,"No_Contact_Block")
    man.contact = read(file,"Contact")

    man.pro_re = read(file,"Pro_Re")
    man.pro_re_block = read(file,"Pro_Re_Block")

    man.exclude = read(file, "Exclude")
    man.exclude_block = read(file, "Exclude_Block")

    close(file)
    nothing
end

function make_range(x::Tuple)
    x[1]:x[2]
end

function draw_touch2(han::Tracker_Handles)

    if length(han.tracked_contact) == han.max_frames

        ctx=Gtk.getgc(han.c)

        if han.man.contact[han.displayed_frame] != 0 #prefer manual
            if han.man.contact[han.displayed_frame] == 2
                set_source_rgb(ctx,1,0,0)
            else
                set_source_rgb(ctx,1,1,1)
            end
        else
            if han.tracked_contact[han.displayed_frame]
                set_source_rgb(ctx,1,0,0)
            else
                set_source_rgb(ctx,1,1,1)
            end
        end

        rectangle(ctx,620,0,20,20)
        fill(ctx)

        for i=1:length(han.man.calc_contact_block)
            if (han.displayed_frame >= han.man.calc_contact_block[i][1]) & (han.displayed_frame <= han.man.calc_contact_block[i][2])
                set_source_rgb(ctx,0,0,0)
                move_to(ctx,620,15)
                show_text(ctx,string(i))
            end
        end

        reveal(han.c)
    end

    nothing
end

function contact_select_cb(w::Ptr,user_data::Tuple{Tracker_Handles})
    han, = user_data

    c_id = get_gtk_property(han.b["contact_spin"],:value,Int64)

    if (c_id > 0)&(c_id <= length(han.man.calc_contact_block))
        frame = han.man.calc_contact_block[c_id][1]
        set_gtk_property!(han.b["adj_frame"],:value,frame)
    end

    nothing
end

function calc_contact_block(han::Tracker_Handles)

    if length(han.tracked_contact) == han.max_frames
        contact = falses(han.max_frames)
        for i=1:length(han.tracked_contact)
            if han.man.contact[i] == 2
                contact[i] = true
            elseif han.man.contact[i] == 1
                contact[i] = false
            else
                contact[i] = han.tracked_contact[i]
            end
        end

        (c_on,c_off) = get_contact_indexes(contact,han.man.exclude_block)
        han.man.calc_contact_block = [(c_on[i],c_off[i]) for i=1:length(c_on)]

        set_gtk_property!(han.b["contact_number_label"],:label,string(length(c_on)))
        set_gtk_property!(han.b["contact_spin_adj"],:upper,length(c_on))
    end
end

function get_contact_indexes(c,exclude,c_dur_min = 4)

    c_ind=Array{Int64,1}()
    c_off=Array{Int64,1}()

    i=1
    while (i < length(c) - c_dur_min)

        if exclude[i] != true
            if ((c[i] - c[i+1])==-1)
                push!(c_ind,i)
                myoff=findnext(c.==false,i+1)
                if typeof(myoff) == Nothing #single frame contact
                    myoff = i+1
                end

                push!(c_off,myoff)

                i=myoff + 1
            else
                i+=1
            end
        else
            i+= 1
        end
    end

    keep=trues(length(c_ind))
    for i=1:length(c_ind)
        if (c_off[i] - c_ind[i]) < c_dur_min
            keep[i] = false
        end
    end

    (c_ind[keep], c_off[keep])
end
