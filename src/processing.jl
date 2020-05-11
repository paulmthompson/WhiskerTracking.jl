
function upload_mask(wt,mask_file)

    #Load mask
    myimg = reinterpret(UInt8,load(string(wt.data_path,mask_file)))

    if size(myimg,3) == 1
        wt.mask = myimg.==0
    else
        wt.mask=myimg[1,:,:].==0
    end

    nothing
end

function generate_mask(wt,myimg,min_val,max_val)

    if VERSION > v"0.7-"
        myimg[myimg.>max_val] .= 255
        myimg[myimg.<min_val] .= 0
    else
        myimg[myimg.>max_val] = 255
        myimg[myimg.<min_val] = 0
    end
    wt.mask=myimg.==0

    #Find connected Regions
    comp=label_components(wt.mask)

    if maximum(comp)>1
        total_counts=zeros(Int64,maximum(comp))
        for i=1:length(total_counts)
            total_counts[i]=length(find(comp.==i))
        end

        max_comp=indmax(total_counts)

        for i=1:length(wt.mask)
            if comp[i] != max_comp
                wt.mask[i] = false
            end
        end
    end

    nothing
end

function adjust_contrast_gui(han::Tracker_Handles)
    han.current_frame=adjust_contrast(han.current_frame,han.wt.contrast_min,han.wt.contrast_max)
    nothing
end

#=
Only Whiskers are identified that are inside a region of interest (ROI)
That ROI is a circle centered on the whisker pad of radius 100
=#

function apply_roi(whiskers::Array{Whisker1,1},pad_pos::Tuple{Float32,Float32})

    remove_whiskers=Array{Int64,1}()

    #for i=1:length(whiskers)

        #if sqrt((pad_pos[1]-whiskers[i].x[end])^2+(pad_pos[2]-whiskers[i].y[end])^2)>100.0
            #push!(remove_whiskers,i)
        #end
    #end

    #deleteat!(whiskers,remove_whiskers)

    nothing
end

function total_frames(tt,fps)
    h=Base.Dates.hour(tt)
    m=Base.Dates.minute(tt)
    s=Base.Dates.second(tt)
    (h*3600+m*60+s)*fps + 1
end

function frames_between(tt1,tt2,fps)
    total_frames(tt2,fps)-total_frames(tt1,fps)
end

function get_follicle(han::Tracker_Handles)
    x=0.0
    y=0.0
    count=0

    for i=1:length(han.tracked)
        if han.tracked[i]
            x+=han.woi[i].x[end]
            y+=han.woi[i].y[end]
            count+=1
        end
    end
    x=x/count
    y=y/count
    (x,y)
end

#Need to optimize this significantly
#Really we want this to be such that the length of each line is equal.
#Probably can do this by interpolating along each segment or something
#I also need to reverse these
function whisker_similarity(han::Tracker_Handles,prev)

    cor_length=20

    w2_x=han.woi[han.frame-prev].x
    w2_y=han.woi[han.frame-prev].y
    mincor=10000.0.*ones(length(han.wt.whiskers))
    w_id = 0;
    for i=1:length(han.wt.whiskers)
        w1_x=han.wt.whiskers[i].x
        w1_y=han.wt.whiskers[i].y

        for j=1:(size(w1_x,1)-cor_length)
            for k=1:(size(w2_x,1)-cor_length)
                mycor=w_dist(w1_x,w2_x,w1_y,w2_y,j,k,cor_length)
                if mycor < mincor[i]
                    mincor[i]=mycor
                end
            end
        end
    end
    findmin(mincor)
end

function w_dist(x1,x2,y1,y2,i1,i2,cor_length)

    mysum=0.0
    for jj=1:cor_length
        mysum += sqrt((x2[i2+jj] - x1[i1+jj]) ^ 2 + (y2[i2+jj] - y1[i1+jj]) ^2)
    end
    mysum
end

whisker_similarity(han) = whisker_similarity(han,1)

function smooth(x, window_len=7)
    w = getfield(DSP.Windows, :lanczos)(window_len)
    DSP.filtfilt(w ./ sum(w), [1.0], x)
end

function calc_woi_angle(han::Tracker_Handles,x,y)

    this_angle=atan(y[end-5] - y[end], x[end-5] - x[end])
    han.woi_angle[han.frame]=rad2deg(this_angle)
    nothing
end

function calc_woi_curv(han::Tracker_Handles,x,y)
    han.woi_curv[han.frame]=get_curv(x,y)
    nothing
end

function get_curv(xdata,ydata)

    a=[xdata ydata]
    m=size(a,1)
    A = [2a -ones(m)]
    b=[]
    for i=1:m
        b=[b; norm(a[i,:])^2]
    end
    y=inv(A'*A)*A'*b
    x=y[1:end-1]
    R=y[end]
    r=sqrt(norm(x)^2-R)

    v1x=xdata[1]-xdata[end]
    v1y=ydata[1]-ydata[end]

    v2x=x[1]-xdata[end]
    v2y=x[2]-ydata[end]

    mydot = v1x * -v2y + v1y * v2x

    mycurv=1/r

    if mydot > 0
        mycurv *= -1
    end

    mycurv
end

function assign_woi(han::Tracker_Handles)

    han.woi[han.frame] = deepcopy(han.wt.whiskers[han.woi_id])

    #if han.discrete_auto_calc
        #make_discrete(han.wt.w_p,han.frame,han.woi[han.frame],han.d_spacing)
    #end

    x=han.woi[han.frame].x
    y=han.woi[han.frame].y

    calc_woi_angle(han,x,y)
    calc_woi_curv(han,x,y)

    nothing
end

function WT_length_constraint(whiskers::Array{Whisker1,1},min_length::Int)

    remove_whiskers=Array{Int64,1}()

    #length constraint
    for i=1:length(whiskers)
        if whiskers[i].len<min_length
            push!(remove_whiskers,i)
        end
    end

    deleteat!(whiskers,remove_whiskers)

    nothing
end

function apply_mask(whiskers::Array{Whisker1,1},mask::BitArray{2},min_length::Int64)

    remove_whiskers=Array{Int64,1}()

    for i=1:length(whiskers)
        delete_points=Array{Int64,1}()

        #Start at the tip and work our way back to the follicle.
        #If the mask hits something, we should probably delete all points following
        for j=1:length(whiskers[i].x)
            x_ind = round(Int64,whiskers[i].y[j])
            y_ind = round(Int64,whiskers[i].x[j])

            if x_ind<1
                x_ind=1
            elseif x_ind>size(mask,1)
                x_ind=size(mask,1)
            end

            if y_ind<1
                y_ind=1
            elseif y_ind>size(mask,2)
                y_ind=size(mask,2)
            end

            if mask[x_ind,y_ind]
                for k=j:length(whiskers[i].x)
                    push!(delete_points,k)
                end
                break
            end
        end

        deleteat!(whiskers[i].x,delete_points)
        deleteat!(whiskers[i].y,delete_points)
        deleteat!(whiskers[i].thick,delete_points)
        deleteat!(whiskers[i].scores,delete_points)
        whiskers[i].len = length(whiskers[i].x)

        #Sometimes whiskers are detected in mask of reasonable length, so they are completely deleted
        #In this step and will mess up later processing, so we should delete them after a length check
        if whiskers[i].len < min_length
            push!(remove_whiskers,i)
        end

    end

    deleteat!(whiskers,remove_whiskers)

    nothing
end

function WT_reorder_whisker(whiskers::Array{Whisker1,1},pad_pos::Tuple{Float32,Float32})

    #order whiskers so that the last index is closest to the whisker pad
    for i=1:length(whiskers)
        front_dist = (whiskers[i].x[1]-pad_pos[1])^2+(whiskers[i].y[1]-pad_pos[2])^2
        end_dist = (whiskers[i].x[end]-pad_pos[1])^2+(whiskers[i].y[end]-pad_pos[2])^2

        if front_dist < end_dist #
            reverse!(whiskers[i].x,1)
            reverse!(whiskers[i].y,1)
            reverse!(whiskers[i].scores,1)
            reverse!(whiskers[i].thick,1)
        end
    end

    nothing
end

function eliminate_redundant(whiskers::Array{Whisker1,1},keep_thres=20.0)

    i=1

    while i<length(whiskers)
        w2=[whiskers[i].x[(end-19):end] whiskers[i].y[(end-19):end]]

        mincor=10000.0
        w_id = 0;
        for j=1:length(whiskers)

            if j != i
                w1=[whiskers[j].x[(end-19):end] whiskers[j].y[(end-19):end]]

                mycor=euclidean(w1,w2)
                if mycor < mincor
                    mincor=mycor
                    w_id = i
                end
            end
            if mincor<keep_thres
                w1_score=mean(whiskers[j].scores)
                w2_score=mean(whiskers[i].scores)

                if w1_score > w2_score
                    deleteat!(whiskers,i)
                else
                    deleteat!(whiskers,j)
                end

                i=1
                break
            end
        end
        i+=1
    end

    nothing
end

#Order anterior to posterior
function reorder_whiskers(wt::Tracker)

    for i=1:length(wt.all_whiskers)

        xpos=[wt.all_whiskers[i][j].x[end] for j=1:length(wt.all_whiskers[i])]
        wt.all_whiskers[i]=wt.all_whiskers[i][sortperm(xpos)]
    end

    nothing
end
