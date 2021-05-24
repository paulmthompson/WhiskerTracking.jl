
mutable struct TouchClassifier <: StackedHourglass.NN
    fb::StackedHourglass.FirstBlock
    r1::StackedHourglass.Residual
    pool1::StackedHourglass.Pool
    r2::StackedHourglass.Residual
    pool2::StackedHourglass.Pool
    r3::StackedHourglass.Residual
    pool3::StackedHourglass.Pool
    w::Union{Param{KnetArray{Float32,2}},Param{Array{Float32,2}}}
    b::StackedHourglass.PType4
end

function TouchClassifier(N,N_input,K,atype=KnetArray)
    fb = StackedHourglass.FirstBlock(N,atype) # 64 x 64 x 64

    fb.c1.w = Knet.Param(convert(atype,Knet.xavier_normal(Float32,7,7,N_input,64)))
    fb.c1.bn_p = Knet.Param(convert(atype{Float32,1},Knet.bnparams(N_input)))
    fb.c1.ms = Knet.bnmoments()

    r1 = StackedHourglass.Residual(N,N,atype)
    p1 = StackedHourglass.Pool()
    r2 = StackedHourglass.Residual(N,N,atype) # 32 x 32 x 64
    p2 = StackedHourglass.Pool()
    r3 = StackedHourglass.Residual(N,N,atype) # 16 x 16 x 64
    p3 = StackedHourglass.Pool() # 8 x 8 x 64
    fc_w = Knet.Param(convert(atype,Knet.xavier_normal(Float32,1,4096)))
    fc_b = Knet.Param(convert(atype,Knet.xavier_normal(Float32,1,1,1,1)))
    TouchClassifier(fb,r1,p1,r2,p2,r3,p3,fc_w,fc_b)
end

function (h::TouchClassifier)(x::StackedHourglass.HGType)

    temp = h.fb(x)
    r1 = h.r1(temp)
    p1 = h.pool1(r1)
    r2 = h.r2(p1)
    p2 = h.pool2(r2)
    r3 = h.r3(p2)
    p3 = h.pool3(r3)
    bmm(h.w,mat(p3)) .+ mat(h.b) #Fully connected layer. bmm does batch multiply, while MAT makes the matrix 2d
end

function (h::TouchClassifier)(x::StackedHourglass.HGType,y)
    bce(vec(h(x)),y)
end

function set_testing(h::TouchClassifier,training=false)
    StackedHourglass.set_testing(h.fb,training)
    StackedHourglass.set_testing(h.r1,training)
    StackedHourglass.set_testing(h.r2,training)
    StackedHourglass.set_testing(h.r3,training)
end
