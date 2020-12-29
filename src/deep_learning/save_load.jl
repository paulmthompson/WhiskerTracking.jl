
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
function save_training(han,mypath=string(han.paths.backup,"/labels.jld"))
    save_training(mypath,han.frame_list,han.woi,han.nn)
end

function save_training(mypath,frame_list,woi,nn)

    file = jldopen(mypath, "w")
    write(file, "frame_list",frame_list)
    write(file, "woi",woi)
    write(file, "mean_img",nn.norm.mean_img)
    write(file, "std_img",nn.norm.std_img)

    close(file)

    nothing
end

function load_training(han::Tracker_Handles,path::String)

    file = jldopen(path, "r")
    frame_list = read(file, "frame_list")
    woi = read(file, "woi")
    if typeof(woi) == Array
        han.woi = Dict{Int64,Whisker1}(frame_list,woi)
    else # New Version
        han.woi = woi
    end

    han.frame_list = frame_list
    set_gtk_property!(han.b["labeled_frame_adj"],:upper,length(han.frame_list))

    tracked = [true for i=1:length(han.frame_list)]
    han.tracked = Dict{Int64,Bool}(zip(frame_list,tracked))

    pole_present = [false for i=1:length(han.frame_list)]
    han.pole_present=Dict{Int64,Bool}(zip(frame_list,pole_present))

    pole_loc = [zeros(Float32,2) for i=1:length(han.frame_list)]
    han.pole_loc=Dict{Int64,Array{Float32,1}}(zip(frame_list,pole_loc))

    han.nn.norm.mean_img = read(file, "mean_img")
    han.nn.norm.std_img = read(file, "std_img")

    close(file)

end
