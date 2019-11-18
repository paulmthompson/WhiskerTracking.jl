


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

function change_discrete_size(wt::Tracker,new_size)

    num_points = div(size(wt.w_p,1),2)

    if new_size > num_points

        new_p_array=zeros(Float32,new_size*2,size(wt.w_p,2))

        for i=1:size(wt.w_p,1),j=1:size(wt.w_p,2)
            new_p_array[i,j] = wt.w_p[i,j]
        end

        wt.w_p=new_p_array

    elseif new_size < num_points

        new_p_array=zeros(Float32,new_size*2,size(wt.w_p,2))

        for i=1:size(new_p_array,1),j=1:size(wt.w_p,2)
            new_p_array[i,j] = wt.w_p[i,j]
        end

        wt.w_p=new_p_array
    else

    end

    nothing
end

#=
Go through all loaded frames and discretize the whisker of interest
=#

function make_discrete_woi(wt,woi,tracked,spacing)

    for i=1:length(woi)

        if tracked[i]

            make_discrete(wt.w_p,i,woi[i],spacing)
        end
    end

    nothing
end

function draw_discrete(han::Tracker_Handles)

    circ_rad=5.0

    ctx=Gtk.getgc(han.c)
    set_source_rgb(ctx,0,1,0)
    num_points = div(size(han.wt.w_p,1),2)

    for i=1:num_points
        arc(ctx, han.wt.w_p[i*2-1,han.frame],han.wt.w_p[i*2,han.frame], circ_rad, 0, 2*pi);
        stroke(ctx);
    end


    nothing

end

function add_discrete_point(han::Tracker_Handles,x,y)

    num_points = div(size(han.wt.w_p,1),2)
    ss=han.d_spacing

    last_point=1

    loc_x=zeros(Float64,num_points)
    loc_y=zeros(Float64,num_points)
    point_exists=falses(num_points)
    for i=1:num_points

        if han.wt.w_p[i*2-1,han.frame] != 0.0
            loc_x[i]=han.wt.w_p[i*2-1,han.frame]
            loc_y[i]=han.wt.w_p[i*2,han.frame]
            point_exists[i] = true
            last_point = i
        end
    end

    if last_point < num_points

        total_dist=0.0
        for i=2:last_point
            total_dist += sqrt((loc_x[i]-loc_x[i-1])^2 + (loc_y[i]-loc_y[i-1])^2)
        end

        true_dist=sqrt((x - loc_x[last_point])^2 + (y-loc_y[last_point])^2)

        pos_vals=((last_point+1):(num_points))*ss

        j=argmin(abs.(pos_vals .- true_dist))

        han.wt.w_p[(last_point+j)*2-1,han.frame] = x
        han.wt.w_p[(last_point+j)*2,han.frame] = y
    end

    nothing
end
