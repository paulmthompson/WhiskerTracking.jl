
#################
Contact Detection
#################

Contact detection can be done either before or after whisker tracking has been completed, as they are saved in different locations


*********
Overview
*********
#. Open Whisker Tracking GUI
#. Click on "File"->"Load Video" and navigate to your mp4 file
#. Click on "Contact Detection"->"Classifier for Prediction". A window will pop open that will allow you to see the amount of frames you have trained as you identify contact throughout the video
#. In the Whisker Tracking GUI, go through the video and "mark contact" or "mark no contact" depending on if the pole touches the whisker or not
#. Watch the classifier and try to label ~1000 or more frames
#. When completed, click on "Contact Detection" at the top of the GUI, go to "Training Labels" and then click on "Save contact labels"
#. The file will save as a .mat file
