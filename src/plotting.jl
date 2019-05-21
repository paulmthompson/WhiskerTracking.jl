(myfig,myax)=subplots(1,1)
vid_name=string(data_path,"output.mp4")

#w_ids=10485:10595
w_ids=17260:17360
outframes=zeros(UInt8,480,640,length(w_ids))

t_ind=(w_ids[1]-1)/25
xx=open(`$(WhiskerTracking.ffmpeg_path) -ss $(t_ind) -i $(vid_name) -f image2pipe -vcodec rawvideo -pix_fmt gray -`);
temp=zeros(UInt8,640,480)
for i=1:length(w_ids)
    read!(xx[1],temp)
    outframes[:,:,i]=temp'
    outframes[:,:,i]=flipdim(outframes[:,:,i],1)
end

close(xx[1])

mkdir("video_data")
frame_id=1
for w_id=w_ids

    myax[:scatter](p_pos[w_id,1],480-p_pos[w_id,2])
    myax[:plot](wx[w_id],480-wy[w_id])
    myax[:set_xlim]([1,640])
    myax[:set_ylim]([1,480])
    myax[:imshow](outframes[:,:,frame_id],cmap="gray")
    myax[:set_xticks]([])
    myax[:set_yticks]([])
    if contact[w_id]
        ii=WhiskerTracking.calc_p_dist(wx[w_id],wy[w_id],p_pos[w_id,1],p_pos[w_id,2])[2]
        myax[:scatter](wx[w_id][ii],480-wy[w_id][ii])

        #Lateral Force
        F_lat_x = F_y[w_id] * cosd(-1*(myangles[w_id]-90.0))
        F_lat_y = F_y[w_id] * sind(-1*(myangles[w_id]-90.0))
        myax[:quiver](wx[w_id][end], 480-wy[w_id][end],F_lat_x * 0.5e7,F_lat_y * 0.5e7,
            width=0.005,color="red",angles="xy",scale_units="xy",scale=1)

        #Axial Force
        F_axial_x = F_y[w_id] * cosd(180.0-myangles[w_id])
        F_axial_y = F_y[w_id] * sind(180.0-myangles[w_id])
        myax[:quiver](wx[w_id][end], 480-wy[w_id][end],F_axial_x * 0.5e7,F_axial_y * 0.5e7,
            width=0.005,color="red",angles="xy",scale_units="xy",scale=1)

        myax[:quiver](wx[w_id][ii],480-wy[w_id][ii],F_t[w_id]*cos(theta_c[w_id])*0.5e7,F_t[w_id]*sin(theta_c[w_id])*0.5e7,width=0.005,color="red",angles="xy",scale_units="xy",scale=1)
    end

    savefig(string("video_data/",frame_id))
    frame_id+=1
    myax[:clear]()
end
