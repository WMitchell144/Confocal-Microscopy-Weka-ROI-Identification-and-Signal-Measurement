# Confocal-microscopy-Weka-ROI-identification-and-Signal-measurement

This series of Fiji Macros use a previously created Weka model to identify regions of interest (ROIs) in confocal microscopy images and measure the signal within those ROIs. The macros automate the process of loading images, applying the Weka model, and extracting quantitative data from the identified ROIs.

A second MAcro generates a background control by selecting a large number of square ROIs acrosss the image and measuring the signal within those ROIs. The background control can be used to normalize the signal measurements from the identified ROIs.