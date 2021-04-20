
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
function correct_follicle(x::Array{T,1},y::Array{T,1},x_f::Real,y_f::Real) where T
    d1 = sqrt((x[1]-x_f)^2 + (y[1]-y_f)^2)
    d2 = sqrt((x[end]-x_f)^2 + (y[end]-y_f)^2)

    if d2 < d1
        reverse!(x)
        reverse!(y)
    end
    nothing
end

function correct_follicle_all(xx::Array,yy::Array,x_f::Real,y_f::Real)

    for i=1:length(xx)
        try
            correct_follicle(xx[i],yy[i],x_f,y_f)
        catch
        end
    end
end
