
const background_img = zeros(UInt8,640*480)

function JT_trace(iFrame,image_data::Array{UInt8,2})

    image=Ref{WT_Image}(WT_Image(1,640,480,C_NULL,pointer(image_data)))
    background=Ref{WT_Image}(WT_Image(1,640,480,C_NULL,pointer(zeros(UInt8,640*480))))
    pnseg=Ref{Int32}(0)

    data=ccall(Libdl.dlsym(libwhisk,:find_segments),Ptr{Whisker2},(Int32,Ref{WT_Image},Ref{WT_Image},Ref{Int32}),iFrame,image,background,pnseg)

    wts=Array{Whisker1}(0)

    for i=1:pnseg[]
        ww=Whisker1(unsafe_load(data,i))
        push!(wts,deepcopy(ww))
    end

    ccall(Libdl.dlsym(libwhisk,:Free_Whisker_Seg_Vec),Void,(Ptr{Whisker2}, Int32),data,pnseg[])

    wts
end

function WT_trace(iFrame,image_data,min_length,pad_pos,mask)

    whiskers=JT_trace(iFrame,image_data)

    WT_length_constraint(whiskers,min_length)

    WT_reorder_whisker(whiskers,pad_pos)

    #Apply mask
    apply_mask(whiskers,mask,min_length)

    apply_roi(whiskers,pad_pos)

    eliminate_redundant(whiskers)

    whiskers
end

function get_JT_params()
    ccall((Libdl.dlsym(libwhisk,:Params)),Ptr{JT_Params},())
end

function change_JT_param(f_name,value)
    xx=get_JT_params()
    jt=unsafe_load(xx,1)

    setfield!(jt,f_name,value)

    unsafe_store!(xx,jt,1)

    nothing
end
