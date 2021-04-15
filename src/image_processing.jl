
function anisodiff(im,niter,kappa,lambda,option)
    diff=zeros(Float64,size(im))
    anisodiff!(im,niter,kappa,lambda,option,diff)
    diff
end

function anisodiff!(im::Array{Float64,2}, niter::Int64, kappa::Float64, lambda::Float64, option::Int64,dd=zeros(Float64,size(dd)))
#=
% Arguments:
%         im     - input image
%         niter  - number of iterations.
%         kappa  - conduction coefficient 20-100 ?
%         lambda - max value of .25 for stability
%         option - 1 Perona Malik diffusion equation No 1
%                  2 Perona Malik diffusion equation No 2
%
% Returns:
%         diff   - diffused image.
%
% kappa controls conduction as a function of gradient.  If kappa is low
% small intensity gradients are able to block conduction and hence diffusion
% across step edges.  A large value reduces the influence of intensity
% gradients on conduction.
%
% lambda controls speed of diffusion (you usually want it at a maximum of
% 0.25)
%
% Diffusion equation 1 favours high contrast edges over low contrast ones.
% Diffusion equation 2 favours wide regions over smaller ones.

% Reference:
% P. Perona and J. Malik.
% Scale-space and edge detection using ansotropic diffusion.
% IEEE Transactions on Pattern Analysis and Machine Intelligence,
% 12(7):629-639, July 1990.
%
% Peter Kovesi
% www.peterkovesi.com/matlabfns/
%
% June 2000  original version.
% March 2002 corrected diffusion eqn No 2.
=#

    (rows,cols) = size(dd);
    #rows=480
    #cols=640

    for i = 1:niter
        for j=1:length(im)
            dd[j]=im[j]
        end

        for k=1:cols
            for j=1:rows

                if j==1
                    deltaN = -1 * dd[j,k]
                else
                    @inbounds deltaN = dd[j-1,k] - dd[j,k]
                end

                if j==rows
                    deltaS = -1 * dd[j,k]
                else
                    @inbounds deltaS = dd[j+1,k] - dd[j,k]
                end

                if k==1
                    deltaW = -1 * dd[j,k]
                else
                    @inbounds deltaW = dd[j,k-1] - dd[j,k];
                end

                if k==cols
                    deltaE = -1 * dd[j,k]
                else
                    @inbounds deltaE = dd[j,k+1] - dd[j,k];
                end

                #if option == 1
                    cN = exp(-(deltaN/kappa)*(deltaN/kappa))
                    cS = exp(-(deltaS/kappa)*(deltaS/kappa))
                    cE = exp(-(deltaE/kappa)*(deltaE/kappa))
                    cW = exp(-(deltaW/kappa)*(deltaW/kappa))
                #else
                    #cN = 1/(1 + (deltaN/kappa)*(deltaN/kappa))
                    #cS = 1/(1 + (deltaS/kappa)*(deltaS/kappa))
                    #cE = 1/(1 + (deltaE/kappa)*(deltaE/kappa))
                    #cW = 1/(1 + (deltaW/kappa)*(deltaW/kappa))
                #end

                @inbounds im[j,k] = dd[j,k] + lambda*(cN*deltaN + cS*deltaS + cE*deltaE + cW*deltaW);
            end
        end
    end

    nothing
end

#The clahe method from Images is not optomized for iterations.
#Should make a new method that preallocates a temp array to be reused.
function local_contrast_enhance!(img,out_img)

    for i=1:length(img)
        out_img[i] = img[i]/255
    end

    img2 = Images.clahe(out_img,256,xblocks=30,yblocks=30,clip=15)

    for i=1:length(img2)
        out_img[i] = img2[i]*255
    end

    nothing
end

function local_contrast_enhance(img)

    img2 = img ./ 255

    img2 = Images.clahe(img2,256,xblocks=30,yblocks=30,clip=15) .* 255

    img2
end

function subtract_background(han::Tracker_Handles)

    mydiff = han.current_frame2 .- mean_image(han)
    new_diff = (mydiff - minimum(mydiff))
    new_diff = new_diff ./ maximum(new_diff)

    han.current_frame = round.(UInt8,new_diff .* 255)

    nothing
end

function sharpen_image(han::Tracker_Handles)
    han.current_frame = sharpen_image(han.current_frame)
    nothing
end

function sharpen_image(img::Array{UInt8,2}) where T
    imgl = imfilter(img, Kernel.Laplacian());
    newimg= imgl .- minimum(imgl)
    newimg = newimg ./ maximum(newimg)
    255 .- round.(UInt8,newimg .* 255)
end

function adjust_contrast(img::Array{T,2},min_c::Real,max_c::Real) where T

    out_max = 255
    out_min = 0

    out_min_rel = min_c / out_max
    out_max_rel = max_c / out_max
    out_range_f = (max_c - min_c) / (out_max - out_min)

    for i=1:length(img)

        inten = img[i] / 255 #normalize to float of intensity

        inten = inten - out_min_rel # remove bottom
        if inten < 0.0
            inten = 0.0
        end

        inten = inten / out_range_f

        if inten > 1.0
            inten = 1.0
        end

        img[i] = round(T,inten * out_max)
    end

    nothing
end
