
function make_zoom_gui(b::Gtk.GtkBuilder,handles::Tracker_Handles)

    b["zoom_grid"][2,1] = handles.zoom.c
    setproperty!(handles.zoom.c,:hexpand,true)
    setproperty!(handles.zoom.c,:vexpand,true)
    show(handles.zoom.c)

end

function add_analog_callbacks(b::Gtk.GtkBuilder,handles::Tracker_Handles)

    signal_connect(zoom_select_cb,b["select_zoom_button"],"toggled",Void,(),false,(handles,))

    nothing
end

function zoom_select_cb(w::Ptr,user_data::Tuple{Tracker_Handles})

    han, = user_data

    onset = get_gtk_property(han.b["select_zoom_button"],:active,Bool)

    if onset
        han.selection_mode = 14
    else
        han.selection_mode = 1
    end

    nothing
end

function select_zoom_location(han::Tracker_Handles,m_x,m_y)

    han.zoom.w1 = round(Int64,m_x)
    han.zoom.h1 = round(Int64,m_y)

    push!((han.c.mouse, :button1release), (c, event) -> zoom_stop(han, event.x, event.y))
end

function zoom_stop(han::Tracker_Handles,m_x,m_y)

    han.zoom.w2 = round(Int64,m_x)
    han.zoom.h2 = round(Int64,m_y)

    pop!((han.c.mouse, :button1release))
end

function draw_zoom(han::Tracker_Handles)

    ctx=Gtk.getgc(han.zoom.c)

     w = han.zoom.w2 - han.zoom.w1
     h = han.zoom.h2 - han.zoom.h1

     img2 = han.current_frame[w1:w2,h1:h2]

     for i=1:length(img2)
        han.plot_frame[i] = (convert(UInt32,img2[i]) << 16) | (convert(UInt32,img2[i]) << 8) | img2[i]
     end
     stride = Cairo.format_stride_for_width(Cairo.FORMAT_RGB24, w)
     surface_ptr = ccall((:cairo_image_surface_create_for_data,Cairo._jl_libcairo),
                 Ptr{Void}, (Ptr{Void},Int32,Int32,Int32,Int32),
                 han.plot_frame, Cairo.FORMAT_RGB24, w, h, stride)

     ccall((:cairo_set_source_surface,Cairo._jl_libcairo), Ptr{Void},
     (Ptr{Void},Ptr{Void},Float64,Float64), ctx.ptr, surface_ptr, 0, 0)

     rectangle(ctx, 0, 0, w, h)

     fill(ctx)

     reveal(han.zoom.c)
end
