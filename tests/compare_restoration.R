# Rscript tests/compare_restoration.R reference_results new_results
# Compare every regional raster plus all scientific output CSV columns, including
# classifications, place names, identifiers, coverage and sensitivity tables.
suppressPackageStartupMessages({library(terra);library(jsonlite)})
if(.Platform$OS.type=='windows')suppressWarnings(Sys.setlocale('LC_CTYPE','English_United States.utf8'))
script_arg<-grep('^--file=',commandArgs(FALSE),value=TRUE)
source(file.path(dirname(normalizePath(sub('^--file=','',script_arg),winslash='/')),'comparison_helpers.R'))
args<-commandArgs(TRUE)
if(length(args)!=2L||!all(dir.exists(args)))stop('Supply existing reference and new restoration result directories')
report<-list()
for(reg in c('congo','kaza')){
 files<-sort(list.files(file.path(args[1],reg),'[.]tif$',full.names=FALSE))
 new_files<-sort(list.files(file.path(args[2],reg),'[.]tif$',full.names=FALSE))
 if(!length(files))stop('No reference rasters for ',reg)
 if(!identical(files,new_files))stop('Raster file sets differ for ',reg)
 for(f in files){
  a<-rast(file.path(args[1],reg,f));b<-rast(file.path(args[2],reg,f))
  if(!compareGeom(a,b,stopOnError=FALSE))stop('Raster grids differ: ',reg,'/',f)
  na_diff<-global(is.na(a)!=is.na(b),'sum',na.rm=TRUE)[1,1]
  valid_cells<-global(!is.na(a),'sum',na.rm=TRUE)[1,1]
  value_diff<-if(valid_cells==0&&na_diff==0)0 else global(abs(a-b),'max',na.rm=TRUE)[1,1]
  report[[length(report)+1L]]<-data.frame(region=reg,file=f,max_absolute_difference=value_diff,
    nodata_mask_differences=na_diff,pass=is.finite(value_diff)&&value_diff==0&&na_diff==0)
 }
}
files<-reproduction_csv_files(args[1]);new_files<-reproduction_csv_files(args[2])
if(!length(files))stop('No reference CSV outputs')
csv_report<-list()
for(f in sort(union(files,new_files))){
 check<-compare_csv_content(file.path(args[1],f),file.path(args[2],f))
 csv_report[[length(csv_report)+1L]]<-data.frame(file=f,pass=check$pass,
  numeric_columns=check$numeric_columns,text_columns=check$text_columns,
  encoding_artifacts=check$encoding_artifacts,detail=check$detail)
}
result<-do.call(rbind,report);csv_result<-do.call(rbind,csv_report)
write.csv(result,file.path(args[2],'reproduction_raster_checks.csv'),row.names=FALSE)
write.csv(csv_result,file.path(args[2],'reproduction_csv_checks.csv'),row.names=FALSE)
passed<-all(result$pass)&&all(csv_result$pass)
write_json(list(status=if(passed)'PASS'else'FAIL',raster_checks=nrow(result),
  max_absolute_difference=max(result$max_absolute_difference),csv_checks=nrow(csv_result),
  csv_numeric_columns=sum(csv_result$numeric_columns),csv_text_columns=sum(csv_result$text_columns),
  compared_classification_labels_and_identifiers=TRUE,
  unicode_escape_artifacts=sum(csv_result$encoding_artifacts)),
  file.path(args[2],'reproduction_check.json'),pretty=TRUE,auto_unbox=TRUE)
if(!passed)stop('Reproduction failed; inspect reproduction_raster_checks.csv and reproduction_csv_checks.csv')
cat(nrow(result),'restoration rasters reproduce exactly;',nrow(csv_result),
 'complete CSV outputs match, including text identifiers/classifications and missing values\n')
