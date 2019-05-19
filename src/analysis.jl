
#=
Finds the phase over time for a given angle vs time array
using the Hilbert Transform

Kleinfeld and Deschenes 2011
=#
function get_phase(aa)
    responsetype = Bandpass(8.0,30.0; fs=500.0)
    designmethod=Butterworth(4)
    df1=digitalfilter(responsetype,designmethod)
    myfilter=DF2TFilter(df1)
    filter_aa=filt(myfilter,aa) #filtfilt?

    hh=hilbert(filter_aa)

    angle.(hh)
end

#Polynomial smoothing with the Savitsky Golay filters
#
# Sources
# ---------
# Theory: http://www.ece.rutgers.edu/~orfanidi/intro2sp/orfanidis-i2sp.pdf
# Python Example: http://wiki.scipy.org/Cookbook/SavitzkyGolay
# Modified from https://github.com/BBN-Q/Qlab.jl/blob/master/src/SavitskyGolay.jl
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

#Detect Contact Position
#=
if contact has been detected, find the most likely point of contact by minimizing the distance between the pole
and whisker position

w = array of whiskers
contact = array of booleans indicating if contact occured in this frame (true)

i_c = index (in whisker x y points) of contact
xy_c = Tuple of x,y coordinates of contact point

function find_contact_position(w,contact)

    i_c = zeros(Int64,length(w))
    xy_c = [(0.0,0.0) for i=1:length(w)]
    for i=1:length(w)
        if contact[i]



        end
    end

end

=#

#=
Calculate Forces





=#
