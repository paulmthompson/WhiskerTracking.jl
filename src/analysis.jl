
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
