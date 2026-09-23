# Run a conditional restoration screen using only the portable data bundle.
suppressPackageStartupMessages({library(terra);library(jsonlite);library(digest)})
arg<-grep("^--file=",commandArgs(),value=TRUE)
source(file.path(dirname(dirname(normalizePath(sub("^--file=","",arg),winslash="/"))),"R","core.R"))
cfg<-read_config()
if(!is.null(cfg$local_library_dir)).libPaths(c(cfg$local_library_dir,.libPaths()))
if(!requireNamespace("exactextractr",quietly=TRUE)||!requireNamespace("sf",quietly=TRUE))stop("Install sf and exactextractr for exact zonal summaries")
options(warn=1)
dir.create(cfg$scratch_dir,recursive=TRUE,showWarnings=FALSE)
terraOptions(tempdir=cfg$scratch_dir,memfrac=.25,progress=0)
if(dir.exists(cfg$output_dir))stop("Output destination exists; choose a new version directory")
manifest<-read.csv(file.path(cfg$data_dir,"manifest_sha256.csv"),stringsAsFactors=FALSE)
message("Verifying ",nrow(manifest)," bundled inputs")
for(i in seq_len(nrow(manifest))){
 p<-file.path(cfg$data_dir,manifest$path[i])
 if(!file.exists(p) || digest(p,algo="sha256",file=TRUE)!=manifest$sha256[i])stop("Input checksum mismatch: ",p)
}
dir.create(cfg$output_dir,recursive=TRUE)
summaries<-list();qa<-list()
for(reg in cfg$regions){
 message("Analyzing ",reg$id)
 input<-file.path(cfg$data_dir,reg$id);out<-file.path(cfg$output_dir,reg$id);dir.create(out)
 loadr<-function(n)rast(file.path(input,n))
 ref<-loadr("mask_c.tif")
 A<-loadr("A_c.tif")/cfg$source_mass_divisor_ha;k<-loadr("k_c.tif");m<-loadr("m_c.tif");lc<-loadr("LULCt1_c.tif")
 check_same_grid(list(ref,A,k,m,lc))
 tab<-eligibility_table(read.csv(file.path(input,"landcover_lookup.csv"),check.names=FALSE),cfg$include_woody_savanna)
 write.csv(tab,file.path(out,"eligibility_rules.csv"),row.names=FALSE)
 eligible<-classify(lc,as.matrix(tab[,c("code","screening_eligible")]),others=NA)
 eligible<-mask(eligible,ref)
 # The default native woody-ecosystem scope includes historical woody savanna.
 # It does not prescribe increased tree cover in natural open ecosystems.
 # The historical scope is not current ecological or social eligibility.
 wooded_tab<-eligibility_table(read.csv(file.path(input,"landcover_lookup.csv"),check.names=FALSE),TRUE)
 wooded<-mask(classify(lc,as.matrix(wooded_tab[,c("code","screening_eligible")]),others=NA),ref)
 write_tif(wooded,file.path(out,"historic_forest_and_woody_savanna_context.tif"),"INT1U")
 write_tif(eligible,file.path(out,"screening_eligibility.tif"),"INT1U")
 ground_area<-cellSize(ref,unit="ha",mask=TRUE)
 write_tif(ground_area,file.path(out,"ground_cell_area_ha.tif"))
 candidates<-list.files(input,sprintf("^stock_%d_mc[0-9]+[.]tif$",cfg$branch_year))
 ids<-as.integer(sub(".*_mc([0-9]+)[.]tif$","\\1",candidates))
 ids<-sort(ids)
 if(!length(ids))stop("No stock realizations")
 for(mc in ids){
  message("  realization ",mc)
  B<-loadr(sprintf("stock_%d_mc%03d.tif",cfg$branch_year,mc))/cfg$source_mass_divisor_ha
  E<-loadr(sprintf("stock_%d_mc%03d.tif",cfg$end_year,mc))/cfg$source_mass_divisor_ha
  H<-loadr(sprintf("harvest_%d_%d_mc%03d.tif",cfg$branch_year+1,cfg$end_year,mc))/cfg$source_mass_divisor_ha
  baseline<-loadr(sprintf("investment_baseline_%d_mc%03d.tif",cfg$investment_start_year,mc))
  investment_harvest<-loadr(sprintf("harvest_%d_%d_mc%03d.tif",cfg$investment_start_year,cfg$end_year,mc))
  nrb<-baseline-E*cfg$source_mass_divisor_ha
  nrb<-ifel(nrb<0,0,nrb)
  write_tif(nrb,file.path(out,sprintf("investment_nrb_mc%03d_MgDM_cell.tif",mc)))
  write_tif(investment_harvest,file.path(out,sprintf("investment_harvest_mc%03d_MgDM_cell.tif",mc)))
  check_same_grid(list(ref,B,E,H))
  for(mult in c(.75,1,1.25)){
   years<-cfg$end_year-cfg$branch_year
   gain<-lapp(c(B,A,k,m),function(b,a,kk,mm)cr_recovery(b,a,kk,mm,years,mult)-b)
   gain<-ifel(eligible==1,gain,NA)
   write_tif(gain,file.path(out,sprintf("recovery_k%03d_mc%03d_MgDM_ha.tif",round(100*mult),mc)))
  }
  loss<-ifel(B-E>0,B-E,0)
  write_tif(loss,file.path(out,sprintf("net_depletion_mc%03d_MgDM_ha.tif",mc)))
  write_tif(H,file.path(out,sprintf("harvest_mc%03d_MgDM_ha.tif",mc)))
 }
 aggregate_files<-function(pattern,stem){
  files<-list.files(out,pattern,full.names=TRUE)
  if(length(files)!=length(ids))stop("Incomplete realization outputs")
  r<-rast(files)
  for(fun in c("mean","min","max")){
   target<-file.path(out,paste0(stem,"_",fun,".tif"))
   app(r,fun,na.rm=FALSE,filename=target,overwrite=FALSE,wopt=list(gdal=c("COMPRESS=DEFLATE","TILED=YES")))
  }
 }
 aggregate_files("^recovery_k100_mc[0-9]+_MgDM_ha[.]tif$","recovery_MgDM_ha")
 aggregate_files("^net_depletion_mc[0-9]+_MgDM_ha[.]tif$","net_depletion_MgDM_ha")
 aggregate_files("^harvest_mc[0-9]+_MgDM_ha[.]tif$","harvest_MgDM_ha")
 aggregate_files("^investment_nrb_mc[0-9]+_MgDM_cell[.]tif$","investment_nrb_MgDM_cell")
 aggregate_files("^investment_harvest_mc[0-9]+_MgDM_cell[.]tif$","investment_harvest_MgDM_cell")
 for(mult in c(75,125))aggregate_files(sprintf("^recovery_k%03d_mc[0-9]+_MgDM_ha[.]tif$",mult),sprintf("recovery_k%03d_MgDM_ha",mult))
 gain<-rast(file.path(out,"recovery_MgDM_ha_mean.tif"))
 loss<-rast(file.path(out,"net_depletion_MgDM_ha_mean.tif"))
 H<-rast(file.path(out,"harvest_MgDM_ha_mean.tif"))
 N<-rast(file.path(out,"investment_nrb_MgDM_cell_mean.tif"))
 IH<-rast(file.path(out,"investment_harvest_MgDM_cell_mean.tif"))
 IF<-lapp(c(N,IH),pressure_share)
 write_tif(IF,file.path(out,"investment_fNRB_ratio_of_MC_means.tif"))
 share<-lapp(c(loss,H),pressure_share)
 write_tif(share,file.path(out,"net_depletion_share_of_harvest.tif"))
 # Classes keep physical quantities visible and avoid hidden weighted overlays.
 cls<-lapp(c(gain,loss,share,eligible),function(g,d,s,e)priority_class(g,d,s,e,cfg$gain_threshold_MgDM_ha,cfg$pressure_share_threshold))
 write_tif(cls,file.path(out,"screening_class.tif"),"INT1U")
 change<-loadr("observed_2025_MgDM_ha.tif")-loadr("observed_2000_MgDM_ha.tif")
 write_tif(change,file.path(out,"observed_change_2000_2025_MgDM_ha.tif"))
 classes<-data.frame(code=0:5,label=c("Outside native woody-recovery scope; separate ecosystem assessment","Low conditional recovery","Recovery potential; no net BAU depletion","Recovery potential with BAU depletion","Recovery potential with high depletion share","Mass balance or attribution review"))
 write.csv(classes,file.path(out,"screening_class_legend.csv"),row.names=FALSE)
 sumone<-function(r)global(r,"sum",na.rm=TRUE)[1,1]
 summaries[[length(summaries)+1L]]<-data.frame(region=reg$id,realizations=length(ids),
 domain_ground_ha=sumone(ground_area),screening_eligible_ground_ha=sumone(ifel(eligible==1,ground_area,0)),
 conditional_recovery_MgDM=sumone(gain*ground_area),
  recovery_covered_ground_ha=sumone(ifel(!is.na(gain),ground_area,0)),
  area_weighted_mean_recovery_MgDM_ha=sumone(gain*ground_area)/sumone(ifel(!is.na(gain),ground_area,0)))
 # Explicit sensitivity table: stress tests are not probabilities or climate scenarios.
 sense<-list()
 for(thr in c(5,10,20))for(ps in c(.15,.25,.35)){
  cc<-lapp(c(gain,loss,share,eligible),function(g,d,s,e)priority_class(g,d,s,e,thr,ps))
  sense[[length(sense)+1L]]<-data.frame(gain_threshold=thr,pressure_share_threshold=ps,high_pressure_recovery_ground_ha=sumone(ifel(cc==4,ground_area,0)))
 }
 write.csv(do.call(rbind,sense),file.path(out,"threshold_sensitivity.csv"),row.names=FALSE)
 # Recompute zonal summaries using geometry only, ignoring legacy result fields.
 # Keep model-accounting totals distinct from ground-area-weighted recovery.
 pair_ok<-!is.na(N)&!is.na(IH)
 metrics<-c(ground_area,ifel(eligible==1,ground_area,0),
   ifel(!is.na(gain),ground_area,0),gain*ground_area,ifel(cls==4,ground_area,0),
   ifel(pair_ok,N,NA),ifel(pair_ok,IH,NA),ifel(pair_ok,ground_area,0))
 names(metrics)<-c("model_domain_ground_ha","screening_eligible_ground_ha","recovery_covered_ground_ha",
   "conditional_recovery_MgDM","high_pressure_recovery_ground_ha",
   "NRB_2020_2050_model_MgDM","harvest_2020_2050_model_MgDM","investment_covered_ground_ha")
 summarize_zones<-function(v){
  z<-exactextractr::exact_extract(metrics,sf::st_as_sf(v),"sum",progress=FALSE,force_df=TRUE)
  names(z)<-sub("^sum[.]","",names(z))
  if(!identical(names(z),names(metrics)))stop("Unexpected zonal-summary column order")
  result<-cbind(as.data.frame(v),z)
  result$zone_ground_ha<-expanse(v,unit="ha")
  result$investment_coverage_fraction<-result$investment_covered_ground_ha/result$model_domain_ground_ha
  result$domain_coverage_fraction<-result$model_domain_ground_ha/result$zone_ground_ha
  result$conditional_recovery_MgDM[result$recovery_covered_ground_ha<=0]<-NA_real_
  result$area_weighted_recovery_MgDM_ha<-result$conditional_recovery_MgDM/result$recovery_covered_ground_ha
  for(col in c("NRB_2020_2050_model_MgDM","harvest_2020_2050_model_MgDM"))result[[col]][result$investment_covered_ground_ha<=0]<-NA_real_
  result$fNRB_2020_2050<-with(result,pressure_share(NRB_2020_2050_model_MgDM,harvest_2020_2050_model_MgDM))
  result
 }
 tnc_interest<-vect(file.path(cfg$data_dir,"tnc_zones.gpkg"),layer="zone_of_interest_all")
 tnc_interest<-tnc_interest[if(reg$id=="congo")grepl("^Congo",tnc_interest$Name)else tnc_interest$Name=="KAZA",]
 tnc_interest<-project(tnc_interest,crs(ref))
 if(!all(is.valid(tnc_interest)))tnc_interest<-makeValid(tnc_interest)
 for(n in c("adm1","ecoregions")){
  message("  summarizing ",n)
  v<-vect(file.path(input,paste0("mofuss_",n,"_fr.gpkg")))
  keep<-intersect(c("ID","GID_0","NAME_0","GID_1","NAME_1","ECO_ID","ECO_NAME"),names(v))
  v<-v[,keep]
  if(!same.crs(v,ref))v<-project(v,crs(ref))
  if(!all(is.valid(v)))v<-makeValid(v)
  # Typology is within the TNC landscape, not entire provinces beyond it.
  v<-intersect(v,tnc_interest[,0])
  # Fractional cell weighting avoids assigning complete boundary cells to multiple zones.
  result<-summarize_zones(v)
  if(n=="adm1"){
   sufficient<-is.finite(result$investment_coverage_fraction)&result$investment_coverage_fraction>=.99&
     is.finite(result$domain_coverage_fraction)&result$domain_coverage_fraction>=.99
   t<-investment_typology(ifelse(sufficient,result$NRB_2020_2050_model_MgDM,NA_real_),result$fNRB_2020_2050)
   result$investment_class<-t$class
   result$NRB_landscape_tercile_cutpoint<-t$nrb_cutpoint
   result$fNRB_landscape_tercile_cutpoint<-t$fnrb_cutpoint
   result$classification_status<-ifelse(is.na(t$class),"Review coverage or invalid/zero-harvest ratio","Classified")
   values(v)<-result
   writeVector(v,file.path(out,"investment_provinces.gpkg"),overwrite=FALSE)
  }
  write.csv(result,file.path(out,paste0("summary_",n,".csv")),row.names=FALSE)
 }
 # TNC layers are nested/overlapping: their totals must never be added together.
 for(layer in c("zone_of_interest_all","zone_of_influence_all","zone_of_ops_all")){
  message("  summarizing ",layer)
  v<-vect(file.path(cfg$data_dir,"tnc_zones.gpkg"),layer=layer)
  take<-if(reg$id=="congo")grepl("^Congo",v$Name)else v$Name=="KAZA"
  v<-v[take,]
  if(!nrow(v))next
  v<-project(v,crs(ref));if(!all(is.valid(v)))v<-makeValid(v)
  write.csv(summarize_zones(v),file.path(out,paste0("summary_",layer,".csv")),row.names=FALSE)
 }
 qa[[length(qa)+1L]]<-data.frame(region=reg$id,realizations=length(ids),
 invalid_growth_cells=sumone(ifel(eligible==1 & (is.na(A)|A<=0|is.na(k)|k<=0|is.na(m)|m<=0),1,0)),
 unknown_landcover_cells=sumone(ifel(is.na(eligible)&!is.na(ref),1,0)),
  share_above_one_cells=sumone(ifel(share>1,1,0)),
  investment_fNRB_above_one_cells=sumone(ifel(IF>1,1,0)),
  investment_positive_NRB_zero_harvest_cells=sumone(ifel(N>0 & IH==0,1,0)),
 negative_recovery_cells=sumone(ifel(gain<0,1,0)))
 # Standalone overview: full-resolution numerical products remain in GeoTIFFs.
 boundary<-vect(file.path(input,"mofuss_adm1_fr.gpkg"))
 boundary<-project(boundary,crs(ref))
 tnc<-vect(file.path(cfg$data_dir,"tnc_zones.gpkg"),layer="zone_of_interest_all")
 tnc<-tnc[if(reg$id=="congo")grepl("^Congo",tnc$Name)else tnc$Name=="KAZA",]
 tnc<-project(tnc,crs(ref))
 png(file.path(out,paste0(reg$id,"_restoration_screen.png")),width=2400,height=1550,res=180)
 par(mfrow=c(1,2),mar=c(4,3,5,5),oma=c(6.5,0,3,0),bg="white")
 # Native metre coordinates avoid pretending the model grid is equal area.
 plot(gain,col=hcl.colors(80,"YlGn",rev=TRUE),main=paste0("Conditional recovery ",cfg$branch_year,"-",cfg$end_year),
      axes=FALSE,plg=list(title="Mg dry biomass/ha",cex=.8),maxcell=500000)
 lines(boundary,col="#7d8580",lwd=.35);if(nrow(tnc))lines(tnc,col="#33224b",lwd=1.3)
 plot(loss,col=hcl.colors(80,"YlOrRd",rev=TRUE),main="BAU net biomass depletion",axes=FALSE,
      plg=list(title="Mg dry biomass/ha",cex=.8),maxcell=500000)
 lines(boundary,col="#7d8580",lwd=.35);if(nrow(tnc))lines(tnc,col="#33224b",lwd=1.3)
 mtext(paste0(reg$name," | Native woody-ecosystem recovery screen"),outer=TRUE,side=3,line=.7,cex=1.3,font=2)
 captions<-screening_caption_lines(cfg$include_woody_savanna,length(ids))
 for(j in seq_along(captions))mtext(captions[j],outer=TRUE,side=1,line=.9+1.25*(j-1),cex=.8)
 writeLines(captions,file.path(out,"screening_interpretation.txt"))
 dev.off()
 message("Completed ",reg$id)
 rm(A,k,m,lc,ref,gain,loss,H,share,cls,change,ground_area,N,IH,IF,metrics);gc()
}
write.csv(do.call(rbind,summaries),file.path(cfg$output_dir,"regional_summary.csv"),row.names=FALSE)
write.csv(do.call(rbind,qa),file.path(cfg$output_dir,"quality_checks.csv"),row.names=FALSE)
write_json(cfg,file.path(cfg$output_dir,"analysis_config.json"),pretty=TRUE,auto_unbox=TRUE)
capture.output(sessionInfo(),file=file.path(cfg$output_dir,"analysis_session.txt"))
message("Analysis complete: ",cfg$output_dir)
