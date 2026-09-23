# Prepare native-resolution climate layers and TNC-zone summaries.
# Rscript scripts/03_prepare_climate.R config/climate_portable.json
suppressPackageStartupMessages({library(terra);library(jsonlite);library(digest)})
args<-commandArgs(TRUE)
if(length(args)!=1)stop("Supply config/climate_portable.json")
options(warn=1)
cfg<-fromJSON(args[1],simplifyVector=FALSE)
dir.create(cfg$scratch_dir,recursive=TRUE,showWarnings=FALSE)
terraOptions(tempdir=cfg$scratch_dir,memfrac=.2,progress=0)
dest<-file.path(cfg$storage_dir,if(is.null(cfg$processed_subdir))"processed"else cfg$processed_subdir)
if(dir.exists(dest))stop("Processed climate directory exists; choose another version to preserve outputs")
manifest<-fromJSON(file.path(cfg$storage_dir,"download_manifest.json"))
expected_files<-length(cfg$variables)*(1L+length(cfg$scenarios)*length(cfg$periods)*length(cfg$percentiles))
if(nrow(manifest)!=expected_files)stop("Climate manifest does not match the configured selection")
expected_units<-c(tas="degC",pr="mm",cdd="days")
for(i in seq_len(nrow(manifest))){
 p<-file.path(cfg$storage_dir,manifest$path[i])
 if(!file.exists(p)||file.info(p)$size!=manifest$bytes[i]||
    digest(p,algo="sha256",file=TRUE)!=manifest$sha256[i])stop("Input checksum failed: ",p)
}
dir.create(dest,recursive=TRUE)
write_tif<-function(r,p)writeRaster(r,p,overwrite=FALSE,
 wopt=list(datatype="FLT4S",gdal=c("COMPRESS=DEFLATE","TILED=YES")))
read_variable<-function(row){
 r<-rast(file.path(cfg$storage_dir,row$path))
 tag<-paste0(row$product,"-",row$variable,"-annual-mean")
 idx<-which(names(r)==tag)
 if(length(idx)!=1)stop("Expected one climate data variable: ",tag)
 value<-r[[idx]]
 if(units(value)!=expected_units[row$variable])stop("Unexpected physical units in ",row$path)
 if(any(abs(res(value)-.25)>1e-8)||!is.lonlat(value))stop("Unexpected native climate grid")
 value
}
manifest$units<-unname(expected_units[manifest$variable])
all_zonal<-list();qa<-list();metadata<-list()
zone_layers<-c("zone_of_interest_all","zone_of_influence_all","zone_of_ops_all")
# Copy only the named regional geometries needed to reproduce the summaries.
zones<-list()
for(reg in cfg$regions){
 zones[[reg$id]]<-list()
 for(layer in zone_layers){
  v<-vect(cfg$tnc_zones,layer=layer)
  v<-v[grepl(reg$tnc_pattern,v$Name),]
  if(!nrow(v))stop("Missing TNC zone: ",reg$id," ",layer)
  if(!all(is.valid(v)))v<-makeValid(v)
  v<-project(v,"EPSG:4326")
  zones[[reg$id]][[layer]]<-v
 }
}
for(reg in cfg$regions){
 message("Preparing native climate for ",reg$id)
 out<-file.path(dest,reg$id);dir.create(out)
 if(!is.null(reg$bounds_wgs84)){
  bb<-unlist(reg$bounds_wgs84,use.names=FALSE)
  if(length(bb)!=4L||any(!is.finite(bb))||bb[1]>=bb[2]||bb[3]>=bb[4])stop("Invalid regional bounds")
  bounds<-ext(bb)
 }else{
  ref<-rast(file.path(reg$source_dir,"LULCC/TempRaster/mask_c.tif"))
  bb<-as.vector(ext(project(as.polygons(ext(ref),crs=crs(ref)),"EPSG:4326")))
  for(v in zones[[reg$id]]){
   e<-as.vector(ext(v));bb<-c(min(bb[1],e[1]),max(bb[2],e[2]),min(bb[3],e[3]),max(bb[4],e[4]))
  }
  bounds<-ext(bb+c(-.25,.25,-.25,.25))
 }
 write_json(as.vector(bounds),file.path(out,"region_bounds_wgs84.json"),pretty=TRUE)
 # Geometry intersections depend only on the native grid, not on the variable.
 template<-crop(read_variable(manifest[1,]),bounds,snap="out")
 area<-cellSize(template,unit="km");names(area)<-"area_km2"
 weights<-lapply(zones[[reg$id]],function(v)extract(area,v,cells=TRUE,exact=TRUE))
 for(i in seq_len(nrow(manifest))){
  row<-manifest[i,]
  value<-crop(read_variable(row),bounds,snap="out")
  if(!compareGeom(value,template,stopOnError=FALSE))stop("Climate grids differ")
  name<-sub("[.]nc$",".tif",basename(row$path))
  write_tif(value,file.path(out,name))
  values_vector<-values(value,mat=FALSE)
  for(layer in zone_layers){
   v<-zones[[reg$id]][[layer]]
   w<-weights[[layer]]
   covered<-weighted<-numeric(nrow(v))
   for(j in seq_len(nrow(v))){
    take<-which(w$ID==j)
    vv<-values_vector[w$cell[take]];ww<-w$area_km2[take]*w$fraction[take]
    valid<-is.finite(vv)&is.finite(ww)
    covered[j]<-sum(ww[valid]);weighted[j]<-sum(ww[valid]*vv[valid])
   }
   full_area<-expanse(v,unit="km")
   all_zonal[[length(all_zonal)+1L]]<-data.frame(region=reg$id,zone_layer=layer,
    zone_name=v$Name,variable=row$variable,units=row$units,scenario=row$scenario,
    period=row$period,product=row$product,gridcell_ensemble_statistic=row$percentile,
    area_weighted_mean=ifelse(covered>0,weighted/covered,NA_real_),
    climate_covered_km2=covered,zone_km2=full_area,
    coverage_fraction=covered/full_area)
  }
  if(row$product=="anomaly" && row$percentile=="median"){
   raw<-rast(file.path(cfg$storage_dir,row$path))
   idx<-which(names(raw)==paste0("anomalysignificance-",row$variable,"-annual-mean"))
   if(length(idx)==1){
    sig<-crop(raw[[idx]],bounds,snap="out")
    # CCKP encodes robust change as missing in the significance variable.
    # Only recover that class where the corresponding anomaly is finite.
    sig<-ifel(is.na(value),NA,ifel(is.na(sig),3,sig))
    names(sig)<-"change_significance_code"
    write_tif(sig,file.path(out,sub(".tif$","_significance.tif",name)))
   }
  }
  stats<-global(value,c("min","max"),na.rm=TRUE)
  metadata[[length(metadata)+1L]]<-data.frame(region=reg$id,path=file.path(reg$id,name),
    variable=row$variable,product=row$product,scenario=row$scenario,period=row$period,
    percentile=row$percentile,units=row$units,nrow=nrow(value),ncol=ncol(value),
    xres=res(value)[1],yres=res(value)[2],min=stats[1,"min"],max=stats[1,"max"])
 }
 for(variable in unlist(cfg$variables))for(scenario in unlist(cfg$scenarios))for(period in unlist(cfg$periods)){
  paths<-vapply(c("p10","median","p90"),function(q)file.path(out,paste0("anomaly-",variable,
    "-annual-mean_",cfg$collection,"_ensemble-all-",scenario,"_climatology_",q,"_",period,".tif")),character(1))
  q<-rast(paths)
  bad<-global(ifel(q[[1]]>q[[2]]+1e-6 | q[[2]]>q[[3]]+1e-6,1,0),"sum",na.rm=TRUE)[1,1]
  complete<-global(ifel(!is.na(q[[1]]) & !is.na(q[[2]]) & !is.na(q[[3]]),1,0),"sum",na.rm=TRUE)[1,1]
  qa[[length(qa)+1L]]<-data.frame(region=reg$id,variable=variable,scenario=scenario,period=period,
    complete_native_cells=complete,percentile_order_errors=bad)
  if(!is.finite(bad)||bad>0||complete<1)stop("Climate percentile validation failed")
 }
 # Mid-century exposure maps, preserving the original climate cell sizes.
 primary<-zones[[reg$id]][["zone_of_interest_all"]]
 plotrs<-list()
 for(variable in unlist(cfg$variables))for(scenario in unlist(cfg$scenarios)){
  p<-file.path(out,paste0("anomaly-",variable,"-annual-mean_",cfg$collection,
   "_ensemble-all-",scenario,"_climatology_median_2040-2059.tif"))
  plotrs[[paste(variable,scenario)]]<-mask(crop(rast(p),primary,snap="out"),primary,touches=TRUE)
 }
 png(file.path(out,paste0(reg$id,"_climate_context_2040_2059.png")),width=2700,height=1800,res=180)
 par(mfrow=c(2,3),mar=c(2.6,2.6,3.5,4.5),oma=c(4,0,3,0),bg="white")
 for(scenario in unlist(cfg$scenarios))for(variable in unlist(cfg$variables)){
  rr<-plotrs[[paste(variable,scenario)]]
  pair<-c(plotrs[[paste(variable,"ssp245")]],plotrs[[paste(variable,"ssp585")]])
  lim<-range(global(pair,c("min","max"),na.rm=TRUE),finite=TRUE)
  if(variable!="tas")lim<-c(-1,1)*max(abs(lim))
  cols<-if(variable=="tas")hcl.colors(80,"YlOrRd",rev=TRUE)else
    if(variable=="pr")hcl.colors(81,"BrBG")else hcl.colors(81,"BrBG",rev=TRUE)
  title<-c(tas="Temperature change",pr="Rainfall change",cdd="Longest dry-spell change")[variable]
  plot(rr,col=cols,range=lim,axes=TRUE,main=paste(title,if(scenario=="ssp245")"SSP2-4.5"else"SSP5-8.5",sep="\n"),
   plg=list(title=expected_units[variable],cex=.85),cex.axis=.75)
  lines(primary,col="#303b35",lwd=.8)
 }
 mtext(paste(reg$name,"| Mid-century climate exposure"),outer=TRUE,side=3,line=.8,cex=1.6,font=2)
 mtext("2040-2059 minus 1995-2014 | World Bank CCKP CMIP6 ensemble median | Native 0.25-degree cells",
  outer=TRUE,side=1,line=.8,cex=.85)
 mtext("Climate context for regional screening; projections are not a calibrated prediction of biomass recovery.",
  outer=TRUE,side=1,line=2.3,cex=.85)
 dev.off()
}
write.csv(do.call(rbind,all_zonal),file.path(dest,"tnc_zone_climate_summary.csv"),row.names=FALSE)
write.csv(do.call(rbind,qa),file.path(dest,"climate_quality_checks.csv"),row.names=FALSE)
write.csv(do.call(rbind,metadata),file.path(dest,"layer_inventory.csv"),row.names=FALSE)
write.csv(data.frame(code=0:3,meaning=c("no data","no significant change","conflicting model signals","robust change where anomaly exists")),
 file.path(dest,"significance_legend.csv"),row.names=FALSE)
write.csv(manifest,file.path(dest,"source_manifest.csv"),row.names=FALSE)
capture.output(sessionInfo(),file=file.path(dest,"R_sessionInfo.txt"))
message("COMPLETE: ",dest)
