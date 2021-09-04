

Kinematic and Mechanical Quantification
#########################################


Here we outline the different behavioral features of whisking that can be calculated from
whisker videos. We also provide background on how these are calculated in the WhiskerTracking.jl
package. Many of these features do not have consensus of how they should be calculated in the
literature, and we will try our best to highlight potential advantages and pitfalls to the
approaches that we have selected here.

Whisker Angle
--------------

.. image:: media/mouse_angle.png

The whisker angle is in a coordinate system where the axis perpendicular to the axis
of the head is equal to 0. More protracted (toward the nose) positions are positive,
while more retracted (toward the tail) are negative. The angle is calculated in this
coordinate system as the angle between a vector extending from the whisker follicle (x_f,y_f) to a
point along the whisker shaft (x_2,y_2), and the axis indicating 0 (dashed line).

Pitfalls
~~~~~~~~~

Whisker Curvature
------------------


Whisker Phase
--------------
