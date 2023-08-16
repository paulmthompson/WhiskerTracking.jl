
using Test, WhiskerTracking 

@testset "utils" begin 

x = rand(100000)

output = WhiskerTracking.bandpass_filter(x,10.0,100.0,500.0)

@test length == 100000

end