library('move')
library('sp')
library('progress')
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
    hei_ix <- c(height_ix,altitude_ix)
    
    if (length(hei_ix)>0)
    {
      for (hei in hei_ix)
      {
        if (all(is.na(data@data[hei]))) logger.info(paste("The variable",names(data)[hei],"contains only NA values. Therefore, no elevation-adapted variable is calculated.")) else
        {
          hei_adap <- data@data[,hei] - data@data$ground.elevation
          data@data <- cbind(data@data,hei_adap)
          adap_name <- paste0(names(data@data)[hei],".adapted")
          names(data@data)[which(names(data@data)=="hei_adap")] <- adap_name
          logger.info(paste("The variable",names(data)[hei],"was adapted by elevation. The new variable name is called:",adap_name))
          
          data.split <- move::split(data)
          ids <- namesIndiv(data)
          n <- length(ids)
          alt_table <- data.frame("trackId"=c(ids,"all"),"n.pts"=numeric(n+1),"mean.height.adapted"=numeric(n+1),"sd.height.adapted"=numeric(n+1))
          
          pdf(paste0(Sys.getenv(x = "APP_ARTIFACTS_DIR", "/tmp/"), "Histograms_",adap_name,".pdf"),width=12,height=8)
          lapply(data.split, function(z){
            topl <- z@data[,adap_name]
            hist(topl,xlim=c(quantile(topl,probs=0.01,na.rm=TRUE),quantile(topl,probs=0.99,na.rm=TRUE)),breaks=length(topl)/10,main=paste("Histogramme of", namesIndiv(z)),xlab=names(hei_adap),freq=FALSE,col="blue")
          })
          toplA <- data@data[,adap_name]
          hist(toplA,xlim=c(quantile(toplA,probs=0.01,na.rm=TRUE),quantile(toplA,probs=0.99,na.rm=TRUE)),breaks=length(toplA)/10,main="Histogramme of all tracks",freq=FALSE,col="red",xlab=names(hei_adap))
          dev.off()
          
          for (i in seq(along=data.split))
          {
            datai <- data.split[[i]]
            ix <- which(alt_table$trackId==namesIndiv(datai))
            hei_adap_i <- datai@data[,adap_name]
            alt_table$mean.height.adapted[ix] <- mean(hei_adap_i,na.rm=TRUE)
            alt_table$sd.height.adapted[ix] <- sd(hei_adap_i,na.rm=TRUE)
            alt_table$n.pts[ix] <- length(hei_adap_i[!is.na(hei_adap_i)])
          }

          alt_table$mean.height.adapted[n+1] <- mean(hei_adap,na.rm=TRUE)
          alt_table$sd.height.adapted[n+1] <- sd(hei_adap,na.rm=TRUE)
          alt_table$n.pts[n+1] <- length(hei_adap[!is.na(hei_adap)])
          write.csv(alt_table,paste0(Sys.getenv(x = "APP_ARTIFACTS_DIR", "/tmp/"), "Altitude.adapted.stats.csv"),row.names=FALSE)
        }
      }
    } else logger.info("There are no height or altitude variables in your data set.")

  } else logger.info ("You did not select to adapt height or altitude.")

  result <- data
  return(result)
}

  
  
  
  
  
  
  
  
  
  
