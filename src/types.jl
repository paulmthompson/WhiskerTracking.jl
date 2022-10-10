
mutable struct Whisker1
    id::Int32
    time::Int32
    len::Int32
    x::Array{Float32,1}
    y::Array{Float32,1}
    thick::Array{Float32,1}
    scores::Array{Float32,1}
end

Whisker1()=Whisker1(0,0,0,Array{Float32,1}(),Array{Float32,1}(),Array{Float32,1}(),Array{Float32,1}())

include("janelia_types.jl")

function Whisker1(w::Whisker2)
    id=w.id
    time=w.time
    len=w.len
    x=unsafe_wrap(Array,w.x,len)
    y=unsafe_wrap(Array,w.y,len)
    thick=unsafe_wrap(Array,w.thick,len)
    scores=unsafe_wrap(Array,w.scores,len)
    Whisker1(id,time,len,x,y,thick,scores)
end

mutable struct Tracker
    data_path::String
    file_name::String
    vid_name::String
    tracking_path::String
    tracking_name::String
    min_length::Int64 #Minimum size of traced element from Janelia tracker, in pixels
    mask::BitArray{2}
    extended_mask::BitArray{2}
    whiskers::Array{Whisker1,1} #Properties of whiskers in active frame
    pad_pos::Tuple{Float32,Float32}
    h::Int64
    w::Int64
    all_whiskers::Array{Array{Whisker1,1},1} #Whiskers on every frame - IS THIS STILL NEEDED?
end

include("contact_detection.jl")

mutable struct classifier
    tc::TouchClassifier
    w_id::Int64
end

function classifier()
    if CUDA.has_cuda_gpu()
        classifier(TouchClassifier(64,2,2),1)
    else
        classifier(TouchClassifier(64,2,2,Array),1)
    end
end

mutable struct Normalize_Parameters
    mean_img::Array{Float32,3}
    std_img::Array{Float32,3}
    min_ref::Float32
    max_ref::Float32
    num::Int64 #Number of frames to calculate mean over
end

Normalize_Parameters() = Normalize_Parameters(zeros(Float32,0,0,0),zeros(Float32,0,0,0),0,0,10000)

mutable struct Manual_Class
    max_frames::Int64

    partial_contact::Int64
    contact_block::Array{Tuple,1} #Contact on and off tuples
    no_contact_block::Array{Tuple,1} #No Contact on and off
    contact::Array{Int64,1} #Manually classified contact frames; 0 is not manual; 1 = no contact; 2 = contact

    calc_contact_block::Array{Tuple,1}

    pro_re::Dict{Int,Int}
    pro_re_block::Array{Int64,1}

    exclude::Array{Tuple,1}
    exclude_block::BitArray{1}
end

Manual_Class() = Manual_Class(0,1,Array{Tuple,1}(),Array{Tuple,1}(),Array{Int64,1}(),Array{Tuple,1}(),Dict{Int,Int}(),Array{Int64,1}(),Array{Tuple,1}(),falses(1))

Manual_Class(frame_num::Int) = Manual_Class(frame_num,1,Array{Tuple,1}(),Array{Tuple,1}(),
zeros(Int64,frame_num),Array{Tuple,1}(),Dict{Int,Int}(),zeros(Int64,frame_num),Array{Tuple,1}(),falses(frame_num))

mutable struct NeuralNetwork
    labels::Array{Float32,4} #Labels for training
    imgs::Array{Float32,4} #Images for training
    norm::Normalize_Parameters #Reference values to scale input images
    hg::StackedHourglass.NN #Deep Learning weights
    epochs::Int64
    losses::Array{Float32,1}
    confidence_thres::Float64
    predict_single::Bool
    normalize_inputs::Bool
    weight_path::String
    features::Int64
    draw_preds::Bool
    use_existing_weights::Bool
    use_existing_labels::Bool
    predicted::Array{Float32,3}
    flip_x::Bool
    flip_y::Bool
end

function NeuralNetwork()
    if CUDA.has_cuda_gpu()
        hg = HG2(64,13,4)
    else
        hg = HG2(64,13,4, Array)
    end
    NeuralNetwork(zeros(Float32,0,0,0,0),zeros(Float32,0,0,0,0),Normalize_Parameters(), hg,10,zeros(Float32,0),0.5,false,
true,pre_train_path,1,false,false,false,zeros(Float32,0,3,0),false,false)
end


mutable struct Tracked_Whisker
    path::String
    whiskers_x::Vector{Vector{Float64}}
    whiskers_y::Vector{Vector{Float64}}
    whiskers_l::Vector{Float64}
    pole_x::Array{Float64,1}
    pole_y::Array{Float64,1}
    follicle_x::Array{Float64,1}
    follicle_y::Array{Float64,1}
    follicle_angle::Array{Float64,1}
    contact_angle::Array{Float64,1}
    normal_angle::Array{Float64,1}
    ip_1::Array{Float64,1}
    ip_2::Array{Float64,1}
    parabola_coeffs::Array{Float64,2}
    parabola_angle::Array{Float64,1}
    whisker_pad::Tuple{Float32,Float32}
    intrinsic_x::Array{Float64,1}
    intrinsic_y::Array{Float64,1}
end

function Tracked_Whisker(n)
    Tracked_Whisker("",[zeros(Float64,0) for i=1:n],[zeros(Float64,0) for i=1:n],zeros(Float64,n),zeros(Float64,n),zeros(Float64,n),zeros(Float64,n),
    zeros(Float64,n),zeros(Float64,n),zeros(Float64,n),zeros(Float64,n),
    50.0.*ones(Float64,n),400.0.*ones(Float64,n),zeros(Float64,3,n),zeros(Float64,n),(0.0f0,0.0f0),zeros(Float64,1),zeros(Float64,1))
end