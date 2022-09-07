# Add Elevation

MoveApps

Github repository: *github.com/movestore/Add_Elevation*

## Description
This App annotates all locations with ground elevation (DEM, 30m resolution) and optionally provides corrected height/altitude values and histograms/stats thereof. Careful if using height above ellipsoid, there is no adaption included yet. (R package `elevatr`)

## Documentation
Using the R package `elevatr`, this App is appending a ground elevation estimate (DEM) to each location of the data set. We have selected to use DEM from the Amazon Web Services Terrain Tiles at a resolution of 30 m, which is available globally.

In case the `adapt_alt` parameter is set TRUE, the algorithm detects altitude/height measures in your data (by the phrases `height` or `altitude`) and adapts it by subtracting the DEM estimate from it, i.e. transforming a height above mean sea level to height above ground. It then generates a table of mean and sd individual adapted altitudes/heights and histograms as well as duration adapted mean and sd individual adapted values. Please note that height measurements of any tracking devices have rather large errors.

Note that if your data contain height above ellispoid, they will be used in this App, but height above ground is not adapted to it. It is planned to update this App with such a functionality. Mean sea level height can be calculated as height above ellipsoid minus the interpolated geoid height at the specified location. Geoid height is a complex value that differs by region, but can be obtained from the [Earth Gravitational Model 2008 (EGM2008)](https://earth-info.nga.mil/index.php?dir=wgs84&action=wgs84#tab_egm2008). 

Ground elevation as well as the adapted height/altittude measure are appended to the input data set and passed on to the next App. Thus, they can be used as attribute parameter there. Furthermore, they can be written as part of the data set to output files if using the rds 2 csv, Write Shapefile, Write GPX or similar Apps.

It is necessary to include the Time Lag Between Locations App before this App in the workflow.

### Input data
moveStack in Movebank format

### Output data
moveStack in Movebank format

### Artefacts
`Altitude.adapted.stats.csv`:  table of number of locations, mean and standard deviation adapted height/altitude and (by duration) weighted mean and standard deviation. Values are given per track and overall. (only available if `adapt_alt` is TRUE).

`Histograms_height.above.ellipsoid.adapted.pdf`: histogrammes of altitude/height distribution for each track and overall. If `height_props` are given, the breaks of the histograms are aligned to them, else equidistant (only available if `adapt_alt` is TRUE).

`Thr_prop_adap_Altitude.csv`: table of proportions of locations and durations for each height threshold and track. For each threshold, an average and standard deviation value are given, in addition. (only available if `adapt_alt` is TRUE).

`last_loctime`: Select this option if your data were collected with a regular daily gap (e.g. no locations at night). This leads the App to calculate duration weighted altitudes/heights using the adapted `timelag2` that is weighting the last location before the gap with the median data resolution instead of the long gap time interval. Depending on your required data property and how the animal(s) behave during the gap (e.g. night - flying or not?) either one or the other might be sensible. Note that (in addition to the Time Lag Between Locations App) you need to add the Adapt Time Lag for Regular Gaps App to your workflow before, if you want to use this feature.

### Parameters 
`adapt_alt`: Select if you want to add as additional attribute a DEM adapted height variable. Default FALSE. See details above.

`height_props`: One or more height thresholds (in metre) that you want proportional use calculated for. For multiple values please separate by comma. Default NULL (then no proportional use is calculated).

### Null or error handling:
**Parameter `adapt_alt`:** If TRUE, problems can occur if the name of the altitude variable does not contain the phrases 'height' or 'altitude'.

**Parameter `height_props`: ** If NULL (default), no proportional use is calculated and the histograms# breaks become equidistant.

**Data:** The input data set is returned with one or two additional attributes. Should not lead to errors. 
