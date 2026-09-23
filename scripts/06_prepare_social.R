# Native-resolution population pathways and national poverty context.
# Run from code root: Rscript scripts/06_prepare_social.R config/social.json
suppressPackageStartupMessages({library(terra);library(jsonlite);library(digest)})
args<-commandArgs(TRUE)
if(length(args)!=1L)stop("Supply config/social.json")
options(warn=1)
script_arg<-grep("^--file=",commandArgs(FALSE),value=TRUE)
script_root<-dirname(dirname(normalizePath(sub("^--file=","",script_arg),winslash="/")))
source(file.path(script_root,"R/social_core.R"))
cfg<-fromJSON(args[1],simplifyVector=FALSE)
dir.create(cfg$scratch_dir,recursive=TRUE,showWarnings=FALSE)
terraOptions(tempdir=cfg$scratch_dir,memfrac=.15,progress=0)
dest<-file.path(cfg$storage_dir,if(is.null(cfg$processed_subdir))"processed"else cfg$processed_subdir)
if(dir.exists(dest))stop("Output exists; choose a new processed_subdir")
manifest<-fromJSON(file.path(cfg$storage_dir,"download_manifest.json"))
for(i in seq_len(nrow(manifest))){
 p<-file.path(cfg$storage_dir,manifest$path[i])
 if(!file.exists(p)||digest(p,algo="sha256",file=TRUE)!=manifest$sha256[i])stop("Social input checksum failed: ",p)
}
pop_manifest<-manifest[manifest$kind=="population",]
if(nrow(pop_manifest)!=length(cfg$periods)*length(cfg$scenarios))stop("Unexpected population selection")
poverty<-read.csv(file.path(cfg$storage_dir,"national_poverty_latest.csv"),stringsAsFactors=FALSE)
if(anyDuplicated(poverty$iso3))stop("Duplicate national poverty keys")
if(any(poverty$poverty_pct<0 | poverty$poverty_pct>100,na.rm=TRUE))stop("Poverty rate outside 0-100")
for(s in cfg$poverty_sensitivities)social_proxy(1,1,s$rate_multiplier)
dir.create(dest,recursive=TRUE)
write.csv(data.frame(input="tnc_zones.gpkg",sha256=digest(cfg$tnc_zones,algo="sha256",file=TRUE)),
 file.path(dest,"geography_manifest.csv"),row.names=FALSE)
country_zip<-normalizePath(file.path(cfg$storage_dir,"raw/ne_50m_admin_0_countries.zip"),winslash="/")
countries<-vect(paste0("/vsizip/",country_zip,"/ne_50m_admin_0_countries.shp"))
countries<-countries[,c("ISO_A3_EH","ADMIN")];names(countries)<-c("iso3","country")
countries<-makeValid(project(countries,"EPSG:4326"))
zone_layers<-c("zone_of_interest_all","zone_of_influence_all","zone_of_ops_all")
summary_rows<-list();country_rows<-list();qa_rows<-list();inventory<-list()
write_tif<-function(r,p)writeRaster(r,p,overwrite=FALSE,wopt=list(datatype="FLT4S",gdal=c("COMPRESS=DEFLATE","TILED=YES")))
extract_weights<-function(area,polygons){
 w<-extract(area,polygons,cells=TRUE,exact=TRUE)
 w$weight_km2<-w$area_km2*w$fraction
 w
}
sum_population<-function(density,w,n){
 vv<-values(density,mat=FALSE)
 do.call(rbind,lapply(seq_len(n),function(i){
  ix<-which(w$ID==i);d<-vv[w$cell[ix]];a<-w$weight_km2[ix]
  ok<-is.finite(d)&d>=0&is.finite(a)&a>=0
  data.frame(population=if(any(ok))sum(d[ok]*a[ok])else NA_real_,covered_km2=sum(a[ok]))
 }))
}
for(reg in cfg$regions){
 message("Preparing social context: ",reg$id)
 out<-file.path(dest,reg$id);dir.create(out)
 zones<-lapply(zone_layers,function(layer){
  v<-vect(cfg$tnc_zones,layer=layer);v<-v[grepl(reg$tnc_pattern,v$Name),]
  if(!nrow(v))stop("Missing TNC zone: ",reg$id," ",layer)
  v<-makeValid(project(v,"EPSG:4326"));v<-v[,"Name"];v$zone_id<-seq_len(nrow(v));v
 });names(zones)<-zone_layers
 primary<-zones[[1]]
 bb<-as.vector(ext(primary))
 for(v in zones){e<-as.vector(ext(v));bb<-c(min(bb[1],e[1]),max(bb[2],e[2]),min(bb[3],e[3]),max(bb[4],e[4]))}
 bounds<-ext(bb+c(-.25,.25,-.25,.25))
 raw_ref<-rast(file.path(cfg$storage_dir,pop_manifest$path[1]))
 ref<-crop(raw_ref,bounds,snap="out");units(ref)<-units(raw_ref)
 if(nlyr(ref)!=1L || names(ref)!="climatology-popdensity-annual-mean" ||
    units(ref)!="persons per km2" || any(abs(res(ref)-.25)>1e-8) || !is.lonlat(ref))stop("Unexpected population units/grid")
 area<-cellSize(ref,unit="km");names(area)<-"area_km2"
 region_countries<-crop(countries,bounds)
 weights<-lapply(zones,function(v)extract_weights(area,v))
 country_zones<-lapply(zones,function(v)intersect(region_countries,v))
 country_weights<-lapply(country_zones,function(v)extract_weights(area,v))
 writeVector(region_countries,file.path(out,"national_context_boundaries.gpkg"),overwrite=FALSE)
 for(i in seq_len(nrow(pop_manifest))){
  row<-pop_manifest[i,];raw_r<-rast(file.path(cfg$storage_dir,row$path))
  r<-crop(raw_r,bounds,snap="out");units(r)<-units(raw_r)
  if(!compareGeom(ref,r,stopOnError=FALSE))stop("Population grids differ")
  if(units(r)!="persons per km2" || names(r)!="climatology-popdensity-annual-mean")stop("Unexpected population variable")
  lim<-global(r,c("min","max"),na.rm=TRUE)
  if(!is.finite(lim[1,"min"])||lim[1,"min"]<0)stop("Invalid population densities")
  name<-paste0("population_density_",row$scenario,"_",row$period,"_persons_km2.tif")
  write_tif(r,file.path(out,name))
  inventory[[length(inventory)+1L]]<-data.frame(region=reg$id,path=file.path(reg$id,name),scenario=row$scenario,
    period=row$period,units="persons per km2",resolution_degrees=.25,min=lim[1,"min"],max=lim[1,"max"])
  for(layer in zone_layers){
   z<-zones[[layer]];cz<-country_zones[[layer]]
   totals<-sum_population(r,weights[[layer]],nrow(z))
   ct<-sum_population(r,country_weights[[layer]],nrow(cz))
   rates<-poverty[match(cz$iso3,poverty$iso3),]
   base<-data.frame(region=reg$id,zone_layer=layer,zone_name=cz$Name,zone_id=cz$zone_id,
    iso3=cz$iso3,country=cz$country,population_scenario=row$scenario,population_period=row$period,
    modelled_population=ct$population,population_covered_km2=ct$covered_km2,
    national_poverty_pct=rates$poverty_pct,national_observation_year=rates$observation_year,
    poverty_indicator="SI.POV.DDAY",poverty_line="3.00 USD/day, 2021 PPP",
    poverty_geography="national rate; not measured within the TNC zone")
   for(s in cfg$poverty_sensitivities){
    b<-base;b$poverty_sensitivity<-s$id;b$rate_multiplier<-s$rate_multiplier
    b$poverty_exposure_proxy_not_beneficiaries<-social_proxy(b$modelled_population,b$national_poverty_pct,s$rate_multiplier)
    country_rows[[length(country_rows)+1L]]<-b
    for(j in seq_len(nrow(z))){
     sub<-b[b$zone_id==j,];valid<-is.finite(sub$poverty_exposure_proxy_not_beneficiaries)
     covered_pop<-sum(sub$modelled_population[valid],na.rm=TRUE)
     ptotal<-totals$population[j]
     fraction<-if(is.finite(ptotal)&&ptotal>0)covered_pop/ptotal else NA_real_
     proxy<-if(is.finite(fraction)&&fraction>=.99)sum(sub$poverty_exposure_proxy_not_beneficiaries[valid])else NA_real_
     yrs<-sub$national_observation_year[valid]
     summary_rows[[length(summary_rows)+1L]]<-data.frame(region=reg$id,zone_layer=layer,zone_name=z$Name[j],
      population_scenario=row$scenario,population_period=row$period,modelled_population=ptotal,
      population_covered_km2=totals$covered_km2[j],zone_km2=expanse(z[j,],unit="km"),
      poverty_sensitivity=s$id,rate_multiplier=s$rate_multiplier,
      population_with_national_poverty_context=covered_pop,national_context_population_coverage=fraction,
      population_weighted_national_poverty_context_pct=social_weighted_rate(sub$modelled_population,sub$national_poverty_pct)*s$rate_multiplier,
      poverty_exposure_proxy_not_beneficiaries=proxy,
      oldest_national_observation=if(length(yrs))min(yrs)else NA_integer_,
      newest_national_observation=if(length(yrs))max(yrs)else NA_integer_,
      interpretation="Uniform national-rate assumption; sensitivity, not a poverty forecast or restoration benefit")
    }
   }
   for(j in seq_len(nrow(z))){
    ct_sum<-sum(ct$population[cz$zone_id==j],na.rm=TRUE)
    discrepancy<-if(totals$population[j]>0)ct_sum/totals$population[j]-1 else NA_real_
    qa_rows[[length(qa_rows)+1L]]<-data.frame(region=reg$id,zone_layer=layer,zone_name=z$Name[j],scenario=row$scenario,
     period=row$period,country_intersection_population_relative_difference=discrepancy,
     population_area_coverage=totals$covered_km2[j]/expanse(z[j,],unit="km"))
    if(is.finite(discrepancy)&&abs(discrepancy)>.02)stop("Country boundary coverage differs by >2%; inspect social geography")
   }
  }
 }
 # Population remains on its native cells; poverty is shown only as national bars.
 png(file.path(out,paste0(reg$id,"_population_and_poverty_context.png")),width=2400,height=2000,res=170)
 layout(matrix(c(1,2,3,3),nrow=2,byrow=TRUE),heights=c(1.25,1))
 par(mar=c(3.5,3.4,5,6),oma=c(4.5,0,3.5,0),bg="white")
 popmaps<-lapply(c("ssp245","ssp585"),function(s)mask(crop(rast(file.path(out,paste0("population_density_",s,"_2040-2059_persons_km2.tif"))),primary),primary,touches=TRUE))
 upper<-max(vapply(popmaps,function(x)global(x,"max",na.rm=TRUE)[1,1],numeric(1)))
 for(j in 1:2){
  plot(log10(popmaps[[j]]+1),range=c(0,log10(upper+1)),col=hcl.colors(80,"YlOrRd",rev=TRUE),
   main=paste("Mid-century population",c("SSP2 demographic pathway","SSP5 demographic pathway")[j],sep="\n"),
   plg=list(title="log10(density + 1)",cex=.7),cex.axis=.75,cex.main=.95,mar=c(3.5,3.4,5,6))
  lines(primary,lwd=.7,col="#303b35")
 }
 primary_iso<-unique(country_zones[[1]]$iso3)
 plotp<-poverty[match(primary_iso,poverty$iso3),];plotp<-plotp[is.finite(plotp$poverty_pct),]
 plotp<-plotp[order(plotp$poverty_pct),]
 par(mar=c(5,10,3,3))
 barplot(plotp$poverty_pct,names.arg=paste0(plotp$iso3," (",plotp$observation_year,")"),horiz=TRUE,las=1,
  col="#3e7464",border=NA,xlim=c(0,100),xlab="National population below $3.00/day (2021 PPP), %",
  main="Latest available national poverty observations (country code and survey/reference year)",cex.names=.85)
 mtext(paste(reg$name,"| Population and poverty context"),outer=TRUE,side=3,line=.7,cex=1.45,font=2)
 mtext("Population: CCKP / Jones & O'Neill SSP data, 2040-2059 period mean, native 0.25 degrees.",outer=TRUE,side=1,line=.5,cex=.8)
 mtext("Poverty: World Bank WDI/PIP. National observations are not current local poverty rates or restoration benefits.",outer=TRUE,side=1,line=1.8,cex=.8)
 dev.off()
}
write.csv(do.call(rbind,summary_rows),file.path(dest,"tnc_zone_social_scenarios.csv"),row.names=FALSE,na="")
write.csv(do.call(rbind,country_rows),file.path(dest,"tnc_zone_country_social_context.csv"),row.names=FALSE,na="")
write.csv(do.call(rbind,qa_rows),file.path(dest,"social_quality_checks.csv"),row.names=FALSE,na="")
write.csv(do.call(rbind,inventory),file.path(dest,"layer_inventory.csv"),row.names=FALSE)
write_json(cfg,file.path(dest,"preparation_config.json"),pretty=TRUE,auto_unbox=TRUE)
capture.output(sessionInfo(),file=file.path(dest,"R_sessionInfo.txt"))
message("COMPLETE: ",dest)
