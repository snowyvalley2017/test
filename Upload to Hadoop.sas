%LET host_nm =hive.sys.cigna.com;
%LET port_num = 25006;
%let stat_in= c41621_inov_mbr;

%let scrh_scm=CIMA_SCRATCH; /*Hadoop schema name for all intermediate datasets*/
%let scrh_lib=SAE_SCRH; /*Hadoop schema libname for all intermediate datasets*/

libname &scrh_lib. hadoop SERVER="&host_nm" PORT=&port_num
     subprotocol=hive2 
     HDFS_TEMPDIR='hdfs://nameservice1/saseg' schema=&scrh_scm.  
     DBMAX_TEXT=30;


     DATA &scrh_lib..&STAT_IN.;
           SET c41621_mbr2;  /*you can specify keep option*/
     RUN;
