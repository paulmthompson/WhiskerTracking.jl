if Sys.isunix()
    jt_parameters = string(dirname(Base.source_path()),"/../lib/default.parameters")
    const libwhisk_path=string(dirname(Base.source_path()),"/../deps/whisk/lib/whisk/libwhisk.so")

    const pre_train_path = string(dirname(Base.source_path()),"/../deps/quad_hourglass_64.mat")
else
    const libwhisk_path=string(dirname(Base.source_path()),"\\..\\deps\\whisk\\whisker\\lib\\whisk.dll")
    jt_parameters = string(dirname(Base.source_path()),"\\..\\lib\\default.parameters")

    const pre_train_path = string(dirname(Base.source_path()),"\\..\\deps\\quad_hourglass_64.mat")
end

#libwhisk = Libdl.dlopen(libwhisk_path,Libdl.RTLD_NOW)

if Sys.isunix()
    #const ffmpeg_path = string(homedir(),"/Programs/ffmpeg/ffmpeg")
    #const ffprobe_path = string(homedir(),"/Programs/ffmpeg/ffprobe")
else
    #const ffmpeg_path = string(homedir(),"\\Documents\\ffmpeg\\bin\\ffmpeg")
    #const ffprobe_path = string(homedir(),"\\Documents\\ffmpeg\\bin\\ffprobe")
end

if Sys.isunix()
    #const hourglass_path = string(homedir(),"/Programs/ffmpeg/ffmpeg")
else
    #const hourglass_path = string(homedir(),"\\Documents\\ffmpeg\\bin\\ffmpeg")
end
