# WhiskerTracking.jl

This is a collection of methods for whisker tracking and whisker kinetic/kinematic analysis. Right now, this is probably not very usable outside of my hands as a package, but hopefullly will become more refined. Briefly, the tracking methods include:

1) A wrapper for the Janelia Whisker Tracker https://github.com/nclack/whisk. Basically, this package provides wrappers for automatic tracking and manual tracking, uses a Julia-based GUI, and adds some features like image processing, face masking etc. The heavy lifting is done by Janelia.

2) A wrapper for DeeplabCut https://github.com/AlexEMG/DeepLabCut. Here you can transform a collection of fully tracked whiskers into a discrete set of equally spaced points, reformat these into the format that deeplabcut expects, use deeplabcut to process your videos, then perform polynomial fits on the discrete points to get whisker traces.  I also use DLC for stimuli tracking (e.g. the pole).

There is also a collection of analysis methods for whiskers. These include

1) Hilbert transform for calculating whisker phase and amplitude. https://www.ncbi.nlm.nih.gov/pmc/articles/PMC3717360/

2) Calculation of forces/moments at the whisker follicle from http://www.jneurosci.org/content/33/16/6726. 

## Installation

I have only used this on Linux. If you want to use the janelia methods, you will need to probably compile the tracker from source to get a .so (or DLL on Windows, but I haven't tried this), and change the hard coded library path in the code to the appropriate folder on your computer. I am also relying on FFMPEG (https://ffmpeg.org/) to decode videos, and have the filepath location hard coded.

## Future Directions

I would love for the Janelia methods to be in pure Julia to no longer rely on their library. My impression is that it should run just as fast in pure julia, and would not be too tedious of a code migration. 

I have found a lot of success in using janelia to "pre-train" a deeplabcut neural network by automatically tracing data, changing it into a format deeplabcut can use, and then letting deeplabcut doing all of the tracking and linking. Right now this process is pretty clunky, and I basically have to switch back and forth between DLC notebooks and Julia notebooks. All of this should be integrated better.
