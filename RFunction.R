library('move')
library('sp')
library('elevatr')

rFunction <- function(data,adapt_alt=FALSE)
{
  Sys.setenv(tz="UTC")
  
  data_locs <- data.frame(coordinates(data))
  names(data_locs) <- c("x","y")
  
  elev <- get_elev_point(data_locs, prj = projection(data), src = "aws")$elevation
  
  data@data <- cbind(data@data,"ground.elevation"=elev)
  logger.info("The variable ground.elevation was added to your data.")
  
  if (adapt_alt==TRUE)
  {
    height_ix <- grep("height",names(data))
    altitude_ix <- grep("altitude",names(data))
    
    if (length(height_ix>0))
    {
      for (hei in height_ix)
      {
        if (all(is.na(data@data[hei]))) logger.info(paste("The variable",names(data)[hei],"contains only NA values. Therefore, no elevation-adapted variable is calculated.")) else
        {
          hei_adap <- data@data[hei] - data@data$ground.elevation
          names(hei_adap) <- paste0(names(data)[hei],".adapted")
          data@data <- cbind(data@data,hei_adap)
          logger.info(paste("The variable",names(data)[hei],"was adapted by elevation. The new variable name is called:",names(hei_adap)))
        }
      }
    }
    
    if (length(altitude_ix>0))
    {
      for (hei in altitude_ix)
      {
        if (all(is.na(data@data[hei]))) logger.info(paste("The variable",names(data)[hei],"contains only NA values. Therefore, no elevation-adapted variable is calculated.")) else
        {
          hei_adap <- data@data[hei] - data@data$ground.elevation
          names(hei_adap) <- paste0(names(data)[hei],".adapted")
          data@data <- cbind(data@data,hei_adap)
          logger.info(paste("The variable",names(data)[hei],"was adapted by elevation. The new variable name is called:",names(hei_adap)))
        }
      }
    }
    
    if (length(height_ix)==0 & length(altitude_ix)==0) logger.info("There are no height or altitude variables in your data set.")
        
  }

  result <- data
  return(result)
}

  
  
  
  
  
  
  
  
  
  
