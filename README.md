# WhiskerTracking.jl

This is a collection of methods for whisker tracking and whisker kinetic/kinematic analysis. Right now, this is probably not very usable outside of my hands as a package, but hopefullly will become more refined. Briefly, it includes the following capabilities:

### Manual video curation, whisker identification, and selection.

A GUI can be used to scroll through large whisker tracking videos. A wrapper is provided for the Janelia Whisker Tracker https://github.com/nclack/whisk to manually identify whiskers on a single frame. Some image processing algorithms are provided such as sharpening filters or contrast adjustment.

### Whisker and pole prediction using deep learning

A stacked hourglass network (https://github.com/paulmthompson/StackedHourglass.jl) to predict individual pixels that correspond to unique whiskers. Default weights from a large training dataset are provided that should automatically work on fairly clean whisker videos, but the user has the ability to add more training frames to the dataset.

### Analysis of whisker kinematics and kinetics

There is also a collection of analysis methods for whiskers. These include

1) Hilbert transform for calculating whisker phase and amplitude. https://www.ncbi.nlm.nih.gov/pmc/articles/PMC3717360/

2) Calculation of forces/moments at the whisker follicle from http://www.jneurosci.org/content/33/16/6726. 

## Documentation

https://whiskertrackingjl.readthedocs.io/en/latest/

