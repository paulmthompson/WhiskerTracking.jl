
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

    outlier_inds=cov2.<percentile(cov2,min_ex)

    itp_out = interpolate((find(.!outlier_inds),), cov2[.!outlier_inds], Gridded(Linear()))

    for i in find(outlier_inds)[2:(end-1)]
        cov2[i] = itp_out[i]
    end

    cov1[ind_range[1]:ind_range[2]]=cov2
    nothing
end

function outlier_removal_max(cov1,max_ex,ind_range=(1,length(cov1)))

    cov2=cov1[ind_range[1]:ind_range[2]]

    outlier_inds=cov2.>percentile(cov2,max_ex)

    itp_out = interpolate((find(.!outlier_inds),), cov2[.!outlier_inds], Gridded(Linear()))

    for i in find(outlier_inds)[2:(end-1)]
        cov2[i] = itp_out[i]
    end

    cov1[ind_range[1]:ind_range[2]]=cov2
    nothing
end
function outlier_removal_twosided(cov1,min_ex,max_ex,ind_range=(1,length(cov1)))

    cov2=cov1[ind_range[1]:ind_range[2]]

    outlier_inds1=cov2.<percentile(cov2,min_ex)
    outlier_inds2=cov2.>percentile(cov2,max_ex)

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
