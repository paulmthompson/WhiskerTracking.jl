
function WT_trace(iFrame,image_data::Array{UInt8,2})

    image=Ref{WT_Image}(WT_Image(1,640,480,C_NULL,pointer(image_data)))
    background=Ref{WT_Image}(WT_Image(1,640,480,C_NULL,pointer(zeros(UInt8,640*480))))
    pnseg=Ref{Int32}(0)

    data=ccall(Libdl.dlsym(libwhisk,:find_segments),Ptr{Whisker2},(Int32,Ref{WT_Image},Ref{WT_Image},Ref{Int32}),iFrame,image,background,pnseg)

    wts=Array{Whisker1}(0)

    for i=1:pnseg[]
        push!(wts,Whisker1(unsafe_load(data,i)))
    end

    wts
end

function get_JT_params()
    ccall((Libdl.dlsym(libwhisk,:Params)),Ptr{JT_Params},())
end
