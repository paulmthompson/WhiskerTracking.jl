
function dlc_remove_bad_whiskers(xx,yy,thres)

    tracked=trues(length(xx))
    remove_bad_whiskers(xx,yy,thres,tracked)
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
