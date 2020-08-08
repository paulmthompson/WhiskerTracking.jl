if is_unix()
    jt_parameters = string(dirname(Base.source_path()),"/../lib/default.parameters")
    const libwhisk_path=string(dirname(Base.source_path()),"/../deps/whisk/lib/whisk/libwhisk.so")
else
    const libwhisk_path=string(dirname(Base.source_path()),"\\..\\deps\\whisk\\whisker\\lib\\whisk.dll")
    jt_parameters = string(dirname(Base.source_path()),"\\..\\lib\\default.parameters")
end

#libwhisk = Libdl.dlopen(libwhisk_path,Libdl.RTLD_NOW)

if is_unix()
    #const ffmpeg_path = string(homedir(),"/Programs/ffmpeg/ffmpeg")
    #const ffprobe_path = string(homedir(),"/Programs/ffmpeg/ffprobe")
else
    #const ffmpeg_path = string(homedir(),"\\Documents\\ffmpeg\\bin\\ffmpeg")
    #const ffprobe_path = string(homedir(),"\\Documents\\ffmpeg\\bin\\ffprobe")
end

if is_unix()
    #const hourglass_path = string(homedir(),"/Programs/ffmpeg/ffmpeg")
else
    #const hourglass_path = string(homedir(),"\\Documents\\ffmpeg\\bin\\ffmpeg")
end
