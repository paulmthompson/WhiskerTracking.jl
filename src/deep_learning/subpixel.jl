#=
Modified from SubpixelRegistration.jl
https://github.com/romainFr/SubpixelRegistration.jl
Copyright (c) 2016: Romain Franconville.
Under MIT "Expat" License

Original Publication:

=#

function subpixel(imgRef::AbstractArray{T,N},imgF::AbstractArray{T,N},usfac) where {T,N}

    if usfac==1
        ## Whole-pixel shift - Compute crosscorrelation by an IFFT and locate the peak
        L = length(imgRef)
        CC = ifft(imgRef.*conj(imgF))
        loc = argmax(abs.(CC))
        CCmax=CC[loc]

        indi = size(imgRef)
        ind2 = tuple([div(x,2) for x in indi]...)

        #locI = [ind2sub(indi,loc)...]
        locI = [Tuple(loc)...]

        shift = zeros(size(locI))
        for i in eachindex(locI)
            if locI[i]>ind2[i]
                shift[i]=locI[i]-indi[i]-1
            else shift[i]=locI[i]-1
            end
        end

        shift
    else
        ## Partial pixel shift

        ##First upsample by a factor of 2 to obtain initial estimate
        ##Embed Fourier data in a 2x larger array
        dimR = [size(imgRef)...]
        ranges = [(x+1-div(x,2)):(x+1+div(x-1,2)) for x in dimR]
        dimRL = map(x -> x*2, dimR)
        CC = zeros(Complex{Float32},tuple(dimRL...))
        #CC = convert(CuArray,CC)
        CC[ranges...] = fftshift(imgRef).*conj(fftshift(imgF))

        ##  Compute crosscorrelation and locate the peak
        CC = ifft(ifftshift(CC))
        loc = argmax(abs.(CC))

        indi = size(CC)
        #locI = [ind2sub(indi,loc)...]
        locI = [Tuple(loc)...]
        CCmax = CC[loc]
        ## Obtain shift in original pixel grid from the position of the crosscorrelation peak

        ind2 = tuple([div(x,2) for x in indi]...)

        shift = zeros(size(locI))
        for i in eachindex(locI)
            if locI[i]>ind2[i]
                shift[i]=locI[i]-indi[i]-1
            else shift[i]=locI[i]-1
            end
        end
        shift = shift/2

        ## If upsampling > 2, then refine estimate with matrix multiply DFT
        if usfac > 2
            ### DFT Computation ###
            # Initial shift estimate in upsampled grid
            shift = round.(Integer,shift*usfac)/usfac
            dftShift = div(ceil(usfac*1.5),2) ## center of output array at dftshift+1
            ## Matrix multiplies DFT around the current shift estimate
            CC = conj(dftups(imgF.*conj(imgRef),ceil(Integer,usfac*1.5),usfac,dftShift.-shift*usfac))/(prod(ind2)*usfac^2)
            ## Locate maximum and map back to original pixel grid
            loc = argmax(abs.(CC))

            locI = Tuple(loc)
            CCmax = CC[loc]
            locI = map((x) -> x - dftShift - 1,locI)

            for i in eachindex(shift)
                shift[i]=shift[i]+locI[i]/usfac
            end
        end
        ## If its only one row or column the shift along that dimension has no effect. Set to zero.
        shift[[div(x,2) for x in size(imgRef)].==1].=0
    end
    reverse(shift)
end

function dftups(inp::AbstractArray{T,N},no,usfac::Int=1,offset=zeros(N)) where {T,N}
    sz = [size(inp)...]
    permV = 1:N
    for i in permV
        inp = permutedims(inp,[i;deleteat!(collect(permV),i)])
        kern = exp.(Complex{Float32}(-1im*2*pi/(sz[i]*usfac))*((0:(no-1)).-offset[i])*transpose(ifftshift(0:(sz[i]-1)).-floor(sz[i]/2)))
        #kern = convert(CuArray{Complex{Float32}},kern)
        d = size(inp)[2:N]
        inp = kern * reshape(inp, Val(2))
        inp = reshape(inp,(no,d...))
    end
    permutedims(inp,collect(ndims(inp):-1:1))
end
