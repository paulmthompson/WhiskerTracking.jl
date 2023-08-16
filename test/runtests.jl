

using WhiskerTracking, Test

testfiles = ["utils.jl"]

for testfile in testfiles
    eval(:(@testset $testfile begin include($testfile) end))
end


