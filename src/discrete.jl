


#=
Takes a smooth janelia traced whisker, and generateds a set of discrete points
along the whisker of equal spacing
=#
function make_discrete(p_array::Array{Float32,2},ind,w::Whisker1,spacing)

    p_array[1,ind] = w.x[end]
    p_array[2,ind] = w.y[end]

    num_points=div(size(p_array,1),2)

    for i=2:num_points

        id=culm_dist(w.x,w.y,spacing*(i-1))
        if id != 1
            p_array[(i*2) - 1,ind] = w.x[id]
            p_array[(i*2),ind] = w.y[id]
        else
            break
        end
    end

    nothing
end

function make_woi_discrete(woi,num_points,spacing)

    d_points = zeros(Float32,num_points,2,length(woi))

    for i=1:length(woi)
        for j=1:num_points
            id=culm_dist(woi[i].x,woi[i].y,spacing*(j-1))
            if id != 1
                d_points[j,1,i] = woi[i].x[id]
                d_points[j,2,i] = woi[i].y[id]
            end
        end
    end

    d_points
end

#=
Go through all loaded frames and discretize the whisker of interest
=#

function make_discrete_woi(wt,woi,tracked,spacing)

    for i=1:length(woi)

        if tracked[i]
            #make_discrete(wt.w_p,i,woi[i],spacing)
        end
    end

    nothing
end

function make_discrete_all_whiskers(han::Tracker_Handles,spacing=15.0)
    woi=get_woi_array(han)
    make_discrete_all_whiskers(woi,han.wt.pad_pos,spacing)
end

function make_discrete_all_whiskers(woi,pad_pos,spacing=15.0)

    #Make sure that whiskers are ordered with follicle at base
    WT_reorder_whisker(woi,pad_pos)

    #Find longest whisker
    (d_longest,dl_i)=longest_whisker(woi)

    num_points = round(Int,div(d_longest, spacing))

    #Divide into x points
    d_points=make_woi_discrete(woi,num_points,spacing)
end

function longest_whisker(woi)

    d_longest=0.0
    dl_i=1;
    for i=1:length(woi)
        d=0.0
        w=woi[i]
        for j=2:length(w.x)
            d += sqrt((w.x[j]-w.x[j-1])^2 + (w.y[j]-w.y[j-1])^2)
        end

        if d > d_longest
            d_longest = d
            dl_i = i
        end
    end
    (d_longest, dl_i)
end

function draw_discrete(han::Tracker_Handles)

    x1 = han.woi[han.displayed_frame].x
    y1 = han.woi[han.displayed_frame].y

    w_length = total_length(x1,y1)
    d_vec=range(0.1,0.9,step=0.02)

    (w1_theta,w1_theta_absolute,last_ind) = convert_to_angular_coordinates(x1,y1,d_vec.*w_length)

    ctx=Gtk.getgc(han.c)

    (x_p2,y_p2) = get_ind_at_dist_exact(x1,y1,(d_vec.*w_length)[1])
    draw_discrete(ctx,w1_theta_absolute,d_vec.*w_length,(x_p2,y_p2))

    nothing
end

function draw_discrete(ctx,theta,l,origin = (0.0,0.0))

    (x1,y1) = origin
    x2 = 0.0
    y2 = 0.0
    
    t_length = 0.0
    
    circ_rad=5.0

    for i=2:length(theta)
        y2 = sin(theta[i])*(l[i]-l[i-1]) + y1
        x2 = cos(theta[i])*(l[i]-l[i-1]) + x1

        arc(ctx, x2,y2, circ_rad, 0, 2*pi);
        stroke(ctx);
        
        t_length += sqrt((x2-x1)^2+(y2-y1)^2)
        y1 = y2
        x1 = x2
    end
    println(t_length)

end