library('move')
library('sp')
library('progress')
library('elevatr')
library('terra')

rFunction <- function(data,adapt_alt=FALSE,height_props=NULL,ellipsoid=FALSE)
{
  Sys.setenv(tz="UTC")
  
  data$ground.elevation<-get_elev_point(SpatialPoints(coordinates(data)), projection(data), src="aws")$elevation
  #get_elev_point(data, src="aws")$elevation
  logger.info("The variable ground.elevation was added to your data.")
  
  geoid <- terra::rast('us_nga_egm2008_1.tif')
  ann <- terra::extract(geoid,data.frame(coordinates(data)))
  data$egm08.geoid <- ann$us_nga_egm2008_1
  
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
          if (ellipsoid==FALSE)
            {
              hei_adap <- data@data[,hei] - data@data$ground.elevation
              logger.info("You have selected that your data are height above mean sea level, so no geoid adaption was performed.")
            } else 
            {
              hei_adap <- data@data[,hei] - data@data$ground.elevation + data@data$egm08.geoid
              logger.info("You have selected that your data are height above ellipsoid, so geoid adaptation (using the EGM2008 model) was performed for true heights.")
            }
          data@data <- cbind(data@data,hei_adap)
          adap_name <- paste0(names(data@data)[hei],".adapted")
          names(data@data)[which(names(data@data)=="hei_adap")] <- adap_name
          logger.info(paste("The variable",names(data)[hei],"was adapted by elevation. The new variable name is called:",adap_name))

          data.split <- move::split(data)
        
          ids <- namesIndiv(data)
          n <- length(ids)
          alt_table <- data.frame("trackId"=c(ids,"all"),"n.pts"=numeric(n+1),"mean.pts.height.adapted"=numeric(n+1),"sd.pts.height.adapted"=numeric(n+1),"mean.dur.height.adapted"=numeric(n+1),"sd.dur.height.adapted"=numeric(n+1))
          
          if (is.null(height_props)) 
          {
            logger.info ("You have not provided any height thresholds. No file for height proportions will be created.")
            
            pdf(paste0(Sys.getenv(x = "APP_ARTIFACTS_DIR", "/tmp/"), "Histograms_",adap_name,".pdf"),width=12,height=8)
            lapply(data.split, function(z){
              topl <- z@data[,adap_name]
              if(all(is.na(topl))){
                logger.info(paste("There are no altitudes annotated for", rownames(idData(data)),", therefore no histogram is produced for this individual."))
                return(NULL)
              }
              hist(topl,xlim=c(quantile(topl,probs=0.01,na.rm=TRUE),quantile(topl,probs=0.99,na.rm=TRUE)),breaks=length(topl)/10,main=paste("Histogramme of", namesIndiv(z)),xlab=adap_name,freq=FALSE,col="blue")
            })
            toplA <- data@data[,adap_name]
            hist(toplA,xlim=c(quantile(toplA,probs=0.01,na.rm=TRUE),quantile(toplA,probs=0.99,na.rm=TRUE)),breaks=length(toplA)/10,main="Histogramme of all tracks",freq=FALSE,col="red",xlab=adap_name)
            dev.off()
            
          } else
          {
            if (is.null(data@data[,"timelag"])) logger.info("The variable 'timelag' is missing in your data set. Please make sure to run the Time Lag Between Locations App (and Adapt Time Lag for Regular Gaps App) before in your Workflow. Duration weighted height statistics cannot be provided.")
            
            hei_props <- sort(as.numeric(trimws(strsplit(as.character(height_props),",")[[1]])),decreasing=FALSE)
            n.prop <- length(hei_props)
            logger.info (paste0("You have provided the following height thresholds: ",paste(hei_props,collapse=", "),". A propotions file will be generated and the histograms' breaks will be adapted to the thresholds."))
            
            prop_table <- data.frame("trackId"=rep(c(ids,"mean","sd"),each=n.prop),"height_threshold"=rep(hei_props,times=n+2),"n.loc"=numeric((n+2)*n.prop),"prop.locs"=numeric((n+2)*n.prop),"prop.dur"=numeric((n+2)*n.prop))
            n.loc <- prop.loc <- prop.dur <- numeric(n.prop)
            
            for (i in seq(along=data.split))
            {
              datai <- data.split[[i]]
              ix <- which(prop_table$trackId==namesIndiv(datai))
              hei_adap_i <- datai@data[,adap_name]
              dur_i <- datai@data[,"timelag"] # from TimeLag App
              
              for (j in seq(along=hei_props))
              {
                ixj <- which(hei_adap_i<hei_props[j])
                n.loc[j] <- length(ixj)
                if (n.loc[j]>0) 
                  {
                  prop.loc[j] <- n.loc[j]/length(datai)
                  prop.dur[j] <- sum(dur_i[ixj],na.rm=TRUE)/sum(dur_i,na.rm=TRUE)
                } else prop.loc[j] <- prop.dur[j] <- NA
              }
              
              prop_table[which(prop_table$trackId==namesIndiv(datai)),3:5] <- data.frame(n.loc,prop.loc,prop.dur)
            }
            
          for (k in seq(along=hei_props))
            {
              ixk <- which(prop_table$height_threshold==hei_props[k] & prop_table$trackId %in% ids)
              prop_table[which(prop_table$trackId=="mean" & prop_table$height_threshold==hei_props[k]),3] <- length(prop_table$n.loc[ixk])
              prop_table[which(prop_table$trackId=="mean" & prop_table$height_threshold==hei_props[k]),4] <- mean(prop_table$prop.loc[ixk],na.rm=TRUE)
              prop_table[which(prop_table$trackId=="mean" & prop_table$height_threshold==hei_props[k]),5] <- mean(prop_table$prop.dur[ixk],na.rm=TRUE)
              
              prop_table[which(prop_table$trackId=="sd" & prop_table$height_threshold==hei_props[k]),3] <- length(prop_table$n.loc[ixk])
              prop_table[which(prop_table$trackId=="sd" & prop_table$height_threshold==hei_props[k]),4] <- sd(prop_table$prop.loc[ixk],na.rm=TRUE)
              prop_table[which(prop_table$trackId=="sd" & prop_table$height_threshold==hei_props[k]),5] <- sd(prop_table$prop.dur[ixk],na.rm=TRUE)
            }
            write.csv(prop_table,paste0(Sys.getenv(x = "APP_ARTIFACTS_DIR", "/tmp/"), "Thr_prop_adap_",adap_name,".csv"),row.names=FALSE)
            
            # adapted breaks for hei_props
            pdf(paste0(Sys.getenv(x = "APP_ARTIFACTS_DIR", "/tmp/"), "Histograms_",adap_name,".pdf"),width=12,height=8)
            lapply(data.split, function(z){
              topl <- z@data[,adap_name]
              if (any(!is.na(topl)))
              {
                min_topl <- min(topl,na.rm=TRUE)
                max_topl <- max(topl,na.rm=TRUE)
                hist(topl,xlim=c(quantile(topl,probs=0.01,na.rm=TRUE),quantile(topl,probs=0.99,na.rm=TRUE)),breaks=c(min_topl,0,hei_props,max_topl),main=paste("Histogramme of", namesIndiv(z)),xlab=adap_name,freq=FALSE,col="blue",ylab="Probability density")
              }
            })
            toplA <- data@data[,adap_name]
            if (any(!is.na(toplA)))
            {
              min_toplA <- min(toplA,na.rm=TRUE)
              max_toplA <- max(toplA,na.rm=TRUE)
              hist(toplA,xlim=c(quantile(toplA,probs=0.01,na.rm=TRUE),quantile(toplA,probs=0.99,na.rm=TRUE)),breaks=c(min(toplA,na.rm=TRUE),0,hei_props,max(toplA,na.rm=TRUE)),main="Histogramme of all tracks",freq=FALSE,col="red",xlab=adap_name,ylab="Probability density")
            }
            dev.off()
            
          }

          # now same for both cases
          
          for (i in seq(along=data.split))
          {
            datai <- data.split[[i]]
            ix <- which(alt_table$trackId==namesIndiv(datai))
            hei_adap_i <- datai@data[,adap_name]
            alt_table$mean.pts.height.adapted[ix] <- mean(hei_adap_i,na.rm=TRUE)
            alt_table$sd.pts.height.adapted[ix] <- sd(hei_adap_i,na.rm=TRUE)
            dur_i <- as.numeric(datai@data[,"timelag"]) # from TimeLag App
            mu_i <- sum(hei_adap_i*dur_i,na.rm=TRUE)/sum(dur_i,na.rm=TRUE)
            alt_table$mean.dur.height.adapted[ix] <- mu_i
            alt_table$sd.dur.height.adapted[ix] <- sqrt(sum((hei_adap_i-mu_i)*(hei_adap_i-mu_i)*dur_i,na.rm=TRUE)/sum(dur_i,na.rm=TRUE)) #sqrt(weighted variance)
            alt_table$n.pts[ix] <- length(hei_adap_i[!is.na(hei_adap_i)])
          }

          alt_table$mean.pts.height.adapted[n+1] <- mean(hei_adap,na.rm=TRUE)
          alt_table$sd.pts.height.adapted[n+1] <- sd(hei_adap,na.rm=TRUE)
          dur <- as.numeric(data@data[,"timelag"])
          mu <- sum(hei_adap*dur,na.rm=TRUE)/sum(dur,na.rm=TRUE)
          alt_table$mean.dur.height.adapted[n+1] <- mu
          alt_table$sd.dur.height.adapted[n+1] <- sqrt(sum((hei_adap-mu)*(hei_adap-mu)*dur,na.rm=TRUE)/sum(dur,na.rm=TRUE))
          alt_table$n.pts[n+1] <- length(hei_adap[!is.na(hei_adap)])
          write.csv(alt_table,paste0(Sys.getenv(x = "APP_ARTIFACTS_DIR", "/tmp/"), "Adapted.stats",adap_name,".csv"),row.names=FALSE)
        }
      }
    } else logger.info("There are no height or altitude variables in your data set.")

  } else logger.info ("You did not select to adapt height or altitude.")

  result <- data
  return(result)
}

  
  
  
  
  
  
  
  
  
  
