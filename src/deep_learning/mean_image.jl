
function mean_std_video_gpu(han::Tracker_Handles,total_frame_num)
    mean_std_video_gpu(han.wt.vid_name,total_frame_num)
end

function mean_std_video_gpu(vid_name::String,total_frame_num,max_intensity=255,loading_size=500)

    (w,h,fps)=get_vid_dims(vid_name)
    start_frame = 0

    load_number = div(total_frame_num - start_frame, loading_size)-1

    temp_frames=zeros(UInt8,w,h,loading_size)

    temp_frames2 = convert(KnetArray,zeros(Float32,w,h,loading_size))

    running_mean = convert(KnetArray,zeros(Float32,w,h,1))
    running_mean_i = convert(KnetArray,zeros(Float32,w,h,1))

    running_std = convert(KnetArray,zeros(Float32,w,h,1))
    running_std_i = convert(KnetArray,zeros(Float32,w,h,1))

    @ffmpeg_env run(WhiskerTracking.ffmpeg_cmd(start_frame / fps,vid_name,loading_size,"test5.yuv"))
    read!("test5.yuv",temp_frames)

    temp_frames2[:]=convert(KnetArray{Float32,3},temp_frames)
    running_mean_i[:,:,1] = mean(temp_frames2,dims=3) ./ max_intensity

    for i=1:load_number
        @ffmpeg_env run(WhiskerTracking.ffmpeg_cmd((i*loading_size + start_frame)/ fps,vid_name,loading_size,"test5.yuv"))
        read!("test5.yuv",temp_frames)
        temp_frames2[:]=convert(KnetArray{Float32,3},temp_frames)

        x_k = mean(temp_frames2,dims=3) ./ max_intensity

        running_mean = running_mean_i .+ (x_k .- running_mean_i) ./ (i+1)

        running_std = running_std_i .+ (x_k .- running_mean_i).*(x_k - running_mean)

        running_mean_i = running_mean
        running_std_i = running_std
    end

    rm("test5.yuv")

    (convert(Array,running_mean), convert(Array,running_std))
end
