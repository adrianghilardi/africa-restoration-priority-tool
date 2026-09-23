# Produce a portable, minimal input bundle from the specified MoFuSS runs.
suppressPackageStartupMessages({library(terra);library(jsonlite);library(digest)})
arg<-grep("^--file=",commandArgs(),value=TRUE)
source(file.path(dirname(dirname(normalizePath(sub("^--file=","",arg),winslash="/"))),"R","core.R"))
cfg<-read_config()
options(warn=1)
# Fail before creating the release directory if any required source is absent.
required<-cfg$tnc_zones
for(reg in cfg$regions){
 root<-reg$source_dir
 yrs<-read.table(file.path(root,"LULCC/TempTables/annos.txt"),header=TRUE)[,1]
 codes<-frame_for_year(c(cfg$investment_start_year,cfg$branch_year,cfg$end_year),yrs)
 db<-list.dirs(root,recursive=FALSE,full.names=TRUE)
 db<-db[grepl("^debugging_[0-9]+$",basename(db))]
 if(!length(db))stop("No realizations in ",root)
 if(is.null(reg$adm1_path)||is.null(reg$ecoregions_path))stop("Provide open-licensed adm1_path and ecoregions_path; legacy run geometries are not redistributed")
 required<-c(required,file.path(root,"LULCC/TempRaster",c("A_c.tif","k_c.tif","m_c.tif","LULCt1_c.tif","mask_c.tif")),
  file.path(root,"LULCC/TempTables",c("annos.txt","growth_parameters1.csv","InputPara.csv","Resolution.csv")),
  reg$adm1_path,reg$ecoregions_path,
  file.path(root,"LULCC/DownloadedDatasets/SourceDataGlobal/parameters.csv"))
 for(d in db)required<-c(required,file.path(d,sprintf("Growth%02d.tif",codes[1])),
  file.path(d,sprintf("Growth_less_harv%02d.tif",codes[2:3])),
  file.path(d,sprintf("Harvest_tot%02d.tif",seq.int(codes[1],codes[3]))))
 nominal_ha<-read.csv(file.path(root,"LULCC/TempTables/Resolution.csv"))$x[1]^2/10000
 if(abs(nominal_ha-cfg$source_mass_divisor_ha)>1e-8)stop("Model mass divisor differs from nominal resolution")
}
required<-unique(c(required,file.path(cfg$ctrees_dir,sprintf("ctrees_global_%d_AGC.tif",c(2000,2025)))))
if(any(!file.exists(required)))stop("Missing input(s): ",paste(required[!file.exists(required)],collapse="; "))
if(any(file.info(required)$size<=0))stop("Empty input file")
message("Preflight passed for ",length(required)," source files")
dir.create(cfg$scratch_dir,recursive=TRUE,showWarnings=FALSE)
terraOptions(tempdir=cfg$scratch_dir,memfrac=.25,progress=0)
if(dir.exists(cfg$data_dir))stop("Data destination already exists; choose a new version directory")
dir.create(cfg$data_dir,recursive=TRUE)
provenance<-list()
record<-function(path,role,region,hash=TRUE) {
 provenance[[length(provenance)+1L]]<<-data.frame(region=region,role=role,path=normalizePath(path,winslash="/"),bytes=file.info(path)$size,
 sha256=if(hash)digest(path,algo="sha256",file=TRUE)else NA_character_)
}
copy_input<-function(src,dst,role,reg) {
 if(!file.exists(src))stop("Missing source: ",src)
 if(!file.copy(src,dst,overwrite=FALSE))stop("Copy failed: ",src)
 record(src,role,reg)
 if(digest(dst,algo="sha256",file=TRUE)!=tail(provenance,1)[[1]]$sha256)stop("Copied file differs from source")
}
for(reg in cfg$regions){
 message("Preparing ",reg$id)
 root<-reg$source_dir; dest<-file.path(cfg$data_dir,reg$id);dir.create(dest)
 yearfile<-file.path(root,"LULCC/TempTables/annos.txt")
 years<-read.table(yearfile,header=TRUE)[,1]
 i0<-frame_for_year(cfg$branch_year,years);i1<-frame_for_year(cfg$end_year,years)
 is<-frame_for_year(cfg$investment_start_year,years)
 copy_input(yearfile,file.path(dest,"years.txt"),"year_index",reg$id)
 lookup<-file.path(root,"LULCC/TempTables/growth_parameters1.csv")
 copy_input(lookup,file.path(dest,"landcover_lookup.csv"),"landcover_lookup",reg$id)
 for(n in c("InputPara.csv","Resolution.csv"))copy_input(file.path(root,"LULCC/TempTables",n),file.path(dest,n),n,reg$id)
 # Retain scientific run settings, excluding irrelevant personal report metadata.
 parameter_source<-file.path(root,"LULCC/DownloadedDatasets/SourceDataGlobal/parameters.csv")
 record(parameter_source,"original_run_parameters",reg$id)
 parameters<-read.csv(parameter_source,stringsAsFactors=FALSE)
 parameters<-parameters[!parameters$Var %in% c("nameuser","ads","ads_ctry","DATA FOR PDF REPORT"),]
 write.csv(parameters,file.path(dest,"parameters.csv"),row.names=FALSE)
 for(n in c("A_c.tif","k_c.tif","m_c.tif","LULCt1_c.tif","mask_c.tif")){
  copy_input(file.path(root,"LULCC/TempRaster",n),file.path(dest,n),n,reg$id)
 }
 copy_input(reg$adm1_path,file.path(dest,"mofuss_adm1_fr.gpkg"),"open_adm1_geometry",reg$id)
 copy_input(reg$ecoregions_path,file.path(dest,"mofuss_ecoregions_fr.gpkg"),"open_ecoregion_geometry",reg$id)
 dbg<-list.dirs(root,recursive=FALSE,full.names=TRUE)
 dbg<-dbg[grepl("^debugging_[0-9]+$",basename(dbg))]
 dbg<-dbg[order(as.integer(sub("debugging_","",basename(dbg))))]
 if(!length(dbg))stop("No per-realization yearly outputs")
 for(d in dbg){
  mc<-as.integer(sub("debugging_","",basename(d)))
  message("  realization ",mc)
  copy_input(file.path(d,sprintf("Growth%02d.tif",is)),
    file.path(dest,sprintf("investment_baseline_%d_mc%03d.tif",cfg$investment_start_year,mc)),"investment_pre_harvest_baseline",reg$id)
  for(it in c(i0,i1)){
   src<-file.path(d,sprintf("Growth_less_harv%02d.tif",it))
   copy_input(src,file.path(dest,sprintf("stock_%d_mc%03d.tif",years[it],mc)),"post_harvest_stock",reg$id)
  }
  paths<-file.path(d,sprintf("Harvest_tot%02d.tif",seq.int(i0+1L,i1)))
  if(!all(file.exists(paths)))stop("Incomplete annual harvest series")
  for(p in paths)record(p,"annual_harvest",reg$id)
  rr<-rast(paths);check_same_grid(list(rr[[1]],rast(file.path(dest,"mask_c.tif"))))
  # Retain missing-data semantics: one missing year means an unknown period total.
  total<-app(rr,"sum",na.rm=FALSE,filename=file.path(dest,sprintf("harvest_%d_%d_mc%03d.tif",cfg$branch_year+1,cfg$end_year,mc)),
    overwrite=FALSE,wopt=list(gdal=c("COMPRESS=DEFLATE","TILED=YES")))
  rm(rr,total);gc()
  earlier<-file.path(d,sprintf("Harvest_tot%02d.tif",seq.int(is,i0)))
  for(p in earlier)record(p,"annual_harvest",reg$id)
  # Disjoint earlier years plus the already-summed recovery window equal START..END.
  rr<-rast(c(earlier,file.path(dest,sprintf("harvest_%d_%d_mc%03d.tif",cfg$branch_year+1,cfg$end_year,mc))))
  total<-app(rr,"sum",na.rm=FALSE,filename=file.path(dest,sprintf("harvest_%d_%d_mc%03d.tif",cfg$investment_start_year,cfg$end_year,mc)),
    overwrite=FALSE,wopt=list(gdal=c("COMPRESS=DEFLATE","TILED=YES")))
  rm(rr,total);gc()
 }
 ref<-rast(file.path(dest,"mask_c.tif"))
 # cTrees snapshots supply observed context, not an independent calibration test.
 for(y in c(2000,2025)){
  p<-file.path(cfg$ctrees_dir,sprintf("ctrees_global_%d_AGC.tif",y))
  before<-file.info(p)[,c("size","mtime")]
  record(p,"ctrees_MgCO2_per_ha_global",reg$id)
  obs<-rast(p)
  obs<-crop(obs,project(ext(ref),crs(ref),crs(obs)),snap="out")
  obs<-project(obs,ref,method="bilinear")
  obs<-ifel(obs<0,NA,obs)*(12/44)/cfg$carbon_fraction
  obs<-mask(obs,ref)
  write_tif(obs,file.path(dest,sprintf("observed_%d_MgDM_ha.tif",y)))
  if(!identical(before,file.info(p)[,c("size","mtime")]))stop("Source changed during preparation: ",p)
  rm(obs);gc()
 }
}
# Include only named planning geometries used by this release, with no QGIS styles.
record(cfg$tnc_zones,"tnc_source_zone_layers","both")
for(layer in c("zone_of_interest_all","zone_of_influence_all","zone_of_ops_all")){
 v<-vect(cfg$tnc_zones,layer=layer)
 v<-v[grepl("^Congo",v$Name)|v$Name=="KAZA",c("Name")]
 writeVector(v,file.path(cfg$data_dir,"tnc_zones.gpkg"),layer=layer,insert=layer!="zone_of_interest_all")
}
write.csv(do.call(rbind,provenance),file.path(cfg$data_dir,"source_provenance.csv"),row.names=FALSE)
write_json(cfg,file.path(cfg$data_dir,"preparation_config.json"),pretty=TRUE,auto_unbox=TRUE)
capture.output(sessionInfo(),file=file.path(cfg$data_dir,"preparation_session.txt"))
files<-list.files(cfg$data_dir,recursive=TRUE,full.names=TRUE)
manifest<-data.frame(path=substring(files,nchar(cfg$data_dir)+2L),bytes=file.info(files)$size,
 sha256=vapply(files,function(p)digest(p,algo="sha256",file=TRUE),character(1)))
write.csv(manifest,file.path(cfg$data_dir,"manifest_sha256.csv"),row.names=FALSE)
message("Input bundle complete: ",cfg$data_dir)
