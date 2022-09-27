
#=
Configuration Load and saving
=#
function load_hourglass_to_nn(nn,config_path)
    nn.weight_path = config_path
    hg=HG2(64,1,4); #Dummy Numbers
    load_hourglass(nn.weight_path,hg)
    nn.hg = hg
    nn.use_existing_weights = true
    nn.features=StackedHourglass.features(hg)

    nothing
end

#=
Save and load training file
=#

function save_training(mypath,frame_list,woi,nn)

    file = jldopen(mypath, "w")
    write(file, "frame_list",frame_list)
    write(file, "woi",woi)
    write(file, "mean_img",nn.norm.mean_img)
    write(file, "std_img",nn.norm.std_img)

    close(file)

    nothing
end

