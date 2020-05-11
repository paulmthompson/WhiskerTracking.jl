
function w_plot_image(ax,frame_array,f_id)

    ax[:set_xlim]([1,640])
    ax[:set_ylim]([1,480])
    ax[:imshow](frame_array[:,:,f_id],cmap="gray",vmin=0,vmax=130)
    ax[:set_xticks]([])
    ax[:set_yticks]([])

    nothing
end

#=
Draw interpolated whisker from DLC points on currently displayed frame
=#
function draw_tracked_whisker(han::Tracker_Handles)
    ctx=Gtk.getgc(han.c)

    ii=han.displayed_frame+1

    w_x = han.tracked_whiskers_x[han.tracked_whiskers_l[:,ii],ii]
    w_y = han.tracked_whiskers_y[han.tracked_whiskers_l[:,ii],ii]

    my_range = zeros(Float64,length(w_x))
    for i=2:length(my_range)
        my_range[i] = sqrt((w_x[i]-w_x[i-1])^2 + (w_y[i]-w_y[i-1])^2) + my_range[i-1]
    end
    t = my_range

    itp_xx=sp.interpolate.PchipInterpolator(t,w_x)
    itp_yy=sp.interpolate.PchipInterpolator(t,w_y)

    new_t=0.0:1.0:my_range[end]

    new_x=itp_xx(new_t)
    new_y=itp_yy(new_t)

    set_source_rgb(ctx,1,0,0)
    move_to(ctx,new_x[1],new_y[1])
    for i=2:length(new_t)
        line_to(ctx,new_x[i],new_y[i])
    end
    stroke(ctx)

     for i=1:length(w_x)
        move_to(ctx,w_x[i],w_y[i])
        arc(ctx, w_x[i],w_y[i], 5, 0, 2*pi);
        stroke(ctx);
    end

    if han.show_contact

        #Draw Pole
        if han.tracked_contact[ii] #Contact Present
            set_source_rgb(ctx,0,1,1)
        else
            set_source_rgb(ctx,0,0,1)
        end
        move_to(ctx,han.tracked_pole[ii,1],han.tracked_pole[ii,2])
        arc(ctx,han.tracked_pole[ii,1],han.tracked_pole[ii,2],5,0,2*pi)
        stroke(ctx)
    end

    reveal(han.c)
end
