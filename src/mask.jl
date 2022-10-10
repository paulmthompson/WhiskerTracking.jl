
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