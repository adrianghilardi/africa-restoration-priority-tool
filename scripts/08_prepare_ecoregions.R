suppressPackageStartupMessages({library(terra);library(jsonlite);library(digest)})
args<-commandArgs(TRUE)
if(length(args)!=2L)stop('Usage: Rscript scripts/08_prepare_ecoregions.R config/portable.json ../ecoregions')
cfg<-fromJSON(args[1],simplifyVector=FALSE)
root<-normalizePath(args[2],winslash='/',mustWork=TRUE)
manifest<-fromJSON(file.path(root,'source_manifest.json'))
archive<-file.path(root,'raw/Ecoregions2017.zip')
if(digest(archive,file=TRUE,algo='sha256')!=manifest$sha256)stop('Ecoregion archive checksum mismatch')
dir.create(file.path(root,"scratch"),showWarnings=FALSE)
terraOptions(progress=0,memfrac=.2,tempdir=file.path(root,"scratch"))
members<-unzip(archive,list=TRUE)$Name
shapefile<-members[grepl('[.]shp$',members,ignore.case=TRUE)]
if(length(shapefile)!=1L)stop('Expected exactly one provider shapefile in verified archive')
eco<-vect(paste0('/vsizip/',normalizePath(archive,winslash='/'),'/',shapefile))
stopifnot(all(c("ECO_ID","ECO_NAME")%in%names(eco)))
eco<-eco[,intersect(c("ECO_ID","ECO_NAME","LICENSE"),names(eco))]
if("LICENSE"%in%names(eco) && any(!grepl("CC.BY",eco$LICENSE,ignore.case=TRUE)))stop("Unexpected ecoregion licence")
if(!all(is.valid(eco)))eco<-makeValid(eco)
allmeta<-list()
for(reg in c("congo","kaza")){
  message("Preparing ",reg)
  maskpath<-file.path(cfg$data_dir,reg,"mask_c.tif")
  reference<-rast(maskpath)
  bounds<-project(as.polygons(ext(reference),crs=crs(reference)),crs(eco))
  selected<-crop(eco,bounds)
  if(!nrow(selected))stop("Empty ecoregion selection")
  if(!all(is.valid(selected)))selected<-makeValid(selected)
  selected<-project(selected,crs(reference))
  selected<-crop(selected,ext(reference))
  selected$ID<-selected$ECO_ID
  if(!all(is.valid(selected)))selected<-makeValid(selected)
  outdir<-file.path(root,"prepared",reg)
  dir.create(outdir,recursive=TRUE,showWarnings=FALSE)
  output<-file.path(outdir,"mofuss_ecoregions_fr.gpkg")
  if(file.exists(output))stop("Prepared geometry exists")
  writeVector(selected,output,layer="ecoregions_resolve2017",overwrite=FALSE)
  allmeta[[reg]]<-list(region=reg,source="RESOLVE Ecoregions 2017",license="CC-BY-4.0",
    output=paste0(reg,"/mofuss_ecoregions_fr.gpkg"),sha256=digest(output,file=TRUE,algo="sha256"),
    features=nrow(selected),ecoregion_ids=as.integer(sort(unique(selected$ECO_ID))),
    model_bounds=as.vector(ext(reference)),model_crs=crs(reference,proj=TRUE),
    reference_grid_sha256=digest(maskpath,file=TRUE,algo="sha256"),
    processing="Select/crop original provider geometry to model rectangular extent; reproject to model CRS; repair geometry where needed. No country boundaries or GADM used. Final tool intersects these with authorized TNC interest zones.")
  message("Written ",nrow(selected)," features: ",output)
}
write_json(allmeta,file.path(root,"prepared","preparation_manifest.json"),pretty=TRUE,auto_unbox=TRUE)
capture.output(sessionInfo(),file=file.path(root,"prepared","R_sessionInfo.txt"))
