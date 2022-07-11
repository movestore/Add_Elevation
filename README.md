# Add Elevation

MoveApps

Github repository: *github.com/movestore/Add_Elevation*

## Description
This App annotates all locations with ground elevation (DEM, 30m resolution) and optionally provides corrected height/altitude values and histograms/stats thereof. (R package `elevatr`)

## Documentation
Using the R package `elevatr`, this App is appending a ground elevation estimate (DEM) to each location of the data set. We have selected to use DEM from the Amazon Web Services Terrain Tiles at a resolution of 30 m, which is available globally.

In case the `adapt_alt` parameter is set TRUE, the algorithm detects altitude/height measures in your data (by the phrases `height` or `altitude`) and adapts it by subtracting the DEM estimate from it, i.e. transforming a height above mean sea level to height above ground. It then generates a table of mean and sd individual adapted altitudes/heights and histograms as well as duration adapted mean and sd individual adapted values. Please note that height measurements of any tracking devices have rather large errors.

### Input data
moveStack in Movebank format

### Output data
moveStack in Movebank format

### Artefacts
none

### Parameters 
`adapt_alt`: Select if you want to add as additional attribute a DEM adapted height variable. Default FALSE. See details above.

### Null or error handling:
**Parameter `adapt_alt`:** If TRUE, problems can occur if the name of the altitude variable does not contain the phrases 'height' or 'altitude'.

**Data:** The input data set is returned with one or two additional attributes. Should not lead to errors. 
