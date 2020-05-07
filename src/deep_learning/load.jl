
function load_single_image(filename::String,imgs,ii,x_off,y_off)

    this_img=load(filename)

    x_off[ii] = 256 / size(this_img,2)
    y_off[ii] = 256 / size(this_img,1)

    new_img=imresize(this_img,(256,256))
    for i=1:size(imgs,2)
        for j=1:size(imgs,1)
            imgs[i,j,1,ii]=convert(Float32,new_img[j,i].r)
            imgs[i,j,2,ii]=convert(Float32,new_img[j,i].g)
            imgs[i,j,3,ii]=convert(Float32,new_img[j,i].b)
        end
    end

    nothing
end

function make_all_labels(ll,xo,yo,j_a)
    for i=1:size(ll,4)
        add_single_label(ll,i,xo,yo,j_a);
    end
end

function add_single_label(ll,ii,x_off,y_off,j_a,ds=4)

    for i=1:size(ll,3)
        xo=round(Int64,x_off[ii] * j_a[1,i,ii]/ds)
        yo=round(Int64,y_off[ii] * j_a[2,i,ii]/ds)

        ll[:,:,i,ii] = gaussian_2d(1.0:1.0:size(ll,1),1.0:1.0:size(ll,2),xo,yo)

        if maximum(ll[:,:,i,ii])>0
            ll[:,:,i,ii] = ll[:,:,i,ii] ./ maximum(ll[:,:,i,ii])
        end

    end
end
function save_hourglass(name,x)
    count=[1];
    file=matopen(name,"w")
        save_nn(x,file,count)
    close(file)
end

function save_nn(x,file,count)

    for f in fieldnames(typeof(x))
        f1=getfield(x,f)
        if typeof(f1) <: NN
            save_nn(f1,file,count)
        elseif eltype(f1) <: NN
            for i=1:length(f1)
                save_nn(f1[i],file,count)
            end
        else
            if f == :w
                write(file,string("w_",count[1]),convert(Array,f1.value))
                count[1]+=1
            elseif f == :b
                write(file,string("b_",count[1]),convert(Array,f1.value))
                count[1]+=1
            elseif f == :ms
                write(file,string("ms_mo_",count[1]),f1.momentum)
                write(file,string("ms_mean_",count[1]),convert(Array,f1.mean))
                write(file,string("ms_var_",count[1]),convert(Array,f1.var))
                count[1]+=1
            elseif f == :bn_p
                write(file,string("bn_p_",count[1]),convert(Array,f1.value))
                count[1]+=1
            end
        end
    end
end

function load_hourglass(name,x)
    count=[1];
    file=matopen(name,"r")
        load_nn(x,file,count)
    close(file)
end
function load_nn(x,file,count)

    for f in fieldnames(typeof(x))
        f1=getfield(x,f)
        if typeof(f1) <: NN
            load_nn(f1,file,count)
        elseif eltype(f1) <: NN
            for i=1:length(f1)
                load_nn(f1[i],file,count)
            end
        else
            if f == :w
                setfield!(x,f,Param(convert(KnetArray,read(file,string("w_",count[1])))))
                count[1]+=1
            elseif f == :b
                setfield!(x,f,Param(convert(KnetArray,read(file,string("b_",count[1])))))
                count[1]+=1
            elseif f == :ms
                x.ms.momentum=read(file,string("ms_mo_",count[1]))
                x.ms.mean = convert(KnetArray,read(file,string("ms_mean_",count[1])))
                x.ms.var = convert(KnetArray,read(file,string("ms_var_",count[1])))
                count[1]+=1
            elseif f == :bn_p
                setfield!(x,f,Param(convert(KnetArray,read(file,string("bn_p_",count[1])))))
                count[1]+=1
            end
        end
    end
end

function change_hourglass(hg,feature_num,input_dim,output_dim)

    #Input transform
    hg.fb.c1.w = Param(convert(KnetArray,xavier_normal(Float32,7,7,input_dim,64)))
    hg.fb.c1.b = Param(convert(KnetArray,xavier_normal(Float32,1,1,64,1)))
    hg.fb.c1.bn_p = Param(convert(KnetArray{Float32,1},bnparams(1)))
    hg.fb.c1.ms = bnmoments()

    for i=1:length(hg.c1)
        hg.c1[i].w = Param(convert(KnetArray,xavier_normal(Float32,1,1,feature_num,output_dim)))
        hg.c1[i].b = Param(convert(KnetArray,xavier_normal(Float32,1,1,output_dim,1)))
    end

    for i=1:length(hg.merge_preds)
        hg.merge_preds[i].w = Param(convert(KnetArray,xavier_normal(Float32,1,1,output_dim,feature_num)))
        hg.merge_preds[i].b = Param(convert(KnetArray,xavier_normal(Float32,1,1,feature_num,1)))
    end

    nothing
end
