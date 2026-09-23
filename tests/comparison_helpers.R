# Full-content CSV reproduction checks. Base R only.
csv_identifiers<-c('ID','GID_0','GID_1','ECO_ID','ECO_NAME','NAME_0','NAME_1',
 'Name','region','code','Key*','zone_id','iso3','country','zone_name','zone_layer')

compare_table_frames<-function(a,b,tolerance=1e-10){
 if(!identical(dim(a),dim(b)))return(list(pass=FALSE,detail='Table dimensions differ',numeric_columns=0L,text_columns=0L))
 if(!identical(names(a),names(b))||anyDuplicated(names(a)))return(list(pass=FALSE,detail='Column names/order differ or are duplicated',numeric_columns=0L,text_columns=0L))
 problems<-character();nn<-0L;nt<-0L
 number_pattern<-'^[+-]?(([0-9]+([.][0-9]*)?)|([.][0-9]+))([eE][+-]?[0-9]+)?$'
 for(n in names(a)){
  x<-as.character(a[[n]]);y<-as.character(b[[n]])
  missing<-function(v)is.na(v)|v%in%c('NA','NaN','')
  numericish<-function(v)all(missing(v)|v%in%c('Inf','-Inf','+Inf')|grepl(number_pattern,v))
  has_number<-any(grepl(number_pattern,c(x,y)),na.rm=TRUE)
  numeric_column<-!n%in%csv_identifiers&&has_number&&numericish(x)&&numericish(y)
  if(numeric_column){
   nn<-nn+1L
   xx<-suppressWarnings(as.numeric(x));yy<-suppressWarnings(as.numeric(y))
   same<-identical(is.na(xx),is.na(yy))&&identical(is.nan(xx),is.nan(yy))&&
     isTRUE(all.equal(xx,yy,tolerance=tolerance,check.attributes=FALSE))
  }else{
   nt<-nt+1L
   same<-identical(enc2utf8(x),enc2utf8(y))
  }
  if(!same)problems<-c(problems,n)
 }
 list(pass=!length(problems),detail=if(length(problems))paste('Different columns:',paste(problems,collapse=', '))else'All columns and row order match',numeric_columns=nn,text_columns=nt)
}

compare_csv_content<-function(reference,candidate,tolerance=1e-10){
 if(!file.exists(reference)||!file.exists(candidate))return(list(pass=FALSE,detail='Missing CSV file',numeric_columns=0L,text_columns=0L,encoding_artifacts=0L))
 lines<-c(readLines(reference,encoding='UTF-8',warn=FALSE),readLines(candidate,encoding='UTF-8',warn=FALSE))
 bad_utf8<-is.na(iconv(lines,from='UTF-8',to='UTF-8',sub=NA_character_))
 if(any(bad_utf8))return(list(pass=FALSE,detail='Invalid UTF-8 bytes',numeric_columns=0L,text_columns=0L,encoding_artifacts=sum(bad_utf8)))
 artifact<-grepl('<U[+][0-9A-Fa-f]+>',lines)|grepl('\uFFFD',lines,fixed=TRUE)
 count<-sum(bad_utf8|artifact,na.rm=TRUE)
 read_complete<-function(p)withCallingHandlers(
  read.csv(p,colClasses='character',check.names=FALSE,na.strings=NULL,encoding='UTF-8',stringsAsFactors=FALSE),
  warning=function(w)stop('CSV read warning: ',conditionMessage(w),call.=FALSE))
 a<-read_complete(reference);b<-read_complete(candidate)
 ans<-compare_table_frames(a,b,tolerance)
 ans$encoding_artifacts<-count
 if(count){ans$pass<-FALSE;ans$detail<-paste(ans$detail,'; invalid UTF-8/replacement or Unicode-escape artifact')}
 ans
}

reproduction_csv_files<-function(path){
 files<-list.files(path,'[.]csv$',recursive=TRUE,full.names=FALSE)
 # The comparison's own receipts are not scientific analysis outputs.
 sort(files[!grepl('^reproduction_(raster|csv)_checks[.]csv$',basename(files))])
}
