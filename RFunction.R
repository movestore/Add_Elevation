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
          alt_table <- data.frame("trackId"=c(ids,"all"),"n.pts"=numeric(n+1),"mean.pts.height.adapted"=numeric(n+1),"sd.pts.height.adapted"=numeric(n+1),"mean.dur.height.adapted"=numeric(n+1),"sd.dur.height.adapted"=numeric(n+1))
          
          pdf(paste0(Sys.getenv(x = "APP_ARTIFACTS_DIR", "/tmp/"), "Histograms_",adap_name,".pdf"),width=12,height=8)
          lapply(data.split, function(z){
            topl <- z@data[,adap_name]
            hist(topl,xlim=c(quantile(topl,probs=0.01,na.rm=TRUE),quantile(topl,probs=0.99,na.rm=TRUE)),breaks=length(topl)/10,main=paste("Histogramme of", namesIndiv(z)),xlab=adap_name,freq=FALSE,col="blue")
          })
          toplA <- data@data[,adap_name]
          hist(toplA,xlim=c(quantile(toplA,probs=0.01,na.rm=TRUE),quantile(toplA,probs=0.99,na.rm=TRUE)),breaks=length(toplA)/10,main="Histogramme of all tracks",freq=FALSE,col="red",xlab=adap_name)
          dev.off()
          
          for (i in seq(along=data.split))
          {
            datai <- data.split[[i]]
            ix <- which(alt_table$trackId==namesIndiv(datai))
            hei_adap_i <- datai@data[,adap_name]
            alt_table$mean.pts.height.adapted[ix] <- mean(hei_adap_i,na.rm=TRUE)
            alt_table$sd.pts.height.adapted[ix] <- sd(hei_adap_i,na.rm=TRUE)
            dur_i <- datai@data$timelag # from TimeLag App
            mu_i <- sum(hei_adap_i*dur_i,na.rm=TRUE)/sum(dur_i,na.rm=TRUE)
            alt_table$mean.dur.height.adapted[ix] <- mu_i
            alt_table$sd.dur.height.adapted[ix] <- sqrt(sum((hei_adap_i-mu_i)*(hei_adap_i-mu_i)*dur_i,na.rm=TRUE)/sum(dur_i,na.rm=TRUE)) #sqrt(weighted variance)
            alt_table$n.pts[ix] <- length(hei_adap_i[!is.na(hei_adap_i)])
          }

          alt_table$mean.pts.height.adapted[n+1] <- mean(hei_adap,na.rm=TRUE)
          alt_table$sd.pts.height.adapted[n+1] <- sd(hei_adap,na.rm=TRUE)
          if (is.null(data@data$timelag)) logger.info("The variable 'timelag' is missing in your data set. Please make sure to run the Time Lag Between Locations App before in your Workflow. Duration weighted height statistics cannot be provided.")
          dur <- data@data$timelag 
          mu <- sum(hei_adap*dur,na.rm=TRUE)/sum(dur,na.rm=TRUE)
          alt_table$mean.dur.height.adapted[n+1] <- mu
          alt_table$sd.dur.height.adapted[n+1] <- sqrt(sum((hei_adap-mu)*(hei_adap-mu)*dur,na.rm=TRUE)/sum(dur,na.rm=TRUE))
          alt_table$n.pts[n+1] <- length(hei_adap[!is.na(hei_adap)])
          write.csv(alt_table,paste0(Sys.getenv(x = "APP_ARTIFACTS_DIR", "/tmp/"), "Altitude.adapted.stats.csv"),row.names=FALSE)
        }
      }
    } else logger.info("There are no height or altitude variables in your data set.")

  } else logger.info ("You did not select to adapt height or altitude.")

  result <- data
  return(result)
}

  
  
  
  
  
  
  
  
  
  
