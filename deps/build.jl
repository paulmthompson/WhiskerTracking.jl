

if Sys.islinux()
    run(`wget https://www.dropbox.com/s/1dr7g8x270xdrup/whisk-1.1.0d-64bit-Linux.tar.gz`)
    run(`tar -xzf whisk-1.1.0d-64bit-Linux.tar.gz`)
    rm("whisk-1.1.0d-64bit-Linux.tar.gz")
    run(`mv whisk-1.1.0d-Linux whisk`)
elseif Sys.iswindows()
    run(`curl.exe --url https://www.dropbox.com/s/0dwksb5pihauvz8/whisker.zip?dl=0 -o whisk.zip -L`)
    run(`powershell.exe -nologo -noprofile -command "Expand-Archive -Literalpath ./whisk.zip"`)
    rm("whisk.zip")
elseif Sys.isosx()
    println("No Mac support!")
else
    println("Operating system not recognized.")
end
