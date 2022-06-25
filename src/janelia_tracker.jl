
#const background_img = zeros(UInt8,640*480)

#const background=Ref{WT_Image}(WT_Image(1,640,480,C_NULL,pointer(background_img)))

#1st dim = w
#2nd dim = h
function JT_trace(iFrame::Int,image_data::AbstractArray{UInt8,2},background_img=zeros(UInt8,length(image_data)),background=Ref{WT_Image}(WT_Image(1,size(image_data,1),size(image_data,2),C_NULL,pointer(background_img))))

    img=Ref{WT_Image}(WT_Image(1,size(image_data,1),size(image_data,2),C_NULL,pointer(image_data)))

    pnseg=Ref{Int32}(0)

    data=ccall((:find_segments,libwhisk_path),Ptr{Whisker2},(Int32,Ref{WT_Image},Ref{WT_Image},Ref{Int32}),iFrame,img,background,pnseg)

    wts=Array{Whisker1,1}()

    for i=1:pnseg[]
        ww=Whisker1(unsafe_load(data,i))
        push!(wts,deepcopy(ww))
        #push!(wts,Whisker1(unsafe_load(data,i)))
    end

    ccall((:Free_Whisker_Seg_Vec,libwhisk_path),Void,(Ptr{Whisker2}, Int32),data,pnseg[])

    wts
end

function WT_trace(iFrame::Int,image_data::AbstractArray{UInt8,2},min_length::Int,pad_pos::Tuple{Float32,Float32},mask::BitArray{2})

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
    ccall((:Params,libwhisk_path),Ptr{JT_Params},())
end

function change_JT_param(f_name,value)
    xx=get_JT_params()
    jt=unsafe_load(xx,1)

    setfield!(jt,f_name,value)

    unsafe_store!(xx,jt,1)

    nothing
end

#returns measurements for single
function JT_measure(wt::Tracker,frame_id,whisker_num,face_axis='x')

    facex=round(Int32,wt.pad_pos[1])
    facey=round(Int32,wt.pad_pos[2])
    whisk_num = convert(Int32,1)
    whisk_array = Ref{Whisker2}(Whisker2(wt.all_whiskers[frame_id][whisker_num]))

    mm=ccall((:Whisker_Segments_Measure,libwhisk_path),Ptr{JT_Measurements},
    (Ref{Whisker2},Int32,Int32,Int32,Cuchar),whisk_array,whisk_num,facex,facey,face_axis)

    unsafe_load(mm,1)
end

function JT_measure(w::Whisker1,facex::Float32,facey::Float32,face_axis='x')
    JT_measure(w,round(Int32,facex),round(Int32,facey),face_axis)
end

function JT_measure(w::Whisker1,facex::Int32,facey::Int32,face_axis='x')
    #This should be an option depending on how the whisker is oriented

    whisk_num = convert(Int32,1)

    whisk_array = Ref{Whisker2}(Whisker2(w))

    mm=ccall((:Whisker_Segments_Measure,libwhisk_path),Ptr{JT_Measurements},
    (Ref{Whisker2},Int32,Int32,Int32,Cuchar),whisk_array,whisk_num,facex,facey,face_axis)

    unsafe_load(mm,1)
end

function JT_measure(wt::Tracker,w::Whisker1,face_axis='x')

    facex=round(Int32,wt.pad_pos[1])
    facey=round(Int32,wt.pad_pos[2])

    JT_measure(w,facex,facey,face_axis)
end

function JT_find_segments(img,h,th,s,facemask)

    ccall(Libdl.dlsym(libwhisk,:compute_seed_from_point_field_on_grid),Void,(Ref{WT_Image},Int32,Int32,Int32,Float32,Float32,Ref{WT_Image},Ref{WT_Image},Ref{WT_Image}),
    img,50,4,5,0.0f0,0.0f0,h,th,s)

    mystride = img[].height

    s_j=unsafe_wrap(Array,convert(Ptr{Float32},s[].array),(length(img),))
    h_j=unsafe_wrap(Array,h[].array,(length(img),))
    th_j=unsafe_wrap(Array,convert(Ptr{Float32},th[].array),(length(img),))
    for i=1:length(h_j)
        if h_j[i]>0
            th_j[i] = th_j[i] / convert(Float32,h_j[i])
        end
    end

    mask=falses(length(img))

    nseeds=0
    for i=1:length(h_j)
        if (s_j[i] > 0.80f0)&(!facemask[i]) #SEED_THRESH
            nseeds+=1
            mask[i]=true
        end
    end

    myline=Ref{Line_Params}(Line_Params(0.5f0,convert(Float32,0.0f0),2.0f0,0.0f0))

    pi_cycle = pi / 4.0f0 / 18.0f0
    myangle=0.0f0

    scores=zeros(Float32,nseeds)
    inds=find(mask)
    j=1

    for i=inds

        offset=0.5f0
        xdir=100.0f0 * convert(Float32,cos(th_j[i]))
        ydir=100.0f0 * convert(Float32,sin(th_j[i]))

        if xdir < 0.0f0
            myangle = round(atan(-1.0f0 * ydir, -1.0f0 * xdir) / pi_cycle) * pi_cycle
        else
            myangle = round(atan(ydir,xdir) / 18.0f0) * pi_cycle
        end

        width = 2.0f0

        myline[].angle=myangle

        scores[j]=ccall(Libdl.dlsym(libwhisk,:eval_line),Float32,(Ref{Line_Params},Ref{WT_Image},Int32),myline,img,convert(Int32,i-1))
        j+=1
    end

    score_ord=sortperm(scores)

    nsegs=0
    ss=Ref{Seed}(Seed(0,0,0,0))
    for i=score_ord
        ss[].xpnt=(inds[i]-1) % mystride
        ss[].ypnt=div(inds[i]-1,mystride)
        ss[].xdir=round(Int32,100 * cos(th_j[inds[i]]))
        ss[].ydir=round(Int32,100 * sin(th_j[inds[i]]))
        w=ccall(Libdl.dlsym(libwhisk,:trace_whisker),Ptr{Whisker2},(Ref{Seed},Ref{WT_Image}),ss,img)

        if w == C_NULL
            ss[].ydir=round(Int32,100 * cos(th_j[inds[i]]))
            ss[].xdir=round(Int32,100 * sin(th_j[inds[i]]))
            w=ccall(Libdl.dlsym(libwhisk,:trace_whisker),Ptr{Whisker2},(Ref{Seed},Ref{WT_Image}),ss,img)
        end

        if w != C_NULL
            nsegs+=1
        end
    end

    nsegs
end
