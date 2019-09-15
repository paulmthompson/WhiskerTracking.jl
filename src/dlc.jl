
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

function dlc_change_num_segments(dlc::DLC_Wrapper,num,pole=true)
        whisker_body_parts=[string(i) for i=1:num]
    if pole
        push!(whisker_body_parts,"Pole")
    end
    dlc_py[:change_dlc_yaml](dlc.config_path,"bodyparts",whisker_body_parts)
end

function dlc_create_label_file(dlc::DLC_Wrapper,label_path)
    dlc_py[:create_label_hdf5](dlc.config_path,label_path)
end

function dlc_extra_pole_location(han)
    #pole_tracker_config = "/home/wanglab/Documents/Analysis_Scripts/DeepLabCut/Pole Detection-PMT-2019-03-22/config.yaml"
    pole_tracker_config = "C:\\Users\\pmt11\\Desktop\\Pole-Detection-PMT-2019-03-22\\config.yaml"

    vid_path = string(han.paths.temp,"/pole_vid.mp4")

    #Only Unix can glob
    data_path_pole = string(han.paths.images,"/*.png")
    run(`$(ffmpeg_path) -r 1 -pattern_type glob -i $(data_path_pole) -vcodec libx264 -pix_fmt yuv420p $(vid_path)`)

    dlc_module[:analyze_videos](pole_tracker_config,[vid_path],shuffle=1,save_as_csv=false,videotype=".mp4")

    myfiles=readdir(han.paths.temp)
    pole_path=string(han.paths.temp,"/",myfiles[find([endswith(i, ".h5") for i in myfiles])[1]])

    pole_pos=WhiskerTracking.read_pole_hdf5(pole_path)

    for i in myfiles
        rm(string(han.paths.temp,"/",i))
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
Interpolate between DLC points for array of whiskers
w_x_in and w_y_in are both 2D arrays of points
l is the liklihood for each point
inds is the range of indexes to interpolate between
interp_res is the desired interpixel distance for interpolation
=#
function interpolate_dlc(w_x_in,w_y_in,l,inds,interp_res)

    #Interpolate DLC points and generate line of values spaced 1 unit apart (for better visualization)
    wx=[Array{Float64,1}() for i=1:size(w_x_in,2)]
    wy=[Array{Float64,1}() for i=1:size(w_x_in,2)]
    tracked=trues(size(w_x_in,2))

    for i=1:size(w_x_in,2)
        if (sum(l[:,i])>2)&((i>=inds[1])&(i<=inds[2])) #Need to have at least 3 points with super-threshold liklihood to be worth fitting
            (wx[i],wy[i]) = get_woi_x_y(w_x_in[l[:,i],i],w_y_in[l[:,i],i],interp_res)
        else
            tracked[i]=false
        end
    end

    #Now remove any fits that appear to be very bad (high SNR region moves beyond some threshold)
    #dlc_remove_bad_whiskers(wx,wy,bad_whisker_thres,tracked)

    (wx,wy,tracked)
end

#=
Take discrete points along the whisker and interpolate between with 1.0 pixel spacing
=#
function get_woi_x_y(w_x,w_y,interp_res,follicle=(400.0f0,50.0f0))

    my_range = zeros(Float64,length(w_x))
    for i=2:length(my_range)
        my_range[i] = sqrt((w_x[i]-w_x[i-1])^2 + (w_y[i]-w_y[i-1])^2) + my_range[i-1]
    end
    t = my_range

    itp_xx=sp.interpolate.PchipInterpolator(t,w_x)
    itp_yy=sp.interpolate.PchipInterpolator(t,w_y)

    #Make sure the correct side (end of array) is near the follicle
    dist_1=sqrt((w_x[1]-follicle[1])^2+(w_y[1]-follicle[2])^2)
    dist_2=sqrt((w_x[end]-follicle[1])^2+(w_y[end]-follicle[2])^2)

    if dist_1 > dist_2
        new_t=0.0:interp_res:my_range[end]
    else
        new_t=my_range[end]:(-1*interp_res):0.0
    end

    xx=itp_xx(new_t)
    yy=itp_yy(new_t)

    (xx,yy)
end

allequal_1(x) = all(y->y==x[1],x)
