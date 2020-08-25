using Distributed
addprocs(4)
@everywhere begin
    push!(LOAD_PATH,"/home/wanglab/Programs/WhiskerTracking.jl/src")
end
@everywhere using WhiskerTracking, Distributed, Knet

Knet.cuallocator()=false
@time myhandles=make_gui();
@time WhiskerTracking.add_callbacks(myhandles.b,myhandles)
