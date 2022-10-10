
function extend_mask(mask,dist)

    w = size(mask,1)
    h = size(mask,2)

    out_mask = zeros(Float64,size(mask))

    for i=1:h
        for j=1:w
            if (out_mask[j,i] == 0.0)
                for ii = -dist:dist
                    if ((i + ii) > 0) && ((i + ii) <= h)
                        for jj = -dist:dist 
                            if ((j + jj) > 0) && ((j + jj) <= w)
                                if mask[j+jj,i+ii] == 1.0
                                    d = sqrt((jj)^2 + (ii)^2)
                                    if (d < dist)
                                        out_mask[j,i] = 1.0
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    out_mask
end

function load_mask_into_tracker(wt::Tracker,path::String,extend=30)
    wt.mask = load_mask_png(path)
    wt.extended_mask = extend_mask(wt.mask,extend)
    nothing
end

#=
Find first ind that is not masked in whisker
=#
function mask_tracked_whisker(w_x,w_y,wt::WhiskerTracking.Tracker,thres=30.0)

    out_ind = 1
    x_ind = round(Int,w_x[1])
    y_ind = round(Int,w_y[1])
    for i=1:length(w_x)
        x_ind = round(Int,w_x[i])
        y_ind = round(Int,w_y[i])
        if (!wt.extended_mask[y_ind,x_ind]) #Find first index without a mask
            out_ind = i
            break
        end
    end

    theta = atan(w_y[out_ind] - w_y[out_ind + 1],w_x[out_ind] - w_x[out_ind + 1])

    x = w_x[out_ind]
    y = w_y[out_ind]
    while (!wt.mask[y_ind,x_ind]) #loop until we hit fur

        x += cos(theta)
        y += sin(theta)

        x_ind = round(Int,x)
        y_ind = round(Int,y)
    end

    d = 0.0
    x_0 = x
    y_0 = y
    while (d < thres)
        x += cos(theta + pi)
        y += sin(theta + pi)

        d = sqrt((x - x_0)^2 + (y-y_0)^2)
    end

    (out_ind,x_0,y_0,x,y)
end