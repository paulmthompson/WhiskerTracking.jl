
export savitsky_golay, central_difference

#Polynomial smoothing with the Savitsky Golay filters
#
# Sources
# ---------
# Theory: http://www.ece.rutgers.edu/~orfanidi/intro2sp/orfanidis-i2sp.pdf
# Python Example: http://wiki.scipy.org/Cookbook/SavitzkyGolay
# Modified from https://github.com/BBN-Q/Qlab.jl/blob/master/src/SavitskyGolay.jl

#This can't handle NaNs or skipped data
function savitsky_golay(x::Vector, windowSize::Integer, polyOrder::Integer; deriv::Integer=0)

#Some error checking
    @assert isodd(windowSize) "Window size must be an odd integer."
    @assert polyOrder < windowSize "Polynomial order must me less than window size."

    halfWindow = round(Int64,(windowSize-1)/2)

    #Setup the S matrix of basis vectors.
    S = zeros(windowSize, polyOrder+1)
    for ct = 0:polyOrder
        S[:,ct+1] = collect(-halfWindow:halfWindow).^(ct)
    end

    #Compute the filter coefficients for all orders
    #From the scipy code it seems pinv(S) and taking rows should be enough
    G = S*pinv(S'*S)

    #Slice out the derivative order we want
    filterCoeffs = G[:,deriv+1] * factorial(deriv);


    #Pad the signal with the endpoints and convolve with filter
    paddedX = [x[1]*ones(halfWindow); x; x[end]*ones(halfWindow)]
    y = conv(filterCoeffs[end:-1:1], paddedX)

    #Return the valid midsection
    return y[2*halfWindow+1:end-2*halfWindow]

end

#=
Outlier removal
=#

function outlier_removal_min(cov1,min_ex,ind_range=(1,length(cov1)))

    cov2=cov1[ind_range[1]:ind_range[2]]

    outlier_inds=cov2 .< percentile(cov2,min_ex)

    itp_out = interpolate((find(.!outlier_inds),), cov2[.!outlier_inds], Gridded(Linear()))

    for i in find(outlier_inds)[2:(end-1)]
        cov2[i] = itp_out[i]
    end

    cov1[ind_range[1]:ind_range[2]]=cov2
    nothing
end

function outlier_removal_max(cov1,max_ex,ind_range=(1,length(cov1)))

    cov2=cov1[ind_range[1]:ind_range[2]]

    outlier_inds=cov2 .> percentile(cov2,max_ex)

    itp_out = interpolate((find(.!outlier_inds),), cov2[.!outlier_inds], Gridded(Linear()))

    for i in find(outlier_inds)[2:(end-1)]
        cov2[i] = itp_out[i]
    end

    cov1[ind_range[1]:ind_range[2]]=cov2
    nothing
end
function outlier_removal_twosided(cov1,min_ex,max_ex,ind_range=(1,length(cov1)))

    cov2=cov1[ind_range[1]:ind_range[2]]

    outlier_inds1=cov2 .< percentile(cov2,min_ex)
    outlier_inds2=cov2 .> percentile(cov2,max_ex)

    outlier_inds = outlier_inds1 .| outlier_inds2

    itp_out = interpolate((find(.!outlier_inds),), cov2[.!outlier_inds], Gridded(Linear()))

    for i in find(outlier_inds)[2:(end-1)]
        cov2[i] = itp_out[i]
    end

    cov1[ind_range[1]:ind_range[2]]=cov2
    nothing
end

#Central Differences
#=
One implementation only calculates if points are tracked on either side
=#

function central_difference(x)
    y=zeros(Float64,length(x))

    for i=2:length(y)-1
        y[i]=(x[i+1] - x[i-1]) / 2
    end
    y
end

function central_difference(x,tracked)
    y=zeros(Float64,length(x))
    diff_tracked=deepcopy(tracked)

    for i=2:length(y)-1
        if (tracked[i-1]&tracked[i+1])
            y[i]=(x[i+1] - x[i-1]) / 2
        else
            diff_tracked[i] = false
        end
    end

    tracked=diff_tracked

    y
end

function count_consecutive_bits(x,con_thres)
    interp_inds = Array{Int64,1}()

    i = 2
    while (i < (length(x)-con_thres))
        if !(x[i]) #false detected
            j = 1
            while (j<con_thres)
                if (x[i+j])

                    for k=1:j
                        push!(interp_inds,i+k)
                    end
                    break
                end
                j = j + 1
            end
            i = i+j
        else
            i = i+1
        end
    end

    interp_inds
end

function remove_two_sided_outlier(x,t,min_p,max_p)

    min_x = percentile(x[t],min_p)
    max_x = percentile(x[t],max_p)

    for i=1:length(t)

        if t[i]
            if (x[i]<min_x)|(x[i]>max_x)
                t[i] = false
            end
        end
    end
    nothing
end

function interpolate_forward(x,t,interp_ids)

    interp_x = interpolate((findall(t),),x[t],Gridded(Linear()))

    for i in interp_ids

        x[i] = interp_x(i)
    end
end

function reset_tracked(t,interp_ids)
   t[interp_ids] .= true
end

function interpolate_whisker(x,y)
   s=WhiskerTracking.total_length(x,y)

    s_i = zeros(Float64,length(x))
    for i=2:length(x)
       s_i[i]=WhiskerTracking.distance_along(x,y,i) + s_i[i-1]
    end

    itp_x = interpolate((s_i,), x, Gridded(Linear()));
    itp_y = interpolate((s_i,), y, Gridded(Linear()));

    out_s = s_i[2]:s

    x_out = zeros(Float64,length(out_s))
    y_out = zeros(Float64,length(out_s))

    for i=1:length(out_s)
       x_out[i] = itp_x(out_s[i])
        y_out[i] = itp_y(out_s[i])
    end
    (x_out,y_out)
end
