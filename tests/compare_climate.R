# Compare two processing runs without the original MoFuSS drives.
# Rscript tests/compare_climate.R reference_processed new_processed
suppressPackageStartupMessages({library(terra);library(jsonlite)})
args<-commandArgs(TRUE)
if(length(args)!=2)stop("Supply reference and new processed climate directories")
a<-read.csv(file.path(args[1],"tnc_zone_climate_summary.csv"))
b<-read.csv(file.path(args[2],"tnc_zone_climate_summary.csv"))
stopifnot(identical(a[,1:8],b[,1:8]))
difference<-max(abs(a$area_weighted_mean-b$area_weighted_mean),na.rm=TRUE)
stopifnot(is.finite(difference),difference<1e-8)
qa<-read.csv(file.path(args[2],"climate_quality_checks.csv"))
stopifnot(nrow(qa)==24,all(qa$percentile_order_errors==0))
inv<-read.csv(file.path(args[1],"layer_inventory.csv"))
stopifnot(nrow(inv)==78)
all_tifs<-list.files(args[1],pattern="[.]tif$",recursive=TRUE)
stopifnot(length(all_tifs)>=nrow(inv))
for(p in all_tifs){
 x<-rast(file.path(args[1],p));y<-rast(file.path(args[2],p))
 stopifnot(compareGeom(x,y,stopOnError=FALSE),global(abs(x-y),"max",na.rm=TRUE)[1,1]==0,
   global(is.na(x)!=is.na(y),"sum",na.rm=TRUE)[1,1]==0)
}
result<-list(status="PASS",regional_value_rasters=78,percentile_checks=24,
 all_rasters_including_significance=length(all_tifs),nodata_masks_identical=TRUE,
 max_zonal_mean_difference=difference,reference=normalizePath(args[1],winslash="/"),
 comparison=normalizePath(args[2],winslash="/"))
write_json(result,file.path(args[2],"comparison_check.json"),pretty=TRUE,auto_unbox=TRUE)
cat("All",length(all_tifs),"climate value/significance rasters and nodata masks reproduce exactly; maximum mean difference:",difference,"\n")
