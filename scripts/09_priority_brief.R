# Presentation-only views of completed province results; no model recalculation.
# Run from code/: Rscript scripts/09_priority_brief.R config/portable.json [new_brief_dir]
suppressPackageStartupMessages({library(terra);library(jsonlite);library(digest)})
if(.Platform$OS.type=="windows")suppressWarnings(Sys.setlocale("LC_CTYPE","English_United States.utf8"))
args<-commandArgs(trailingOnly=TRUE)
if(!length(args))stop("Usage: 09_priority_brief.R CONFIG.json [NEW_BRIEF_DIRECTORY]")
cfg<-read_json(args[1],simplifyVector=FALSE)
if(is.null(cfg$output_dir)||is.null(cfg$regions)||is.null(cfg$data_dir))stop("Config requires output_dir,data_dir,regions")
dest<-if(length(args)>=2)args[2]else file.path(cfg$output_dir,"priority_brief")
if(file.exists(dest))stop("Brief destination exists; use a new directory")
classes<-c("Critical","Major supply-shed","Fragile/local","Lower priority","Unclassified")
colors<-c("#B52246","#D58A14","#397F98","#D1DED5","#D8D5DE")
fields<-c("GID_0","NAME_0","GID_1","NAME_1","investment_class","classification_status",
 "NRB_2020_2050_model_MgDM","fNRB_2020_2050","investment_coverage_fraction",
 "domain_coverage_fraction","conditional_recovery_MgDM","area_weighted_recovery_MgDM_ha",
 "recovery_covered_ground_ha","high_pressure_recovery_ground_ha")
input<-list()
# Preflight every source and key before writing any output.
for(reg in cfg$regions){
 d<-file.path(cfg$output_dir,reg$id)
 p<-file.path(d,"summary_adm1.csv");g<-file.path(d,"investment_provinces.gpkg")
 if(!file.exists(p)||!file.exists(g))stop("Missing completed province results for ",reg$id)
 tab<-read.csv(p,stringsAsFactors=FALSE,check.names=FALSE,fileEncoding="UTF-8")
 v<-vect(g);attrs<-as.data.frame(v)
 if(!all(fields%in%names(tab))||!all(fields%in%names(attrs)))stop("Province schema mismatch")
 key<-function(x)paste(x$GID_0,x$GID_1,sep="::")
 if(anyDuplicated(key(tab))||anyDuplicated(key(attrs)))stop("Duplicate province keys; explicit disambiguation needed")
 ix<-match(key(tab),key(attrs))
 if(nrow(tab)!=nrow(v)||anyNA(ix))stop("CSV and GeoPackage keys differ")
 if(!isTRUE(all.equal(tab[,fields],attrs[ix,fields],check.attributes=FALSE,tolerance=1e-8)))stop("CSV and GeoPackage values differ")
 v<-v[ix,]
 observed<-unique(tab$investment_class[!is.na(tab$investment_class)&nzchar(tab$investment_class)])
 if(any(!observed%in%classes[1:4]))stop("Unknown pressure class")
 input[[reg$id]]<-list(tab=tab,v=v,csv=p,gpkg=g)
}
dir.create(dest,recursive=TRUE)
checks<-list();provenance<-list()
fmt<-function(x,d=1)ifelse(is.finite(x),formatC(x,format="f",digits=d,big.mark=","),"n.a.")
escape_md<-function(x)gsub("[|\r\n]"," ",as.character(x))
for(reg in cfg$regions){
 src<-input[[reg$id]];tab<-src$tab;v<-src$v
 cls<-tab$investment_class;cls[is.na(cls)|!nzchar(cls)]<-"Unclassified"
 counts<-table(factor(cls,levels=classes))
 take<-tab$classification_status=="Classified" & cls%in%classes[1:2]
 take[is.na(take)]<-FALSE
 shortlist<-tab[take,fields,drop=FALSE]
 shortlist<-shortlist[order(match(shortlist$investment_class,classes),
   -shortlist$NRB_2020_2050_model_MgDM,shortlist$NAME_0,shortlist$NAME_1),,drop=FALSE]
 rownames(shortlist)<-NULL
 out<-file.path(dest,reg$id);dir.create(out)
 csvpath<-file.path(out,paste0(reg$id,"_priority_shortlist.csv"))
 write.csv(shortlist,csvpath,row.names=FALSE,na="",fileEncoding="UTF-8")
 # CSV is an unrounded, flat analytical-data export; Markdown is display only.
 readback<-read.csv(csvpath,stringsAsFactors=FALSE,check.names=FALSE,fileEncoding="UTF-8")
 same_csv<-if(!nrow(shortlist))nrow(readback)==0L&&identical(names(readback),names(shortlist))else
   isTRUE(all.equal(readback,shortlist,check.attributes=FALSE,tolerance=1e-12))
 if(!same_csv)stop("Shortlist CSV roundtrip changed values")
 if(any(!shortlist$investment_class%in%classes[1:2]))stop("Unexpected shortlist class")
 outline<-vect(file.path(cfg$data_dir,"tnc_zones.gpkg"),layer="zone_of_interest_all")
 keep<-if(reg$id=="congo")grepl("^Congo",outline$Name)else outline$Name=="KAZA"
 outline<-project(outline[keep,],"EPSG:4326")
 mapv<-project(v,"EPSG:4326")
 mapfile<-file.path(out,paste0(reg$id,"_province_priority_map.png"))
 png(mapfile,width=2400,height=1750,res=180,bg="white")
 layout(matrix(c(1,2),nrow=1),widths=c(3.4,1.6))
 par(mar=c(3.5,3.5,6,1),oma=c(5.5,.3,1.5,.3),family="sans",fg="#263538")
 plot(mapv,col=colors[match(cls,classes)],border="#FFFFFF",lwd=.55,
      axes=TRUE,main=paste0(reg$name,": province pressure priorities, 2020-2050"),cex.main=1.05)
 lines(outline,col="#29383B",lwd=1.1)
 mtext("Longitude / latitude (WGS84)",side=1,line=2.3,cex=.72)
 par(mar=c(3,0,4,1))
 plot.new();plot.window(xlim=c(0,1),ylim=c(0,1))
 text(0,.98,"PRESSURE CLASS",adj=c(0,1),font=2,cex=1.05)
 labels<-c("Critical: high NRB / high fNRB","Major supply-shed: high NRB / low fNRB",
   "Fragile/local: low NRB / high fNRB","Lower priority: low NRB / low fNRB",
   "Unclassified: coverage or ratio review")
 ypos<-seq(.87,.39,length.out=5)
 for(i in seq_along(classes)){
   rect(0,ypos[i]-.02,.06,ypos[i]+.025,col=colors[i],border=NA)
   text(.09,ypos[i]+.025,paste0(classes[i]," (",counts[i],")"),adj=c(0,1),font=2,cex=.86)
   detail<-if(i==5)"Coverage or ratio review"else sub("^[^:]+: ","",labels[i])
   text(.09,ypos[i]-.024,detail,adj=c(0,1),cex=.75)
 }
 notes<-c("Classes are relative within this landscape.",
  "Top-tercile cut-points for NRB and fNRB.",
  "Province intersections with the TNC interest zone.",
  "Unclassified does not mean low priority.",
  "Pressure is not site eligibility or project approval.")
 text(0,.26,paste(unlist(lapply(notes,strwrap,width=34)),collapse="\n"),adj=c(0,1),cex=.76)
 mtext("Restoration Priority Tool v1.0.0 | Existing province classifications; no new score or ranking formula.",side=1,outer=TRUE,line=1,cex=.8)
 mtext("Sources: MoFuSS; authorized TNC planning zones; geoBoundaries and listed country providers, including OpenStreetMap contributors.",side=1,outer=TRUE,line=2.5,cex=.68)
 mtext("Boundary terms: CC BY / CC BY-SA / ODbL / public domain as listed in boundaries/manifest_adm1.csv. No GADM geometry.",side=1,outer=TRUE,line=3.8,cex=.68)
 dev.off()
 lines<-c(paste0("# ",reg$name," — province priority brief"),"",
 "Restoration Priority Tool v1.0.0. Pressure: 2020–2050. Conditional recovery: post-harvest 2030–2050.","",
 paste0("The completed results contain **",counts[1]," Critical** and **",counts[2],
   " Major supply-shed** province intersections. The full shortlist contains ",nrow(shortlist)," rows."),"",
 "These are pressure priorities for investigation, not approved restoration sites. Fragile/local provinces remain important for locally intense pressure even when their absolute NRB is lower. Unclassified areas require coverage/ratio review.","",
 "| Pressure class | Province intersections |","| --- | ---: |",
 paste0("| ",classes," | ",as.integer(counts)," |"),"",
 paste0("![Province priority map](",basename(mapfile),")"),"",
 "## Shortlist preview","",
 "Rows are grouped by the existing pressure class and displayed by descending NRB within that class. This display order is not a new composite rank. The complete, unrounded CSV includes every Critical and Major supply-shed intersection, original identifiers, both coverage fractions and additional recovery quantities.","",
 paste0("Full data: [",basename(csvpath),"](",basename(csvpath),")."),"",
 "NRB below is model-accounting million Mg dry biomass. Recovery is conditional Mg dry biomass/ha over valid screened area. Coverage is investment-data coverage / model-domain coverage; both must meet the analysis classification rules. Missing recovery is shown as n.a., not zero.","")
 for(category in classes[1:2]){
   sub<-shortlist[shortlist$investment_class==category,,drop=FALSE]
   preview<-head(sub,12L)
   lines<-c(lines,paste0("### ",category),"",
    paste0("Showing ",nrow(preview)," of ",nrow(sub)," rows."),"",
    "| Country | Province | NRB (million MgDM) | fNRB | Coverage | Recovery (MgDM/ha) |",
    "| --- | --- | ---: | ---: | ---: | ---: |")
   if(nrow(preview))for(i in seq_len(nrow(preview))){
     p<-preview[i,]
     lines<-c(lines,paste0("| ",escape_md(p$NAME_0)," | ",escape_md(p$NAME_1)," | ",
       fmt(p$NRB_2020_2050_model_MgDM/1e6,2)," | ",fmt(100*p$fNRB_2020_2050,1),"% | ",
       fmt(100*p$investment_coverage_fraction,1),"% / ",fmt(100*p$domain_coverage_fraction,1),"% | ",
       fmt(p$area_weighted_recovery_MgDM_ha,1)," |"))
   }
   lines<-c(lines,"")
 }
 lines<-c(lines,"## Next decision","",
   "Within the shortlisted province intersections, inspect the existing recovery/depletion and observed-change layers, then climate and social-context sensitivities. Verify current ecosystem condition, native regeneration, tenure/community priorities, fire/grazing/harvest management, displacement and costs. Historical woody-savanna inclusion is not approval to afforest natural open ecosystems.","",
   "The no-harvest recovery envelope is not an ANR impact estimate or carbon-credit quantity. Province classes are relative within the landscape and do not imply equal absolute pressure across Congo Basin and KAZA.","",
   "## Source traceability","",
   "Values are copied from the completed summary_adm1.csv and cross-checked against investment_provinces.gpkg using country/province identifiers. No growth, threshold, classification or zonal calculation is changed. The input hashes in priority_brief_manifest.json identify the source version.","",
   "Sources: MoFuSS; authorized TNC planning zones; geoBoundaries and country providers (including OpenStreetMap contributors where listed). Preserve boundaries/manifest_adm1.csv and THIRD_PARTY_NOTICES.md; boundary terms vary by country, including CC BY-SA and ODbL.")
 writeLines(enc2utf8(lines),file.path(out,paste0(reg$id,"_priority_brief.md")),useBytes=TRUE)
 checks[[reg$id]]<-list(region=reg$id,source_rows=nrow(tab),shortlist_rows=nrow(shortlist),
  class_counts=as.list(setNames(as.integer(counts),classes)),csv_roundtrip=TRUE,
  csv_geopackage_key_and_value_match=TRUE,source_numerical_values_unchanged=TRUE)
 provenance[[reg$id]]<-list(csv_source=paste0(reg$id,"/summary_adm1.csv"),
  csv_sha256=digest(src$csv,file=TRUE,algo="sha256"),gpkg_source=paste0(reg$id,"/investment_provinces.gpkg"),
  gpkg_sha256=digest(src$gpkg,file=TRUE,algo="sha256"))
 message(reg$id,": ",nrow(shortlist)," shortlist rows; map and brief written")
}
write_json(list(version="1.0.0",source_inputs=provenance,checks=checks,
 method="Presentation-only filtering of existing Critical/Major supply-shed classes; no new numerical index or model assumptions"),
 file.path(dest,"priority_brief_manifest.json"),pretty=TRUE,auto_unbox=TRUE)
