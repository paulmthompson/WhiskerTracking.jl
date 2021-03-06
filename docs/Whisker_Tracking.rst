


################
Getting Started
################

********
Overview
********
This is a guide to track mice whiskers in 2d.

To begin, follow these steps:

#. Open Jupyter Notebook Navigator. You can do this one of several always
  * Open Julia. In the Julia terminal type:
  .. code-block:: julia

    using IJulia
    notebook()

  * Or, run anaconda (or anaconda navigator) and start jupyter.

#. Create a new notebook for WhiskerTracking, or load the default.
  * The default is located at ~/Documents/Analysis_Scripts/Whisker_Tracking_new.ipynb
  * Alternatively, you can copy the following code into a new notebook:
  .. code-block:: julia

    using WhiskerTracking
    myhandles=make_gui();

#. Run the cells
#. The GUI will appear. Wait until the notebook shows it has stopped running to proceed
#. Click on File --> Load Video and navigate to your video file. Your video should load and the first frame will appear.

**********************
1. Define Whisker Pad
**********************

The whisker pad location will let the algorithms know what the proximal
and distal ends of the whiskers are: the proximal end is the end of the whisker trace
that is closest to the whisker pad.

#. Select "Extras" --> "Whisker Pad"
#. Click the "Select Whisker Pad" checkbox
#. In the image, click on the approximate whisker pad location (a blue circle should appear)
#. Uncheck the "Select Whisker Pad" checkbox
#. Exit out of the Whisker Pad window

********************
2. Create Face Mask
********************

The face mask is an area of the image which no whisker traces can enter. In other words,
once the algorithm finds whisker traces in the image, any points within the mask region
will be subtracted. This option will create a face mask by manually adjusting the minimum and maximum
intensities of the image. The mask region will appear in red. Be sure that your mask only includes
the fur and doesn't creep up the length of the whisker.

#. Select "Extras" --> "Mask"
#. Click "Create Mask"
#. Increase the "minimum intensity" and "maximum intensity" scroll-boxes to create the mask
#. When the mask is complete, uncheck "Create Mask"
#. Exit out of the mask window
#. Use arrow keys to reload the mask and make it disappear

********************
3. Tracing Whiskers
********************

Now you can trace a whisker in the current frame. Tools are built into the GUI to aid in
defining the features of the whisker of interest. This whisker tracking algorithm relies on a neural network that detects *points* on the
image rather than lines. Consequently, we need to describe whisker traces as discrete points
to use the neural network.

#. Click the *Trace* button (blue candidate whisker traces should appear)
#. If a representative whisker is present, select it with the mouse by clicking the blue trace for the whisker of interest (It should turn red).
#. At the base of the whisker, there will be a collection of green open circles bunched together. These are the "discrete points" selected to describe the whisker.
#. Open the Discrete Points window by going to *Extras* --> *Discretization*
#. Adjust the *Number of Points* and *Spacing* boxes in the *Discrete Points* window.
#. You should adjust these values until the green dots adequate represent the shape of the whisker. Reasonable values are 20-30 for spacing and 12-14 for number of points

*********************
4. Annotating Frames
*********************

The neural network needs a training dataset. From experience, roughly 100 images are enough for
good performance during activate touch. In general, you should select images to annotate that
are significantly different from one another so that the machine learning algorithm is sufficiently prepared to find the whisker in the remaining frames

#. Use the slider at the bottom (or the arrow keys) to advance forward in the video.
#. When you find a good candidate frame, hit the *trace* button. Blue traces will appear around candidate whiskers.
#. If the traces are acceptable, click the "add frame to tracking" button. A green boundary will appear around the image.
#. Click the whisker of interest. It should appear red and the discrete green points should be automatically calculated and applied.
#. If the tip of the whisker is missing, for instance if the middle is obscured by a pole, you can add discrete points by clicking on the "Add Points" checkbox and clicking along the whisker. Uncheck this box when finished.
#. If the points are incorrect, they can be delete with the "Delete points" button, and you can try tracing again.
#. Repeat the above steps until you have annotated ~100 frames

*If the whiskers overlap, go to "Extras" --> "Tracing" --> "Combine segments", then select the most proximal trace of the true whisker, and the distal part of the true whisker. If this works, you will see the true whisker now entirely in red. When done, unclick the "combine segments" button.*

************************************
5. Pole Annotation and Verification
************************************

Once you have finished annotated your frames, it is good to do the final check of your work,
and perform pole tracing (if necessary).

#. When frames have been labeled, go back to the first annotated frame. You can use the slider at the bottom right that moves through only annotated frames.
#. Open the pole window by going to "Extra" --> "Pole"
#. In each frame that has a pole, click the "select pole location" button and click on the pole in the image (A blue circle should appear)
#. Advance to the next frame and until every tracked frame's pole has been labeled

************************
6. Export to DeepLabCut
************************

This program currently uses DeepLabCut to perform the deep learning step of tracking. This step
outputs the data into a format that deeplabcut can use, and initalizes the network.

#. Go to "Other Programs" --> "DeepLabCut"
#. Click the "Initialize" button (the jupyter notebook will have some output)
#. Check the "with pole button"
#. Click the "export" button

*********************
7. Train the network
*********************

This step will train the neural network to detect the discrete points along the whisker. This step takes approximately
*6 hours*, so set aside time accordingly.

#. Click the "Create Training Data" button to create a training dataset for the neural network
#. You may want to use different starting weights for your network (for instance a network trained on a different animal). Load these by clicking the "load" button
#. Navigate to the previous DLC weights you want to use. They should be located in a path like "dlc-models\iteration-0\Whisker_TrackJul16-trainset95shuffle1\train\snapshot-200000.index"
#. The name of this file should now appear as the listed starting weights
#. Click the "Train" button

***********************
8. Analyze Entire Video
***********************

Once you have a trained neural network, you can use it to predict the whisker point locations for all of the frames
in your video.

#. If you need to select a trained neural network (for instance, if I didn't label any frames), you can select the config.yaml file by clicking the "Select Network"
#. Click the Analyze button to process your current video. It will save a .h5 file into the same folder as your video.

**********************
9. Visualize Results
**********************

Now whisker traces have been found for each frame in the video. You can load these whisker traces into the GUI to
inspect their accuracy.
#. Go to File -> "Load DLC Tracked Whiskers"
#. Go to Extras -> Viewer and click the "Tracked Whiskers" checkbox.
#. Scroll through your video and inspect how well the tracking performed.

**********************
10. Process and Export
**********************

Once you have acceptable whisker labels, you can calculate meaningful kinematic and mechanical quantities, and
export these to a .mat file for future analysis.

#. Go to File -> Export...
#. Select the quantities you would like to calculate from your whisker traces
#. Click "Export!" to generate an "output.mat" file in the same directory as your video. This may take >5 minutes to complete
