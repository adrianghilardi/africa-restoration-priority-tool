# Validate numerical invariants after analysis; does not modify numerical products.
suppressPackageStartupMessages({library(terra);library(jsonlite)})
arg<-grep("^--file=",commandArgs(),value=TRUE)
source(file.path(dirname(dirname(normalizePath(sub("^--file=","",arg),winslash="/"))),"R/core.R"))
cfg<-read_config()
terraOptions(tempdir=cfg$scratch_dir,memfrac=.2,progress=0)
checks<-list()
record<-function(region,test,value,pass){
 checks[[length(checks)+1L]]<<-data.frame(region=region,test=test,value=value,pass=isTRUE(pass))
}
for(reg in cfg$regions){
 out<-file.path(cfg$output_dir,reg$id);input<-file.path(cfg$data_dir,reg$id)
 r<-function(n)rast(file.path(out,n))
 gain<-r("recovery_MgDM_ha_mean.tif");lo<-r("recovery_k075_MgDM_ha_mean.tif");hi<-r("recovery_k125_MgDM_ha_mean.tif")
 eligible<-r("screening_eligibility.tif")
 sumr<-function(x)global(x,"sum",na.rm=TRUE)[1,1]
 minr<-function(x)global(x,"min",na.rm=TRUE)[1,1]
 v<-minr(gain);record(reg$id,"recovery_nonnegative",v,is.finite(v)&&v>=-1e-5)
 v<-sumr(ifel(lo>gain+1e-4|gain>hi+1e-4,1,0));record(reg$id,"growth_sensitivity_order_violations",v,v==0)
 v<-sumr(ifel(!is.na(gain)&(is.na(eligible)|eligible!=1),1,0));record(reg$id,"recovery_outside_screen_cells",v,v==0)
 cls<-r("screening_class.tif")
 v<-sumr(ifel(cls<0|cls>5,1,0));record(reg$id,"invalid_screening_codes",v,v==0)
 N<-r("investment_nrb_MgDM_cell_mean.tif");H<-r("investment_harvest_MgDM_cell_mean.tif")
 v<-minr(N);record(reg$id,"NRB_nonnegative",v,is.finite(v)&&v>=0)
 v<-minr(H);record(reg$id,"harvest_nonnegative",v,is.finite(v)&&v>=0)
 ids<-sort(as.integer(sub(".*_mc([0-9]+)[.]tif$","\\1",list.files(input,sprintf("^stock_%d_mc[0-9]+[.]tif$",cfg$branch_year)))))
 for(mc in ids){
  B<-rast(file.path(input,sprintf("stock_%d_mc%03d.tif",cfg$branch_year,mc)))/cfg$source_mass_divisor_ha
  A<-rast(file.path(input,"A_c.tif"))/cfg$source_mass_divisor_ha
  G<-r(sprintf("recovery_k100_mc%03d_MgDM_ha.tif",mc))
  v<-sumr(ifel(G>ifel(A>B,A-B,0)+1e-3,1,0));record(reg$id,paste0("capacity_violations_mc",mc),v,v==0)
 }
 p<-read.csv(file.path(out,"summary_adm1.csv"))
 valid<-!is.na(p$investment_class)
 v<-sum(valid & (!is.finite(p$fNRB_2020_2050)|p$fNRB_2020_2050<0|p$fNRB_2020_2050>1))
 record(reg$id,"classified_provinces_with_invalid_ratio",v,v==0)
 v<-sum(valid & (p$investment_coverage_fraction<.99|p$domain_coverage_fraction<.99))
 record(reg$id,"classified_provinces_with_insufficient_coverage",v,v==0)
 for(name in c(paste0(reg$id,"_restoration_screen.png"),"investment_provinces.gpkg"))
  record(reg$id,paste0("exists_",name),as.integer(file.exists(file.path(out,name))),file.exists(file.path(out,name)))
}
result<-do.call(rbind,checks)
write.csv(result,file.path(cfg$output_dir,"validation_checks.csv"),row.names=FALSE)
write_json(as.list(gdal(lib="all")),file.path(cfg$output_dir,"geospatial_libraries.json"),auto_unbox=TRUE,pretty=TRUE)
print(result,row.names=FALSE)
if(!all(result$pass))stop("Validation failed; inspect validation_checks.csv")
cat(nrow(result),"analysis checks passed\n")
