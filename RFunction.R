library('move2')
library('sf')
library('progress')
library('elevatr')
library('terra')
library('units')

#need to update all to move2

rFunction = function(data, adapt_alt=FALSE,height_props=NULL,ellipsoid=FALSE) 
  {
  locs <- as.data.frame(st_coordinates(data))
  names(locs) <- c("x","y")
  locs_sf <- st_as_sf(x=locs,coords=c("x","y"), crs=st_crs(data))
  
  data$ground.elevation<-get_elev_point(locs_sf, st_crs(data), src="aws")$elevation
  units(data$ground.elevation) <- "m"
  
  #get_elev_point(data, src="aws")$elevation
  logger.info("The variable ground.elevation in metre was added to your data.")
  
  egm.file.path <- paste0(getAppFilePath("egm_file"),"us_nga_egm2008_1.tif")
  geoid <- terra::rast(egm.file.path)

  ann <- terra::extract(geoid,locs_sf)
  data$egm08.geoid <- ann$us_nga_egm2008_1
  units(data$egm08.geoid) <- "m"
  logger.info("The variable egm08.geoid in metre was added to your data. This will only be used for adaption if your tracks provide height above ellipsoid.")
  
  if (adapt_alt==TRUE)
  {
    height_ix <- grep("height",names(data))
    altitude_ix <- grep("altitude",names(data))
    hei_ix <- c(height_ix,altitude_ix)

    if (length(hei_ix)>0)
    {
      for (hei in hei_ix)
      {
        #data_hei <- eval(parse(text=paste("data$",names(data)[hei])))
        if (all(is.na(data[[hei]]))) logger.info(paste("The variable",names(data)[hei],"contains only NA values. Therefore, no elevation-adapted variable is calculated.")) else
        {
          if (ellipsoid==FALSE)
          {
            hei_adap <- data[[hei]] - data$ground.elevation
            logger.info("You have selected that your data are height above mean sea level, so no geoid adaption was performed.")
          } else 
          {
            hei_adap <- data[[hei]] - data$ground.elevation + data$egm08.geoid
          }
          data$hei_adap<- hei_adap
          units(data$hei_adap) <- "m"
          adap_name <- paste0(names(data)[hei],".adapted")
          names(data)[which(names(data)=="hei_adap")] <- adap_name
          logger.info(paste("The variable",names(data)[hei],"was adapted by elevation. The new variable is called:",adap_name))
          
          data.split <- split(data, mt_track_id(data))
          
          ids <- unique(mt_track_id(data))
          n <- length(ids)
          alt_table <- data.frame("track"=c(ids,"all"),"n.pts"=numeric(n+1),"mean.pts.height.adapted"=numeric(n+1),"sd.pts.height.adapted"=numeric(n+1),"mean.dur.height.adapted"=numeric(n+1),"sd.dur.height.adapted"=numeric(n+1))
          
          if (is.null(height_props)) 
          {
            logger.info ("You have not provided any height thresholds. No file for height proportions will be created. The histograms will break in regular intervals.")
            
            pdf(appArtifactPath(paste0("Histograms_",adap_name,".pdf")),width=12,height=8)
            lapply(data.split, function(z){
              topl <- as.numeric(z[[adap_name]])
              if(all(is.na(topl))){
                logger.info(paste0("There are no altitudes annotated for ", unique(mt_track_id(z))," (all NA), therefore no histogram is produced for this individual."))
                return(NULL)
              }
              hist(topl,xlim=c(quantile(topl,probs=0.01,na.rm=TRUE),quantile(topl,probs=0.99,na.rm=TRUE)),breaks=length(topl)/10,main=paste("Histogramme of", unique(mt_track_id(z))),xlab=adap_name,freq=FALSE,col="blue")
            })
            toplA <- data[[adap_name]]
            hist(toplA,xlim=c(quantile(toplA,probs=0.01,na.rm=TRUE),quantile(toplA,probs=0.99,na.rm=TRUE)),breaks=length(toplA)/10,main="Histogramme of all tracks",freq=FALSE,col="red",xlab=adap_name)
            dev.off()
            
          } else
          {
            if (!any(names(data)=="timelag")) logger.info("The variable 'timelag' is missing in your data set. Please make sure to run the Time Lag Between Locations App (and Adapt Time Lag for Regular Gaps App) before in your Workflow. Duration weighted height statistics cannot be provided.")
            
            hei_props <- sort(as.numeric(trimws(strsplit(as.character(height_props),",")[[1]])),decreasing=FALSE)
            n.prop <- length(hei_props)
            logger.info (paste0("You have provided the following height thresholds: ",paste(hei_props,collapse=", "),". A propotions file will be generated and the histograms' breaks will be adapted to the thresholds."))

            prop_table <- data.frame("track"=rep(c(ids,"mean","sd"),each=n.prop),"height_threshold"=rep(hei_props,times=n+2),"n.loc"=numeric((n+2)*n.prop),"prop.locs"=numeric((n+2)*n.prop),"prop.dur"=numeric((n+2)*n.prop))
            n.loc <- prop.loc <- prop.dur <- numeric(n.prop)
              
            for (i in seq(along=data.split))
            {
              datai <- data.split[[i]]
              ix <- which(prop_table$track==unique(mt_track_id(datai)))
              hei_adap_i <- as.numeric(datai[[adap_name]])
              if(any(names(data)=="timelag")) dur_i <- datai$timelag # from TimeLag App
              
              for (j in seq(along=hei_props))
              {
                ixj <- which(hei_adap_i<hei_props[j])
                n.loc[j] <- length(ixj)
                if (n.loc[j]>0) 
                {
                  prop.loc[j] <- n.loc[j]/length(datai)
                  if(any(names(data)=="timelag")) prop.dur[j] <- sum(dur_i[ixj],na.rm=TRUE)/sum(dur_i,na.rm=TRUE) else prop.dur[j] <- NA
                } else prop.loc[j] <- prop.dur[j] <- NA
              }
                
              prop_table[which(prop_table$track==unique(mt_track_id(datai))),3:5] <- data.frame(n.loc,prop.loc,prop.dur)
              }
              
              for (k in seq(along=hei_props))
              {
                ixk <- which(prop_table$height_threshold==hei_props[k] & prop_table$track %in% ids)
                prop_table[which(prop_table$track=="mean" & prop_table$height_threshold==hei_props[k]),3] <- length(prop_table$n.loc[ixk])
                prop_table[which(prop_table$track=="mean" & prop_table$height_threshold==hei_props[k]),4] <- mean(prop_table$prop.loc[ixk],na.rm=TRUE)
                prop_table[which(prop_table$track=="mean" & prop_table$height_threshold==hei_props[k]),5] <- mean(prop_table$prop.dur[ixk],na.rm=TRUE)
                
                prop_table[which(prop_table$track=="sd" & prop_table$height_threshold==hei_props[k]),3] <- length(prop_table$n.loc[ixk])
                prop_table[which(prop_table$track=="sd" & prop_table$height_threshold==hei_props[k]),4] <- sd(prop_table$prop.loc[ixk],na.rm=TRUE)
                prop_table[which(prop_table$track=="sd" & prop_table$height_threshold==hei_props[k]),5] <- sd(prop_table$prop.dur[ixk],na.rm=TRUE)
              }
              write.csv(prop_table,appArtifactPath(paste0("Thr_prop_adap_",adap_name,".csv")),row.names=FALSE)
              
            # adapted breaks for hei_props
            pdf(appArtifactPath(paste0("Histograms_",adap_name,".pdf")),width=12,height=8)
            lapply(data.split, function(z){
              topl <- z[[adap_name]]
              if (any(!is.na(topl)))
              {
                min_topl <- min(topl,na.rm=TRUE)
                max_topl <- max(topl,na.rm=TRUE)
                if (min(hei_props)>0) brks <- c(min_topl,0,hei_props,max_topl)
                if (max(hei_props)<0) brks <- c(min_topl,hei_props,0,max_topl) 
                if (min(hei_props)<=0 & max(hei_props)>=0) brks <- c(min_topl,hei_props,max_topl)
                
              hist(topl,xlim=c(quantile(topl,probs=0.01,na.rm=TRUE),quantile(topl,probs=0.99,na.rm=TRUE)),breaks=brks,main=paste("Histogramme of", unique(mt_track_id(z))),xlab=adap_name,freq=FALSE,col="blue",ylab="Probability density")
              }
            })
            toplA <- data[[adap_name]]
            if (any(!is.na(toplA)))
            {
              min_toplA <- min(toplA,na.rm=TRUE)
              max_toplA <- max(toplA,na.rm=TRUE)
              if (min(hei_props)>0) brksA <- c(min_toplA,0,hei_props,max_toplA)
              if (max(hei_props)<0) brksA <- c(min_toplA,hei_props,0,max_toplA) 
              if (min(hei_props)<=0 & max(hei_props)>=0) brksA <- c(min_toplA,hei_props,max_toplA)
              
              hist(toplA,xlim=c(quantile(toplA,probs=0.01,na.rm=TRUE),quantile(toplA,probs=0.99,na.rm=TRUE)),breaks=brksA,main="Histogramme of all tracks",freq=FALSE,col="red",xlab=adap_name,ylab="Probability density")
            }
            dev.off()
            
          }
          
          # now same for both cases
          
          for (i in seq(along=data.split))
          {
            datai <- data.split[[i]]
            ix <- which(alt_table$track==unique(mt_track_id(datai)))
            hei_adap_i <- datai[[adap_name]]
            alt_table$mean.pts.height.adapted[ix] <- mean(hei_adap_i,na.rm=TRUE)
            alt_table$sd.pts.height.adapted[ix] <- sd(hei_adap_i,na.rm=TRUE)
            if (any(names(datai)=="timelag")) 
            {
              dur_i <- as.numeric(datai$timelag) # from TimeLag App
              mu_i <- sum(hei_adap_i*dur_i,na.rm=TRUE)/sum(dur_i,na.rm=TRUE)
              alt_table$mean.dur.height.adapted[ix] <- mu_i
              alt_table$sd.dur.height.adapted[ix] <- sqrt(sum((hei_adap_i-mu_i)*(hei_adap_i-mu_i)*dur_i,na.rm=TRUE)/sum(dur_i,na.rm=TRUE)) #sqrt(weighted variance)
             } else alt_table$mean.dur.height.adapted[ix] <- alt_table$sd.dur.height.adapted[ix] <- NA
            alt_table$n.pts[ix] <- length(hei_adap_i[!is.na(hei_adap_i)])
          }
          
          alt_table$mean.pts.height.adapted[n+1] <- mean(hei_adap,na.rm=TRUE)
          alt_table$sd.pts.height.adapted[n+1] <- sd(hei_adap,na.rm=TRUE)
          if (any(names(data)=="timelag")) 
          {
            dur <- as.numeric(data$timelag)
            mu <- sum(hei_adap*dur,na.rm=TRUE)/sum(dur,na.rm=TRUE)
            alt_table$mean.dur.height.adapted[n+1] <- mu
            alt_table$sd.dur.height.adapted[n+1] <- sqrt(sum((hei_adap-mu)*(hei_adap-mu)*dur,na.rm=TRUE)/sum(dur,na.rm=TRUE))
          } else alt_table$mean.dur.height.adapted[n+1] <- alt_table$sd.dur.height.adapted[n+1] <- NA
          alt_table$n.pts[n+1] <- length(hei_adap[!is.na(hei_adap)])
          write.csv(alt_table,appArtifactPath(paste0("Adapted.stats",adap_name,".csv")),row.names=FALSE)
        }
      }
    } else logger.info("There are no height or altitude variables in your data set.")
    
  } else logger.info ("You did not select to adapt height or altitude.")
  
  result <- data

  # provide my result to the next app in the MoveApps workflow
  return(result)
}
