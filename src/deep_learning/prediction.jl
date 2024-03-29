
function calculate_whisker_fit(pred_1::AbstractArray{T,2},img::AbstractArray{N,2}) where {T,N}

    calculate_whisker_fit(pred_1,size(img))
end

function calculate_whisker_fit(pred_1::AbstractArray{T,2},sz::Tuple,n_points_max=100) where T

    (rot_angle, loss) = quick_quad(pred_1)

    upsampled = StackedHourglass.upsample_pyramid(pred_1,sz)

    (x,y,conf) = get_points(upsampled)

    x = convert(Array{Float64,1},x)
    y = convert(Array{Float64,1},y)

    calculate_whisker_fit(x,y,conf,n_points_max,rot_angle)
end

function get_points(input::AbstractArray{T,2},conf_thres=0.5) where T
    input_s = input./maximum(input)
    points_1 = findall(input_s .> conf_thres)
    x = [points_1[i][1] for i=1:length(points_1)]
    y = [points_1[i][2] for i=1:length(points_1)]
    conf = input_s[points_1]
    (x,y,conf)
end

function quick_quad(pred::AbstractArray{T,2},angles=0.0:pi/12:pi) where T

    inds = findall(pred .> 0.1)

    x = zeros(Float64,length(inds))
    y = zeros(Float64,length(inds))

    for i=1:length(inds)
        x[i] = inds[i][1]
        y[i] = inds[i][2]
    end

    quick_quad(x,y,angles)
end

function quick_quad(x::AbstractArray{T,1},y::AbstractArray{T,1},angles=0.0:pi/12:pi) where T

    x_prime = zeros(Float64,length(x))
    y_prime = zeros(Float64,length(y))

    quad_mat = ones(Float64,length(x),3)

    losses = zeros(Float64,length(angles))

    for i = 1:length(angles)

        rotate_mat(x,y,x_prime,y_prime,angles[i])

        for j=1:length(x_prime)
            quad_mat[j,1] = x_prime[j]
            quad_mat[j,2] = x_prime[j] * x_prime[j]
        end
        out = quad_mat \ y_prime

        losses[i] = mean(((quad_mat * out) .- y_prime).^2)
    end

    (angles[findmin(losses)[2]],minimum(losses))
end

function calculate_whisker_fit(x::AbstractArray{T,1},y::AbstractArray{T,1},conf::AbstractArray{N,1},
    n_points_max=100,rot_angle=0.0) where {T,N}

    rotate_mat!(x,y,rot_angle)
    (new_x, new_y) = center_of_mass(x,y,conf,n_points_max)
    rotate_mat!(new_x,new_y,-1 * rot_angle)
    (new_x,new_y)
end

#=

=#
function center_of_mass(x::AbstractArray{T,1},y::AbstractArray{T,1},conf::AbstractArray{N,1},n_points_max=100) where {T,N}
    x_sort=sortperm(x)
    sorted_x=sort(x)
    sorted_y = y[x_sort]
    sorted_conf = conf[x_sort]

    out_length = round(Int64,sorted_x[end] - sorted_x[1])

    if out_length > n_points_max
        out_length = n_points_max
    end

    myedges = range(sorted_x[1],stop=sorted_x[end],length=out_length)

    out_x = zeros(Float64,length(myedges)-1)
    out_y = zeros(Float64,length(myedges)-1)
    out_weights = zeros(Float64,length(myedges)-1)

    start_ind = 1

    for i=1:(length(myedges)-1)
        a = myedges[i]
        b = myedges[i+1]
       for j=start_ind:length(x)
            this_x = sorted_x[j]
            if (a <= this_x < b)
                out_y[i] = out_y[i] + sorted_y[j] * sorted_conf[j]
                out_x[i] = out_x[i] + this_x * sorted_conf[j]
                out_weights[i] = out_weights[i] + sorted_conf[j]
            elseif (this_x >= b)
                start_ind = j
                break
            end
        end
    end

    out_y = out_y ./ out_weights
    out_x = out_x ./ out_weights

    nan_vals = isnan.(out_x) .| isnan.(out_y)
    deleteat!(out_x,nan_vals)
    deleteat!(out_y,nan_vals)

    (out_x, out_y)
end

#=
Rotate matrices about specified angle
=#
function rotate_mat(x::AbstractArray{T,1},y::AbstractArray{T,1},x_prime::AbstractArray{T,1},y_prime::AbstractArray{T,1},theta) where T
    x_prime[:] = x .* cos(theta) .- y .* sin(theta)
    y_prime[:] = y .* cos(theta) .+ x .* sin(theta)
    nothing
end

function rotate_mat(x::AbstractArray{T,1},y::AbstractArray{T,1},theta::Real) where T
    x_prime = x .* cos(theta) .- y .* sin(theta)
    y_prime = y .* cos(theta) .+ x .* sin(theta)
    (x_prime,y_prime)
end

function rotate_mat!(x::AbstractArray{T,1},y::AbstractArray{T,1},theta::Real) where T
    for i=1:length(x)
        x_old = x[i]
        y_old = y[i]
        (x[i],y[i]) = rotate_mat(x_old,y_old,theta)
    end
    nothing
end

function rotate_mat(points::Array{CartesianIndex{2},1},theta::Real)
    x = zeros(Float64,length(points))
    y = zeros(Float64,length(points))
    for i=1:length(x)
        (x[i],y[i])=rotate_mat(points[i][1],points[i][2],theta)
    end
    (x,y)
end

function rotate_mat(x::Real,y::Real,theta::Real)
    x_out = x * cos(theta) - y * sin(theta)
    y_out = y * cos(theta) + x * sin(theta)
    (x_out,y_out)
end

function get_whisker(upsampled::AbstractArray{T,2},rot_angle::Real,n_points=100) where T

    (xx,yy,confs) = WhiskerTracking.get_points(upsampled)

    xx = convert(Array{Float64,1},xx)
    yy = convert(Array{Float64,1},yy)

    (x_out,y_out) = WhiskerTracking.calculate_whisker_fit(xx,yy,confs,n_points,rot_angle)
end

function calculate_whisker_predictions(output::Array,hg::StackedHourglass.NN,flip_x=false,flip_y=false)

    atype = []
    if CUDA.has_cuda_gpu()
        atype = KnetArray
    else
        atype = Array
    end

    if flip_x
        reverse!(output,dims=1)
    end
    if flip_y
        reverse!(output,dims=2)
    end

    pred=StackedHourglass.predict_single_frame(hg,output,atype)

    if flip_x
        reverse!(pred,dims=1)
    end
    if flip_y
        reverse!(pred,dims=2)
    end
    pred
end