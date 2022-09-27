
#=
Create training file
=#

function create_new_weights(nn)
    hg=HG2(size(nn.labels,1),size(nn.labels,3),4);
    load_hourglass(nn.weight_path,hg)
    StackedHourglass.change_hourglass(hg,size(nn.labels,1),1,size(nn.labels,3))
    nn.features=features(hg)
    nn.hg = hg
    nn.use_existing_weights=true
    nothing
end


#=
Run Training methods
=#

function make_training_batch(img,ll,batch_size=8)
    dtrn=minibatch(img,ll,batch_size,xtype=KnetArray,ytype=KnetArray)
end

function run_training(hg,trn::Knet.Data,this_opt,p,epochs=100,ls=Array{Float64,1}())

    total_length=length(trn) * epochs
    minimizer = Knet.minimize(hg,ncycle(trn,epochs),this_opt)
    last_update = 0.0
    count=0
    Gtk.set_gtk_property!(p, :fraction, 0)
    sleep(0.0001)

        for x in takenth(minimizer,1)
            push!(ls,x)
            count+=1
            complete=round(count/total_length,digits=2)
            if complete > last_update
                Gtk.set_gtk_property!(p, :fraction, complete)
                last_update = complete
                reveal(p,true)
            end
            sleep(0.0001)
        end

    ls
end

function run_training_no_gui(hg,trn::Knet.Data,this_opt,epochs=100,ls=Array{Float32,1}())

    total_length=length(trn) * epochs
    minimizer = Knet.minimize(hg,ncycle(trn,epochs),this_opt)

    for x in takenth(minimizer,1)
        push!(ls,x)
        sleep(0.0001)
    end

    ls
end


#=
Error Checking before training
=#

#Make sure that dimensions of model weights match label dimensions
function check_hg_features(nn)

    #Output features
    if size(nn.labels,3) != features(nn.hg)
        StackedHourglass.change_hourglass_output(nn.hg,size(nn.labels,1),size(nn.labels,3))
        nn.features = features(nn.hg)
    end
end


function check_whiskers(woi,frame_list,max_frames)

    #Make sure all of the frames actually have a tracked whisker
    empty=trues(length(woi))
    for i=1:length(woi)
        if empty_whiskers(woi[i])
            empty[i] = false
            println("You have an untraced whisker at index: ", i)
        end
    end

    #Last frames don't always work
    if (frame_list[end] == max_frames)
        empty[end] = false
    end

    new_woi = woi[empty]
    new_frame_list = frame_list[empty]

    (new_woi, new_frame_list)
end

function empty_whiskers(w)

    (length(w.x)==0)|(length(w.y)==0)

end
