# Rebuild open administrative boundary inputs without reading GADM geometry.
# Usage: Rscript scripts/06_prepare_boundaries.R config/portable.json boundaries select|prepare
suppressPackageStartupMessages({library(terra);library(jsonlite);library(digest)})
if(.Platform$OS.type=='windows')suppressWarnings(Sys.setlocale('LC_CTYPE','English_United States.utf8'))
args<-commandArgs(TRUE)
if(length(args)!=3L)stop('Usage: Rscript scripts/06_prepare_boundaries.R config/portable.json boundaries select|prepare')
cfg<-fromJSON(args[1],simplifyVector=FALSE)
root<-normalizePath(args[2],winslash='/',mustWork=TRUE)
mode<-args[3]
if(!mode%in%c('select','prepare'))stop('Mode must be select or prepare')
manifest<-read.csv(file.path(root,if(mode=='select')'manifest_countries.csv'else'manifest_adm1.csv'),stringsAsFactors=FALSE)
for(i in seq_len(nrow(manifest))){
 for(kind in c('geometry','metadata')){
  p<-file.path(root,if(kind=='geometry')manifest$path[i]else manifest$metadata_path[i])
  expected<-if(kind=='geometry')manifest$sha256[i]else manifest$metadata_sha256[i]
  if(!file.exists(p)||digest(p,algo='sha256',file=TRUE)!=expected)stop('Boundary source checksum mismatch: ',p)
 }
}
dir.create(file.path(root,'processed'),showWarnings=FALSE)
tnc_all<-vect(file.path(cfg$data_dir,'tnc_zones.gpkg'),layer='zone_of_interest_all')
regions<-list(); selections<-list(); diagnostics<-list(); inventory<-list()
for(reg in cfg$regions){
 ref<-rast(file.path(cfg$data_dir,reg$id,'mask_c.tif'))
 tnc<-tnc_all[if(reg$id=='congo')grepl('^Congo',tnc_all$Name)else tnc_all$Name=='KAZA',]
 if(!nrow(tnc))stop('Missing TNC interest polygon for ',reg$id)
 tnc<-project(tnc,crs(ref));if(!all(is.valid(tnc)))tnc<-makeValid(tnc)
 er<-as.vector(ext(ref));et<-as.vector(ext(tnc))
 ee<-ext(min(er[1],et[1]),max(er[2],et[2]),min(er[3],et[3]),max(er[4],et[4]))
 domain<-as.polygons(ee,crs=crs(ref))
 # Buffer the candidate-selection envelope only; output boundaries use ee.
 search_domain<-buffer(domain,10000)
 if(mode=='select'){
  candidates<-list.files(file.path(root,'raw'),pattern='_ADM0$',full.names=TRUE)
  take<-character()
  for(d in candidates){
   meta<-fromJSON(file.path(d,'metadata.json'))
   v<-vect(file.path(d,'boundary_simplified.geojson'))
   v<-project(v,crs(ref));if(!all(is.valid(v)))v<-makeValid(v)
   hit<-relate(v,search_domain,'intersects')
   if(any(hit)){
    take<-c(take,meta$boundaryISO)
    interest_hit<-relate(v,tnc,'intersects')
    selections[[length(selections)+1L]]<-data.frame(region=reg$id,iso=meta$boundaryISO,country=meta$boundaryName,intersects_tnc_interest=any(interest_hit),selection_rule='Model/TNC union extent plus 10-km country-selection buffer')
   }
  }
  regions[[reg$id]]<-sort(unique(take))
  message(reg$id,': ',paste(regions[[reg$id]],collapse=', '))
 }else{
  selected<-fromJSON(file.path(root,'selected_countries.json'),simplifyVector=FALSE)[[reg$id]]
  pieces<-list()
  for(iso in unlist(selected)){
   d<-file.path(root,'raw',paste0(iso,'_ADM1'))
   meta<-fromJSON(file.path(d,'metadata.json'))
   v<-vect(file.path(d,'boundary.geojson'))
   required<-c('shapeID','shapeName','shapeGroup')
   if(!all(required%in%names(v)))stop('Unexpected geoBoundaries schema for ',iso)
   if(any(v$shapeGroup!=iso))stop('Unexpected country codes for ',iso)
   v<-project(v,crs(ref));if(!all(is.valid(v)))v<-makeValid(v)
   v<-crop(v,domain)
   if(!nrow(v))next
   vv<-as.data.frame(v)
   values(v)<-data.frame(GID_0=iso,NAME_0=meta$boundaryName,GID_1=as.character(vv$shapeID),NAME_1=as.character(vv$shapeName),stringsAsFactors=FALSE)
   pieces[[length(pieces)+1L]]<-v
  }
  combined<-do.call(rbind,pieces)
  combined<-combined[order(combined$GID_0,combined$GID_1),]
  if(anyDuplicated(combined$GID_1))stop('Duplicate geoBoundaries shapeIDs')
  combined$ID<-seq_len(nrow(combined))
  combined<-combined[,c('ID','GID_0','NAME_0','GID_1','NAME_1')]
  dest<-file.path(root,'processed',reg$id)
  dir.create(dest,showWarnings=FALSE)
  p<-file.path(dest,'mofuss_adm1_fr.gpkg')
  if(file.exists(p))stop('Output exists; choose a new boundaries directory: ',p)
  writeVector(combined,p,filetype='GPKG',overwrite=FALSE)
  coverage_geom<-aggregate(combined)
  covered<-intersect(tnc,coverage_geom)
  tnc_area<-sum(expanse(tnc,unit='ha'))
  coverage<-if(nrow(covered))sum(expanse(covered,unit='ha'))else 0
  diagnostics[[length(diagnostics)+1L]]<-data.frame(region=reg$id,adm1_units=nrow(combined),countries=paste(sort(unique(combined$GID_0)),collapse=';'),tnc_interest_ground_ha=tnc_area,admin_covered_ground_ha=coverage,tnc_coverage_fraction=coverage/tnc_area,all_valid=all(is.valid(combined)))
  inventory[[length(inventory)+1L]]<-data.frame(region=reg$id,path=substring(p,nchar(root)+2L),bytes=file.info(p)$size,sha256=digest(p,algo='sha256',file=TRUE))
  message(reg$id,': ',nrow(combined),' ADM1 units, ',round(100*coverage/tnc_area,4),'% TNC coverage')
 }
}
if(mode=='select'){
 write_json(regions,file.path(root,'selected_countries.json'),pretty=TRUE,auto_unbox=FALSE)
 write.csv(do.call(rbind,selections),file.path(root,'country_selection.csv'),row.names=FALSE)
}else{
 write.csv(do.call(rbind,diagnostics),file.path(root,'coverage_checks.csv'),row.names=FALSE)
 write.csv(do.call(rbind,inventory),file.path(root,'manifest_processed.csv'),row.names=FALSE)
 capture.output(sessionInfo(),file=file.path(root,'preparation_session.txt'))
}
