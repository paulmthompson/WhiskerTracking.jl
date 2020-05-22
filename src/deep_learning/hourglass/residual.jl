
mutable struct Conv1 <: NN
    w::Param{KnetArray{Float32,4}} #weights
    b::Param{KnetArray{Float32,4}} #biases
    ms::Knet.BNMoments #batch norm moments
    bn_p::Param{KnetArray{Float32,1}} #batch norm parameters
    stride::Int64
    padding::Int64
    training::Bool
end

function (c::Conv1)(x::Union{KnetArray{Float32,4},AutoGrad.Result{KnetArray{Float32,4}}})
    bn=batchnorm(x,c.ms,c.bn_p,training=c.training)
    relu.(bn)
    output=conv4(c.w,bn,stride=c.stride,padding=c.padding) .+ c.b
    bn=nothing
    output
end

function Conv1(in_dim,out_dim,k_s,stride,padding)
    bn_p = Param(convert(KnetArray{Float32,1},bnparams(in_dim)))
    ms = bnmoments()
    w = Param(convert(KnetArray,xavier_normal(Float32,k_s,k_s,in_dim,out_dim)))
    b = Param(convert(KnetArray,xavier_normal(Float32,1,1,out_dim,1)))
    Conv1(w,b,ms,bn_p,stride,padding,true)
end

function set_testing(f::Conv1,training=false)
    f.training=training
    nothing
end

mutable struct Conv0 <: NN
    w::Param{KnetArray{Float32,4}} #weights
    b::Param{KnetArray{Float32,4}} #biases
    stride::Int64
    padding::Int64
end

function (c::Conv0)(x::Union{KnetArray{Float32,4},AutoGrad.Result{KnetArray{Float32,4}}})
    conv4(c.w,x,stride=c.stride,padding=c.padding) .+ c.b
end

function Conv0(in_dim,out_dim,k_s,stride,padding)
    w = Param(convert(KnetArray,xavier_normal(Float32,k_s,k_s,in_dim,out_dim)))
    b = Param(convert(KnetArray,xavier_normal(Float32,1,1,out_dim,1)))
    Conv0(w,b,stride,padding)
end

struct Residual <: NN
    c1::Conv1
    c2::Conv1
    c3::Conv1
end

function (r::Residual)(x::Union{KnetArray{Float32,4},AutoGrad.Result{KnetArray{Float32,4}}})
    c1=r.c1(x)
    c2=r.c2(c1)
    output=r.c3(c2) .+ x
    c1=nothing; c2=nothing
    output
end

function Residual(in_dim,out_dim)
    c1=Conv1(in_dim,div(out_dim,2),1,1,0)
    c2=Conv1(div(out_dim,2),div(out_dim,2),3,1,1)
    c3=Conv1(div(out_dim,2),out_dim,1,1,0)
    Residual(c1,c2,c3)
end

function set_testing(f::Residual,training=false)
    set_testing(f.c1,training)
    set_testing(f.c2,training)
    set_testing(f.c3,training)
    nothing
end

mutable struct Residual_skip <: NN
    w::Param{KnetArray{Float32,4}}
    b::Param{KnetArray{Float32,4}}
    c1::Conv1
    c2::Conv1
    c3::Conv1
end

function (r::Residual_skip)(x::Union{KnetArray{Float32,4},AutoGrad.Result{KnetArray{Float32,4}}})
    residual = conv4(r.w,x,stride=1) .+ r.b
    c1=r.c1(x)
    c2=r.c2(c1)
    output=r.c3(c2) .+ residual
    c1=nothing; c2=nothing; residual=nothing
    output
end

function Residual_skip(in_dim,out_dim)
    c1=Conv1(in_dim,div(out_dim,2),1,1,0)
    c2=Conv1(div(out_dim,2),div(out_dim,2),3,1,1)
    c3=Conv1(div(out_dim,2),out_dim,1,1,0)
    w=Param(convert(KnetArray,xavier_normal(Float32,1,1,in_dim,out_dim)))
    b=Param(convert(KnetArray,xavier_normal(Float32,1,1,out_dim,1)))
    Residual_skip(w,b,c1,c2,c3)
end

function set_testing(f::Residual_skip,training=false)
    set_testing(f.c1,training)
    set_testing(f.c2,training)
    set_testing(f.c3,training)
    nothing
end

struct Pool
end
(p::Pool)(x::Union{KnetArray{Float32,4},AutoGrad.Result{KnetArray{Float32,4}}}) = pool(x)

struct Unpool
end
(u::Unpool)(x::Union{KnetArray{Float32,4},AutoGrad.Result{KnetArray{Float32,4}}}) = unpool(x)
