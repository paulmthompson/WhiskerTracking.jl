


################
Getting Started
################

********
Overview
********
This is a guide to track mice whiskers in 2d.

To begin, follow these steps:


1) Open Whisker Tracking GUI
2) Open Jupyter Notebook Navigator
3) Go to ~/Documents/Analysis_Scripts/Whisker_Tracking_new.ipynb
4) Change "data_path" to name of folder for video analysis
5) Run the cells
6) The GUI will appear. Wait until the notebook shows it has stopped running to proceed
7) Use the arrow keys right and left to load the first image

**********************
1. Define Whisker Pad
**********************

a) Select "Extras" --> "Whisker Pad"
b) Click the "Select Whisker Pad" checkbox
c) In the image, click on the approximate whisker pad location (a blue circle should appear)
d) Uncheck the "Select Whisker Pad" checkbox
e) Exit out of the Whisker Pad window

********************
2. Create Face Mask
********************

a) Select "Extras" --> "Mask"
b) Click "Create Mask"
c) Increase the "minimum intensity" and "maximum intensity" scroll-boxes to create the mask (The mask will be shown in red, make sure it does not creep up the whisker)
d) When the mask is complete, uncheck "Create Mask"
e) Exit out of the mask window

*Use arrow keys to reload the mask and make it disappear*

******************************
3. Discretization of Whiskers
******************************

Open the "Viewer" window

a) Go to "Extras" --> "Viewer"
b) Click the "Discrete Points" checkbox

*You can leave this window open off to the side*

Open the Discrete Points window

a) Go to "Extras" --> "Discretization"
b) Click the "Auto Calculate" button

*Leave this window open*

********************
4. Tracing Whiskers
********************

a) Find "Whisker Trace" in current frame
b) Click the "Trace" button (blue candidate whisker traces should appear)
c) If a representative whisker is present, select it with the mouse by clicking the blue trace for the whisker of interest (It should turn red).
d) At the base of the whisker, there will be a collection of green open circles bunched together. These are the "discrete points" selected to describe the whisker.
e) Spread the "discrete points" out across the length of the whisker

*Leave this window off to the side*

*********************
5. Annotating Frames
*********************

*You should now annotate ~100 frames that are significantly different from one another so that the machine learning algorithm is sufficiently prepared to find the whisker in the remaining frames*

a) Use the slider at the bottom (or the arrow keys) to advance forward in the video.
b) When you find a good candidate frame, hit the "trace" button. Blue traces will appear.
c) If the traces are acceptable, click the "add frame to tracking" button. A green boundary will appear around the image.
d) Click the whisker of interest. It should appear red and the discrete green points should be automatically calculated and applied.
e) Repeat steps 5a-5d until you have annotated ~100 frames

*If the whiskers overlap, go to "Extras" --> "Tracing" --> "Combine segments", then select the most proximal trace of the true whisker, and the distal part of the true whisker. If this works, you will see the true whisker now entirely in red. When done, unclick the "combine segments" button.*
*If some whiskers do not show up well or are not annotated correctly, they can be fixed later in DeepLabCut*

************************************
6. Pole Annotation and Verification
************************************

a) When frames have been labeled, go back to the first annotated frame
b) Open the pole window by going to "Extra" --> "Pole"
c) In each frame that has a pole, click the "select pole location" button in the pole window and click on the pole in the image (A blue circle should appear)
d) Advance to the next frame and redo steps 6a-6c until every frame's pole has been labeled

************************
7. Export to DeepLabCut
************************

a) Go to "Other Programs" --> "DeepLabCut"
b) Click the "Initialize" button (the jupyter notebook will have some output)
c) Check the "with pole button"
d) Click the "export" button
e) The data folder should be created in the ~/Documents/Analysis_Scripts folder in a new folder with the date
f) When you enter this new folder, the whisker tracking data will be in the DLC folder. Enter it to find the config.yaml.
g) Copy the name of this directory

****************************
8. Fix errors in DeepLabCut
****************************

a) In the jupyter view, go to the notebook ~/documents/ Analysis_Scripts/check_dlc_labels.ipynb.
b) Change the path to the path of your config.yaml file from the last step
c) Click "Load frames" and select the folder that comes up
d) Use the DeepLabCut view to scroll through the annotated images of the whisker and pole.
e) If any points are wrong, or you need to add additional points, or delete points, you can do it here.
f) When you are satisfied with the quality of the data, click the "save" button

*********************
9. Train the network
*********************

*This is done to get your labeled data*
