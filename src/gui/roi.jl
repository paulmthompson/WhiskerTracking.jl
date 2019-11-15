
function _make_roi_gui()

    roi_grid=Grid()
    roi_gen_button = CheckButton("Select ROI center")
    roi_grid[1,1] = roi_gen_button
    roi_height_button = SpinButton(20:150)
    roi_grid[1,2] = roi_height_button
    roi_grid[2,2] = Label("ROI Height")
    roi_width_button = SpinButton(20:150)
    roi_grid[1,3] = roi_width_button
    roi_grid[2,3] = Label("ROI Width")
    roi_tilt_button = SpinButton(-45:45)
    roi_grid[1,4] = roi_tilt_button
    roi_grid[2,4] = Label("ROI Tilt")

    roi_grid[1,7] = Label("When candidate whisker traces are detected in the image, \n only whiskers with bases inside the ROI are kept.")

    roi_win=Window(roi_grid)
    Gtk.showall(roi_win)
    visible(roi_win,false)
    
    r_widgets=roi_widgets(roi_win,roi_gen_button,roi_height_button,roi_width_button,roi_tilt_button)
end
