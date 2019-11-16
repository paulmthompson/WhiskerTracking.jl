if is_unix()
    const libwhisk_path = string(homedir(),"/Programs/whisk/build/libwhisk.so")
    jt_parameters = string(homedir(),"/Programs/whisk/build/default.parameters")
else
    const libwhisk_path = "C:\\Program Files\\WhiskerTracking\\lib\\whisk.dll"
    jt_parameters = "C:\\Program Files\\WhiskerTracking\\default.parameters"
end

#libwhisk = Libdl.dlopen(libwhisk_path,Libdl.RTLD_NOW)

if is_unix()
    const ffmpeg_path = string(homedir(),"/Programs/ffmpeg/ffmpeg")
    const ffprobe_path = string(homedir(),"/Programs/ffmpeg/ffprobe")
else
    const ffmpeg_path = string(homedir(),"\\Documents\\ffmpeg\\bin\\ffmpeg")
    const ffprobe_path = string(homedir(),"\\Documents\\ffmpeg\\bin\\ffprobe")
end
