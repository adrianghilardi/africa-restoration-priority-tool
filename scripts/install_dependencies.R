# Exact package setup using base R only; never installs into a global library.
# Rscript scripts/install_dependencies.R [--check] [--library PATH]
args<-commandArgs(TRUE)
script<-sub("^--file=","",grep("^--file=",commandArgs(FALSE),value=TRUE))
root<-dirname(dirname(normalizePath(script,winslash="/")))
lib<-file.path(root,".r-library");check_only<-FALSE;allow_r_difference<-FALSE
i<-1L
while(i<=length(args)){
 if(args[i]=="--check")check_only<-TRUE else if(args[i]=="--allow-r-version-difference")allow_r_difference<-TRUE else
 if(args[i]=="--library" && i<length(args)){i<-i+1L;lib<-args[i]}else stop("Unknown/incomplete argument: ",args[i])
 i<-i+1L
}
if(as.character(getRversion())!="4.6.0"){
 msg<-paste("Reference R is 4.6.0; detected",as.character(getRversion()))
 if(!allow_r_difference)stop(msg,". Install the reference R or explicitly use --allow-r-version-difference.")else warning(msg)
}
if(!check_only)dir.create(lib,recursive=TRUE,showWarnings=FALSE)
if(dir.exists(lib)).libPaths(c(normalizePath(lib,winslash="/"),.libPaths()))
lock<-read.csv(file.path(root,"dependencies.lock.csv"),stringsAsFactors=FALSE,check.names=FALSE)
stopifnot(nrow(lock)==19L,!anyDuplicated(lock$Package),all(nchar(lock$MD5)==32L),all(nchar(lock$SHA256)==64L))
version_here<-function(p){
 d<-suppressWarnings(packageDescription(p))
 if(is.list(d)&&!is.null(d$Version))d$Version else NA_character_
}
actual<-vapply(lock$Package,version_here,character(1))
matched<-!is.na(actual)&actual==lock$Version
if(check_only){
 print(data.frame(package=lock$Package,expected=lock$Version,installed=actual,match=matched),row.names=FALSE)
 if(!all(matched))stop("Dependency lock mismatch. Run scripts/install_dependencies.R to install exact versions into a project-local library.")
 cat("All 19 pinned package versions match; R ",as.character(getRversion()),"\n",sep="")
 quit(status=0)
}
options(timeout=max(600,getOption("timeout")),repos=c(CRAN="https://cran.r-project.org"))
cache<-file.path(root,".package-cache");dir.create(cache,showWarnings=FALSE)
done<-lock$Package[matched];pending<-setdiff(lock$Package,done)
while(length(pending)){
 ready<-pending[vapply(pending,function(p){
  deps<-strsplit(lock$Depends[match(p,lock$Package)],";",fixed=TRUE)[[1]]
  all(deps[nzchar(deps)]%in%done)
 },logical(1))]
 if(!length(ready))stop("Dependency cycle or incomplete dependency lock: ",paste(pending,collapse=", "))
 for(p in ready){
  row<-lock[match(p,lock$Package),]
  archive<-file.path(cache,paste0(p,"_",row$Version,".tar.gz"))
  if(!file.exists(archive)){
   candidates<-unique(c(row$SourceURL,paste0("https://cran.r-project.org/src/contrib/Archive/",p,"/",basename(archive))))
   fetched<-FALSE
   for(url in candidates){
    status<-tryCatch(suppressWarnings(download.file(url,archive,mode="wb",quiet=FALSE)),error=function(e)1L)
    if(identical(status,0L)){fetched<-TRUE;break}
   }
   if(!fetched)stop("Pinned source unavailable at its original or archived CRAN URL: ",p)
  }
  if(unname(tools::md5sum(archive))!=row$MD5)stop("Pinned source checksum mismatch: ",archive)
  message("Installing locked ",p," ",row$Version," into ",lib)
  install.packages(archive,lib=lib,repos=NULL,type="source",dependencies=FALSE)
  if(!identical(version_here(p),row$Version))stop("Install failed or installed version differs: ",p)
  done<-c(done,p)
 }
 pending<-setdiff(pending,ready)
}
stopifnot(all(vapply(lock$Package,version_here,character(1))==lock$Version))
cat("Exact dependency setup complete. Library: ",normalizePath(lib,winslash="/"),"\n",sep="")
cat("System GDAL/GEOS/PROJ and compilers remain platform dependencies; run all synthetic tests next.\n")
