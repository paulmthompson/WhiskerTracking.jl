
export fit_poly_to_dlc

#=
Initialization Methods
=#

function dlc_init(dlc::DLC_Wrapper,vid_name,vid_path)
    dlc.config_path=dlc_module[:create_new_project](vid_name,"PMT",[vid_path],copy_videos=false)
end

function dlc_extract_frames(dlc::DLC_Wrapper)
    dlc_module[:extract_frames](dlc.config_path,"automatic","kmeans",userfeedback=false)
end

function dlc_change_num_segments(dlc::DLC_Wrapper,num)
    whisker_body_parts=[string(i) for i=1:num]
    dlc_py[:change_dlc_yaml](dlc.config_path,"bodyparts",whisker_body_parts)
end

function dlc_extra_pole_location(data_path)
    pole_tracker_config = "/home/wanglab/Documents/Analysis_Scripts/DeepLabCut/Pole Detection-PMT-2019-03-22/config.yaml"

    #make temp directory
    try mkdir("./temp")
    catch
    end

    data_path_pole = string(data_path,"*.png")

    run(`$(ffmpeg_path) -r 1 -pattern_type glob -i $(data_path_pole) -vcodec libx264 -pix_fmt yuv420p ./temp/pole_vid.mp4`)

    dlc_module[:analyze_videos](pole_tracker_config,["./temp/pole_vid.mp4"],shuffle=1,save_as_csv=false,videotype=".mp4")

    myfiles=readdir("./temp")
    pole_path=string("./temp/",myfiles[find([endswith(i, ".h5") for i in myfiles])[1]])

    pole_pos=WhiskerTracking.read_pole_hdf5(pole_path)

    for i in myfiles
        rm(string("./temp/",i))
    end

    pole_pos
end

#=
When we load the DLC data, we try to remove outlier points by using the confidence of the estimate
and the movement of individual points from some smoothed average.
One final check for noisey estimates here is to make sure that the segment that is supposed to be high signal to
noise for the purpose of force calculation (here defined as being 30 to 80 units of distance from
the follicle base) is relatively stable.

=#

function dlc_remove_bad_whiskers(xx,yy,thres)

    tracked=trues(length(xx))
    remove_bad_whiskers(xx,yy,thres,tracked)
    tracked
end

function dlc_remove_bad_whiskers(xx,yy,thres,tracked)

    dx=zeros(Float64,length(xx),2)
    dy=zeros(Float64,length(xx),2)
    smooth_dx=zeros(Float64,length(xx),2)
    smooth_dy=zeros(Float64,length(xx),2)

    for i=1:length(xx)
        if length(xx[i])>2
            i_p1=WhiskerTracking.culm_dist(xx[i],yy[i],30.0)
            i_p2=WhiskerTracking.culm_dist(xx[i],yy[i],80.0)

            dx[i,1]=xx[i][i_p1]
            dx[i,2]=xx[i][i_p2]
            dy[i,1]=xx[i][i_p1]
            dy[i,2]=xx[i][i_p2]
        end
    end

    smooth_dx[:,1]=WhiskerTracking.smooth(dx[:,1],15)
    smooth_dx[:,2]=WhiskerTracking.smooth(dx[:,2],15)
    smooth_dy[:,1]=WhiskerTracking.smooth(dy[:,1],15)
    smooth_dy[:,2]=WhiskerTracking.smooth(dy[:,2],15)

    for i=1:length(xx)

        dist1=sqrt((smooth_dx[i,1]-dx[i,1])^2+(smooth_dy[i,1]-dy[i,1])^2)
        dist2=sqrt((smooth_dx[i,2]-dx[i,2])^2+(smooth_dy[i,2]-dy[i,2])^2)

        if (dist1>thres)|(dist2>thres)
            tracked[i]=false
        end
    end

    nothing
end

#=
Fit polynomial to points to get whisker traces

=#

function fit_poly_to_dlc(whiskers,tracked,bad_whisker_thres=40.0)
    #Fit polynomial to DLC points and generate line of values spaced 1 unit apart (for better visualization)
    wx=[Array{Float64}(0) for i=1:length(whiskers)]
    wy=[Array{Float64}(0) for i=1:length(whiskers)]

    for i=1:length(whiskers)
        if length(whiskers[i].x)>2
            (wx[i],wy[i]) = get_woi_x_y(whiskers,i)
        end
    end

    #Now remove any fits that appear to be very bad (high SNR region moves beyond some threshold)
    dlc_remove_bad_whiskers(wx,wy,bad_whisker_thres,tracked)

    (wx,wy)
end


function get_woi_x_y(w,w_id,follicle=(400.0f0,50.0f0))

    #We need to center the follicle on 0,0 for good fitting
    cent_x=w[w_id].x[end]
    cent_y=w[w_id].y[end]

    #Determine the best axis for whisker fitting by calculating a vector from follicle to tip
    v_x=w[w_id].x[1]-w[w_id].x[end]
    v_y=w[w_id].y[1]-w[w_id].y[end]

    skip=false

    if allequal_1(sign.(diff(w[w_id].y))) #Check if y dimension is monotonically increasing or decreasing

        #3rd order polynomial fit

        if length(w[w_id].y)>3
            mypoly=polyfit(w[w_id].y-cent_y,w[w_id].x-cent_x,3)
        elseif length(w[w_id].y)>2
            mypoly=polyfit(w[w_id].y-cent_y,w[w_id].x-cent_x,2)
        else
            skip=true
        end

        if skip
            yy=w[w_id].y
            xx=w[w_id].x
        else
            if w[w_id].y[1]<w[w_id].y[end]
                yy = collect(w[w_id].y[1]:w[w_id].y[end])
            else
                yy = collect(w[w_id].y[end]:w[w_id].y[1])
            end
            xx=mypoly(yy-cent_y)+cent_x
        end

    else

        #3rd order polynomial fit
        if length(w[w_id].x)>3
            mypoly=polyfit(w[w_id].x-cent_x,w[w_id].y-cent_y,3)
        elseif length(w[w_id].x)>2
            mypoly=polyfit(w[w_id].x-cent_x,w[w_id].y-cent_y,2)
        else
            skip=true
        end

        if skip
            yy=w[w_id].y
            xx=w[w_id].x
        else
            if w[w_id].x[1]<w[w_id].x[end]
                xx = collect(w[w_id].x[1]:w[w_id].x[end])
            else
                xx = collect(w[w_id].x[end]:w[w_id].x[1])
            end
            yy=mypoly(xx-cent_x)+cent_y
        end
    end

    #Flip to make sure the right side is near the follicle

    dist_1=sqrt((xx[1]-follicle[1])^2+(yy[1]-follicle[2])^2)
    dist_2=sqrt((xx[end]-follicle[1])^2+(yy[end]-follicle[2])^2)

    if dist_1 < dist_2
        reverse!(xx)
        reverse!(yy)
    end

    (xx,yy)
end

allequal_1(x) = all(y->y==x[1],x)
