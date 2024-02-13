# Add Elevation and Height Above Ground

MoveApps

Github repository: *github.com/movestore/Add_Elevation*

## Description
This App annotates all locations with ground elevation (DEM, 30m resolution) and optionally provides corrected height/altitude values and histograms/stats thereof. Height above ellipsoid can additionally be adapted by geoid height (EGM2008). (R package `elevatr`)

## Documentation
Using the R package `elevatr`, this App appends a ground elevation estimate (DEM) to each location of the data set. We have selected to use DEM from the Amazon Web Services Terrain Tiles at a resolution of 30 m, which is available globally.

In case the `adapt_alt` parameter is set to TRUE, the algorithm detects altitude/height measures in your data (by the phrases `height` or `altitude`) and adapts it by subtracting the DEM estimate from it, i.e. transforming a height above mean sea level to height above ground. It then generates a table of mean and standard deviation (sd) individual adapted altitudes/heights and histograms as well as duration adapted mean and sd individual adapted values. Please note that height measurements of any tracking devices have rather large errors.

If your data contain height above ellispoid, please select the setting `Adapt for height above ellipsoid`. Then your adapted altitude will additioanlly be adapted with a modelled geoid height (i.e. added to it) at each location, to get the true height of your animal. Geoid height is a complex value that differs by region, but has been obtained in 1 arc-minute resolution from the [Earth Gravitational Model 2008 (EGM2008)](https://earth-info.nga.mil/index.php?dir=wgs84&action=wgs84#tab_egm2008). 

Ground elevation, EGM2008 geoid height as well as the adapted height/altitude measure are appended to the input data set and passed on to the next App. Thus, they can be used as attribute parameters there. Furthermore, they can be written as part of the data set to output files if using the rds 2 csv, Write Shapefile, Write GPX or similar Apps.

It is necessary to include the Time Lag Between Locations App before this App in the workflow.

### Input data
move2_location object

### Output data
move2_location object

### Artefacts
`Altitude.adapted.stats.csv`:  table of number of locations, mean and standard deviation adapted height/altitude and (by duration) weighted mean and standard deviation. Values are given per track and overall. (only available if `adapt_alt` is TRUE).

`Histograms_height.above.ellipsoid.adapted.pdf`: histogrammes of altitude/height distribution for each track and overall. If `height_props` are given, the breaks of the histograms are aligned to them, else equidistant (only available if `adapt_alt` is TRUE).

`Thr_prop_adap_Altitude.csv`: table of proportions of locations and durations for each height threshold and track. For each threshold, an average and standard deviation value are given, in addition. (only available if `adapt_alt` is TRUE).

### Settings 
**Adapt altitude (`adapt_alt`):** Select if you want to add a DEM adapted height variable as an additional attribute. Default FALSE. See details above.

**Adapt for height above ellipsoid (`ellipsoid`):** Select if your tracks contain height above ellipsoid measurements. Then the adapted altitude for all locations will also include an addition of local geoid height. Default FALSE.

**Height thresholds for proportional use (`height_props`):** One or more height thresholds (in metre) that you want proportional use calculated for. For multiple values please separate by comma. Default NULL (then no proportional use is calculated).

### Null or error handling:
**Adapt altitude (`adapt_alt`):** If TRUE, problems can occur if the name of the altitude variable does not contain the phrases 'height' or 'altitude'.

**Adapt for height above ellipsoid (`ellipsoid`):** If your tracks are mixes of height above ellipsoid and height above mean sea level, it is not possible to select adaptation of part of the data only. Then, please split your workflow into two workflow instances.

**Height thresholds for proportional use (`height_props`):** If NULL (default), no proportional use is calculated and the histogram breaks become equidistant.

**Data:** The input data set is returned with one or two additional attributes. Should not lead to errors. 
