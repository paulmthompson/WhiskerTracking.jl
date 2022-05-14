
function get_displacements(x,y,d_vec,frames)
    
    x1 = x[frames[1]]
    y1 = y[frames[1]]
    
    output_frames_t = frames[end] - frames[1] + 1
    
    out_displacements = zeros(Float64,length(d_vec),output_frames_t)
    
    w_length = mean([WhiskerTracking.total_length(x[i],y[i]) for i in frames])

    (w1_theta,last_ind) = WhiskerTracking.convert_to_angular_coordinates(x1,y1,d_vec.*w_length)

    for i=2:output_frames_t
    
        x2 = x[frames[i]]
        y2 = y[frames[i]]
        
        (w_theta,last_ind) = WhiskerTracking.convert_to_angular_coordinates(x2,y2,d_vec.*w_length)
        
        for j=2:length(d_vec)
           rel_theta =  w_theta[j]
           disp = sin(rel_theta/2) * w_length * (d_vec[j] - d_vec[j-1]) *2
           out_displacements[j,i] =  disp .+ out_displacements[j-1,i]
        end
    end
    
    write_moose_displacement("test.txt",[100.0; 200.0; 300.0; 400.0],out_displacements)
    
    out_displacements
end

function get_displacement_single_frame(out_file_path,x1,y1,d_vec,w_length)
    
    (w1_theta,last_ind) = WhiskerTracking.convert_to_angular_coordinates(x1,y1,d_vec.*w_length)

    out_displacements=zeros(Float64,last_ind,2)

    for j=2:last_ind
        rel_theta =  w_theta[j]
        disp = sin(rel_theta/2) * w_length * (d_vec[j] - d_vec[j-1]) *2
        out_displacements[j,2] =  disp .+ out_displacements[j-1,2]
    end

    mouse_displacement_locations = [i * 100.0 for i=1:last_ind]
        
    write_moose_displacement(out_file_path,mouse_displacement_locations,out_displacements)
    
    out_displacements
end

function write_moose_displacement(file_name,d_vec,displacements)
    open(file_name,"w") do io
    
        println(io,"AXIS X")
        
        for d in d_vec
            print(io,d," ")
        end
        
        println(io)
        
        println(io,"AXIS T")
    
        for i=0:(size(displacements,2)-1)
            print(io,i, " ")
        end
        println(io)
        
        println(io,"DATA")
        for d in displacements
            println(io,d)
        end
        
    end
end