# Synthetic regressions for the full-column repeat-run comparator.
script_arg<-grep('^--file=',commandArgs(FALSE),value=TRUE)
root<-dirname(normalizePath(sub('^--file=','',script_arg),winslash='/'))
source(file.path(root,'comparison_helpers.R'))
n<-0L
check<-function(label,value){if(!isTRUE(value))stop('FAIL: ',label);n<<-n+1L;cat('PASS',label,'\n')}
a<-data.frame(ID=c('001','002'),NAME_1=c('Equateur','Kavango'),investment_class=c('Critical','Lower priority'),
 fNRB=c('0.25','NA'),NRB=c('100','0'),check.names=FALSE)
check('identical full tables pass',compare_table_frames(a,a)$pass)
b<-a;b$investment_class[1]<-'Lower priority'
check('changed classification fails',!compare_table_frames(a,b)$pass)
b<-a;b$ID[1]<-'1'
check('identifier leading zeros are preserved',!compare_table_frames(a,b)$pass)
b<-a;b$NAME_1[1]<-'Other province'
check('changed place name fails',!compare_table_frames(a,b)$pass)
b<-a;b$fNRB[2]<-'0'
check('missing numeric changed to zero fails',!compare_table_frames(a,b)$pass)
b<-a;b$NRB[1]<-'1e2'
check('equivalent numeric notation passes',compare_table_frames(a,b)$pass)
b<-a;b$NRB[1]<-'100.000000001'
check('configured small numeric tolerance applies',compare_table_frames(a,b)$pass)
b<-a;b$NRB[1]<-'101'
check('changed numeric value fails',!compare_table_frames(a,b)$pass)
check('row order change fails',!compare_table_frames(a,a[2:1,])$pass)
check('extra column fails',!compare_table_frames(a,transform(a,extra='unexpected'))$pass)
check('column reorder fails',!compare_table_frames(a,a[,rev(names(a))])$pass)
scratch<-tempfile('comparison_test_');dir.create(scratch)
p<-file.path(scratch,'a.csv');q<-file.path(scratch,'b.csv')
write.csv(a,p,row.names=FALSE);write.csv(a,q,row.names=FALSE)
check('complete CSV reader passes identical files',compare_csv_content(p,q)$pass)
fixture<-paste0('ID,NAME_1\n"001","',enc2utf8('\u00c9quateur'),'"\n')
writeBin(charToRaw(fixture),p);writeBin(charToRaw(fixture),q)
check('literal UTF-8 place names pass without locale conversion',compare_csv_content(p,q)$pass)
check('missing file fails',!compare_csv_content(p,file.path(scratch,'missing.csv'))$pass)
b<-a;b$NAME_1[1]<-'Equ<U+00E9>ateur';write.csv(b,q,row.names=FALSE)
check('Unicode escape artifact fails',!compare_csv_content(p,q)$pass)
write.csv(a,file.path(scratch,'reproduction_csv_checks.csv'),row.names=FALSE)
write.csv(a,file.path(scratch,'reproduction_raster_checks.csv'),row.names=FALSE)
check('comparison receipts excluded from discovery',identical(reproduction_csv_files(scratch),c('a.csv','b.csv')))
cat(n,'comparison checks passed\n')
