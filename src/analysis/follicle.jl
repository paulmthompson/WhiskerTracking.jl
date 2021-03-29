
function get_follicle_from_whisker(x,ind=1)
   x_f = zeros(Float64,length(x))

   for i=1:length(x)
        try
           x_f[i] = x[i][ind]
        catch
            x_f[i] = NaN
        end
    end
    x_f
end

#=
Going to start with 1 as nearest follicle (this is OPPOSITE of janelia)
=#
function correct_follicle(x::Array{T,1},y::Array{T,1},x_f,y_f) where T
    d1 = sqrt((x[1]-x_f)^2 + (y[1]-y_f)^2)
    d2 = sqrt((x[end]-x_f)^2 + (y[end]-y_f)^2)

    if d2 < d1
        reverse!(x)
        reverse!(y)
    end
    nothing
end
