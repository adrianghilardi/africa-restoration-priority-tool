# Restoration screening functions. New implementation; no source-run mutation.
# Windows sessions inherited a C locale on the audit machine. UTF-8 is needed
# to preserve names such as Equateur with their original accents in CSV output.
if(.Platform$OS.type=="windows"){
 locale_result<-suppressWarnings(Sys.setlocale("LC_CTYPE","English_United States.utf8"))
 if(!nzchar(locale_result))warning("UTF-8 locale unavailable; verify non-ASCII place names before release")
}
frame_for_year <- function(year, years) {
 if (anyNA(years) || anyDuplicated(years) || any(diff(years) != 1)) stop("Invalid annual year index")
 i <- match(year,years)
 if (anyNA(i)) stop("Requested year absent from annual index")
 i
}
cr_recovery <- function(B,A,k,m,years,k_multiplier=1) {
 if (length(years)!=1 || !is.finite(years) || years<0) stop("Invalid recovery horizon")
 if (length(k_multiplier)!=1 || !is.finite(k_multiplier) || k_multiplier<=0) stop("Invalid growth multiplier")
 n<-max(length(B),length(A),length(k),length(m))
 if(any(!c(length(B),length(A),length(k),length(m)) %in% c(1,n))) stop("Incompatible parameter lengths")
 B<-rep_len(B,n); A<-rep_len(A,n); k<-rep_len(k,n); m<-rep_len(m,n)
 ans<-rep(NA_real_,n)
 ok<-is.finite(B)&B>=0&is.finite(A)&A>0&is.finite(k)&k>0&is.finite(m)&m>0
 # Carry above-asymptote stock unchanged: fitted capacity must not destroy biomass.
 ans[ok & B>=A]<-B[ok & B>=A]
 j<-which(ok & B<A)
 if(length(j)) {
  # Algebraic advance from equivalent age, stable at zero and close to A.
  q<-(B[j]/A[j])^(1/m[j])
  ans[j]<-A[j]*(1-(1-q)*exp(-k[j]*k_multiplier*years))^m[j]
  ans[j]<-pmax(B[j],pmin(A[j],ans[j]))
 }
 ans
}
co2_to_dry_biomass <- function(x,carbon_fraction=0.47) {
 if(length(carbon_fraction)!=1 || !is.finite(carbon_fraction) || carbon_fraction<=0 || carbon_fraction>1) stop("Invalid carbon fraction")
 ifelse(is.finite(x)&x>=0,x*(12/44)/carbon_fraction,NA_real_)
}
eligibility_table <- function(tab,include_woody_savanna=TRUE) {
 if(length(include_woody_savanna)!=1L || !is.logical(include_woody_savanna) || is.na(include_woody_savanna))stop("include_woody_savanna must be one TRUE/FALSE value")
 required<-c("Key*","LULC")
 if(!all(required %in% names(tab)))stop("Land-cover lookup missing required fields")
 if(anyDuplicated(tab[["Key*"]]))stop("Duplicate land-cover keys")
 lab<-tab$LULC
 forests<-grepl("_(Evergreen|Deciduous) (Needleleaf|Broadleaf) Forests$|_Mixed Forests$",lab)
 woody<-grepl("_Woody Savannas$",lab)
 data.frame(code=tab[["Key*"]],label=lab,screening_eligible=as.integer(forests | (include_woody_savanna & woody)))
}
screening_caption_lines <- function(include_woody_savanna=TRUE,realizations) {
 if(length(include_woody_savanna)!=1L || !is.logical(include_woody_savanna) || is.na(include_woody_savanna))stop("include_woody_savanna must be one TRUE/FALSE value")
 if(length(realizations)!=1L || !is.finite(realizations) || realizations<1 || realizations!=floor(realizations))stop("Invalid realization count")
 c("Version 1.0.0 | Zero-harvest recovery envelope; stable land use and unchanged growth conditions.",
   paste0("Historical 2001 ",if(include_woody_savanna)"forest/woody-savanna"else"forest-only"," scope; ",realizations," MoFuSS realizations. Verify current land use."),
   "Open savannas/grasslands are outside this screen, not afforestation targets. Purple: TNC zone of interest.",
   "Native ecosystem recovery screening, not an intervention impact, carbon-credit estimate or site approval.")
}
investment_typology <- function(nrb,fnrb,prob=2/3) {
 # Strategy document, section 4.4: landscape-specific top-tercile cut-points.
 # Inputs must be verified cumulative NRB mass and ratio of aggregate NRB/harvest.
 if(length(nrb)!=length(fnrb))stop("NRB and fNRB lengths differ")
 if(length(prob)!=1L||!is.finite(prob)||prob<=0||prob>=1)stop("Invalid cut-point probability")
 ok<-is.finite(nrb)&nrb>=0&is.finite(fnrb)&fnrb>=0&fnrb<=1
 label<-rep(NA_character_,length(nrb))
 if(!any(ok))return(list(class=label,nrb_cutpoint=NA_real_,fnrb_cutpoint=NA_real_,n_valid=0L))
 nc<-unname(quantile(nrb[ok],prob,type=7));fc<-unname(quantile(fnrb[ok],prob,type=7))
 high_n<-nrb>0 & nrb>=nc;high_f<-fnrb>0 & fnrb>=fc
 label[ok]<-"Lower priority"
 label[ok & high_n & !high_f]<-"Major supply-shed"
 label[ok & !high_n & high_f]<-"Fragile/local"
 label[ok & high_n & high_f]<-"Critical"
 list(class=label,nrb_cutpoint=nc,fnrb_cutpoint=fc,n_valid=sum(ok))
}
pressure_share <- function(depletion,harvest) {
 # This stock-loss/harvest ratio is a screening proxy, not validated fNRB.
 ifelse(is.finite(depletion)&is.finite(harvest)&depletion>=0&harvest>0,depletion/harvest,NA_real_)
}
priority_class <- function(gain,depletion,share,eligible,gain_threshold=10,share_threshold=.25) {
 n<-max(length(gain),length(depletion),length(share),length(eligible))
 gain<-rep_len(gain,n);depletion<-rep_len(depletion,n);share<-rep_len(share,n);eligible<-rep_len(eligible,n)
 ans<-rep(NA_integer_,n)
 ans[!is.na(eligible)&eligible==0]<-0L
 valid<-!is.na(eligible)&eligible==1&is.finite(gain)&is.finite(depletion)
 ans[valid & gain<gain_threshold]<-1L
 ans[valid & gain>=gain_threshold & depletion<=0]<-2L
 ans[valid & gain>=gain_threshold & depletion>0]<-3L
 ans[valid & gain>=gain_threshold & depletion>0 & is.finite(share)&share>=share_threshold & share<=1]<-4L
 ans[valid & is.finite(share)&share>1]<-5L
 ans[valid & depletion>0 & !is.finite(share)]<-5L
 ans
}
check_same_grid <- function(rasters) {
 for(i in seq_along(rasters))if(!terra::compareGeom(rasters[[1]],rasters[[i]],stopOnError=FALSE))stop("Input grids differ; explicit harmonization required")
 invisible(TRUE)
}
write_tif <- function(r,path,datatype="FLT4S") {
 terra::writeRaster(r,path,overwrite=FALSE,wopt=list(datatype=datatype,gdal=c("COMPRESS=DEFLATE","TILED=YES","BIGTIFF=IF_SAFER")))
}
script_root <- function() {
 arg<-grep("^--file=",commandArgs(),value=TRUE)
 if(length(arg)!=1)stop("Run this script with Rscript")
 dirname(dirname(normalizePath(sub("^--file=","",arg),winslash="/",mustWork=TRUE)))
}
read_config <- function() {
 args<-commandArgs(TRUE)
 if(length(args)!=1)stop("Usage: Rscript scripts/SCRIPT.R config/portable.json")
 cfg<-jsonlite::fromJSON(args[1],simplifyVector=FALSE)
 needed<-c("data_dir","output_dir","scratch_dir","regions","branch_year","end_year","investment_start_year","source_mass_divisor_ha")
 if(!all(needed%in%names(cfg)))stop("Incomplete configuration")
 if(cfg$end_year<=cfg$branch_year)stop("End year must follow branch year")
 if(cfg$investment_start_year!=2020||cfg$end_year!=2050)stop("Version 1.0.0 investment outputs implement the strategy's 2020-2050 window; changing it requires updating the output schema")
 if(!is.finite(cfg$source_mass_divisor_ha)||cfg$source_mass_divisor_ha<=0)stop("Invalid source mass divisor")
 if(is.null(cfg$include_woody_savanna))cfg$include_woody_savanna<-TRUE
 if(length(cfg$include_woody_savanna)!=1L || !is.logical(cfg$include_woody_savanna) || is.na(cfg$include_woody_savanna))stop("include_woody_savanna must be one TRUE/FALSE value")
 cfg$tool_version<-"1.0.0"
 cfg
}
