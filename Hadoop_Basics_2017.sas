/*  Assign User ID  */
data _null_;
 call symput ('userid',compress(lowcase(&_CLIENTUSERID),,'p'));
run;



/*******************************/
/*  Hadoop Libname Statements  */
/*******************************/
libname cima hadoop PORT=25006 server='hive.sys.cigna.com' subprotocol=hive2 HDFS_TEMPDIR='/saseg/' schema=cima
             dbconinit="set hive.exec.parallel=true; set mapred.job.queue.name=sas.g_hadoop_p_cima";
libname default hadoop PORT=25006 server='hive.sys.cigna.com' subprotocol=hive2 HDFS_TEMPDIR='/saseg/' schema=default
                dbconinit="set hive.exec.parallel=true; set mapred.job.queue.name=sas.g_hadoop_p_cima";
libname scratch hadoop PORT=25006 server='hive.sys.cigna.com' subprotocol=hive2  HDFS_TEMPDIR='/saseg/' schema=cima_scratch
	            dbconinit="set hive.exec.parallel=true; set mapred.job.queue.name=sas.g_hadoop_p_cima";
libname sandbox hadoop PORT=25006 server='hive.sys.cigna.com' subprotocol=hive2  HDFS_TEMPDIR='/saseg/' schema=&userid._sandbox
                dbconinit="set hive.exec.parallel=true; set mapred.job.queue.name=sas.g_hadoop_p_cima";



/********************/
/*  Hadoop Options  */
/********************/
OPTIONS COMPRESS = YES DBIDIRECTEXEC OBS = Max
SASTRACE=',,,ds' 
SASTRACELOC=Saslog nostsuffix 
MSGLEVEL = I 
SQL_IP_TRACE = SOURCE 
Debug=DBMS_Timers 
DBIDIRECTEXEC
SQLGENERATION = DBMS;



/******************************************************/
/*  Query Example – Schema Table List & Descriptions  */
/******************************************************/

/*  Produce a list of all tables within a schema:  */
proc sql;
 connect to hadoop (port=25006 server='hive.sys.cigna.com');
 execute(set mapred.job.queue.name=sas.g_hadoop_p_cima) by hadoop;
 select * from connection to hadoop 
  (show tables in cima);
 disconnect from hadoop;
quit;

/*  Produce a list of columns and formats within a table:  */
proc sql;
 connect to hadoop (port=25006 server='hive.sys.cigna.com');
 execute(set mapred.job.queue.name=sas.g_hadoop_p_cima) by hadoop;
 select * from connection to hadoop 
  (describe formatted cima.ccdm_mart_prof_etg_epsde_clm);
 disconnect from hadoop;
quit;

/*  Using “show tables” allows you to view tables with names longer than 32 characters  */
/*  Using “describe formatted” allows you to view true Hadoop formats  */
/*  Use the cima queue in each explicit query to expedite the processes  */



/******************************************************/
/*  Query Example – Moving Data Between SAS & Hadoop  */
/******************************************************/

/*  Run the necessary libname statements to activate your libraries:  */
libname scratch hadoop PORT=25006 server='hive.sys.cigna.com' subprotocol=hive2  HDFS_TEMPDIR='/saseg/' schema=cima_scratch
	            dbconinit="set hive.exec.parallel=true; set mapred.job.queue.name=sas.g_hadoop_p_cima";

/*  Create data from an external source in a SAS work table  */
proc sql;
 connect to db2 (dsn=crdmplin authdomain=CRDM_Auth);
 create table work.cac_alignmnt as 
 select indiv_enterprise_id,
        rpt_end_dt,
        alignmnt_cd,
		put(year(rpt_end_dt),4.)||'Q'||put(qtr(rpt_end_dt),1.) as period
 from connection to db2 (
 select *
 from appdm.cac_alignmnt
 where mrkt_cd = 'TN1'
 order by rpt_end_dt desc
 fetch first 100 rows only);
 disconnect from db2;
quit;

/*  Move data from SAS to Hadoop to utilize in Hadoop processes:  */
proc sql;
 create table scratch.&userid._mrktmbrs_temp_2016q3 as
 select indiv_enterprise_id,
        rpt_end_dt,
        alignmnt_cd,
        period
 from work.cac_alignmnt;
quit;

/*  Pulling data from Hadoop to SAS for processing:  */
proc sql;
 connect to hadoop (port=25006 server='hive.sys.cigna.com');
 execute(set mapred.job.queue.name=sas.g_hadoop_p_cima) by hadoop;
 create table work.risk_scores as select * from connection to hadoop
 (select a.indiv_enterprise_id,
         a.membr_age,
         a.gendr_cd,
         a.retrsp_risk,
         a.rptng_end_dt
  from cima.ccdm_mart_prof_erg_risk a inner join cima_scratch.&userid._mrktmbrs_temp_2016q3 b 
                                      on (a.indiv_enterprise_id = b.indiv_enterprise_id) and
                                         (to_date(a.rptng_end_dt) = to_date(b.rpt_end_dt)));
 disconnect from hadoop;
quit;

/*  Delete tables when no longer necessary  */
proc sql; drop table scratch.&userid._mrktmbrs_temp_2016q3; quit;



/***********************************************************/
/*  Query Example - Guidelines for Creating Hadoop Tables  */
/***********************************************************/

/*  Tables can be written to the CIMA Scratch schema or a Sandbox schema (if you have access to one)  */
/*  Use naming conventions that are consistent and personally identifiable:  */
    /*  Consider including either your initials or LAN ID,  the type of project/work, and an indication of the table’s timeframe  */
    /*  – ex. m76982_CACclaims_temp_2016q3  */
/*  Use a drop table statement before you execute a create table statement; Hadoop will not overwrite an existing table  */
proc sql;
 connect to hadoop (port=25006 server='hive.sys.cigna.com');
 execute (set mapred.job.queue.name=sas.g_hadoop_p_cima) by hadoop;
 execute (drop table cima_scratch.&userid._pregepsd_temp_2015q4) by hadoop;
 execute (create table cima_scratch.&userid._pregepsd_temp_2015q4) as
  select memberid,
         masterepisodeid
  from opensae_eoc.episodelevelassociation limit 100
  where episodeacronym = 'PREGN'
  group by memberid, masterepisodeid) by hadoop;
quit;

/*  Include statements for deletion of these tables in your code when they are no longer required  */
    /*  These statements can be commented out until needed  */
proc sql; drop table scratch.&userid._pregepsd_temp_2015q4; quit;



/********************************************************/
/*  Query Example - Implicit vs Explicit 				*/
/********************************************************/

/*  Run the necessary libname statements to activate your libraries for Implicit connection:  */
libname episode hadoop PORT=25006 server='hive.sys.cigna.com' subprotocol=hive2  HDFS_TEMPDIR='/saseg/' schema=opensae_eoc
                dbconinit="set hive.exec.parallel=true; set mapred.job.queue.name=sas.g_hadoop_p_cima";
/*  Implicit Connection  */
proc sql;
create table work.tmp_epsd_preg as
select memberid, masterepisodeid, episodeacronym, childmasterepisodeid, 
	   childepisodeacronym
from episode.episodelevelassociation_base
where  episodeacronym = 'PREGN'
  and level = 5
  and associationpoint = 1
  and subset_run_date = '2017-01-24'
  and market_subset = 'BOB'
  and report_begin_date = '2013-04-01'
  and report_end_date = '2016-03-31'
order by masterepisodeid;
quit;

/*  Explicit Connection  */
proc sql noerrorstop;
connect to hadoop (PORT=25006 server='hive.sys.cigna.com');
execute(set mapred.job.queue.name=sas.g_hadoop_p_cima) by hadoop;
create table work.tmp_epsd_preg as select * from connection TO hadoop (
select memberid, masterepisodeid, episodeacronym, childmasterepisodeid, 
	   childepisodeacronym
from opensae_eoc.EpisodeLevelAssociation_base 
where  episodeacronym = 'PREGN'
  and level = 5
  and associationpoint = 1
  and subset_run_date = '2017-01-24'
  and market_subset = 'BOB'
  and report_begin_date = '2013-04-01'
  and report_end_date = '2016-03-31'
order by masterepisodeid);
disconnect from hadoop; 
quit;



/*****************************************************************/
/*  Query Example – Using Count Distinct for Multiple Variables  */
/*****************************************************************/

/*  Multiple instances of count distinct will fail within 1 select statement:  */

/*  This can be resolved using the Hive analytics function PARTITION BY:  */
proc sql;
 connect to hadoop (port=25006 server='hive.sys.cigna.com');
 execute(set mapred.job.queue.name=root.g_hadoop_p_cima) by hadoop;
 select * from connection to hadoop
 (select count(distinct membr_num) as mbr_cnt,
         count(distinct clm_num) over (partition by clm_num) as clm_cnt
  from cima.insight_intview_prd_intgrd_med_clm
  where svc_dt_yr_mth = '201609');
 disconnect from hadoop;
quit;

/*  Or you can use multiple select statements with a CROSS JOIN:  */
proc sql;
 connect to hadoop (port=25006 server='hive.sys.cigna.com');
 execute(set mapred.job.queue.name=root.g_hadoop_p_cima) by hadoop;
 select * from connection to hadoop
 ((select count(distinct mbr_num) as mbr_cnt
   from ids.clinical_med_claims_tst limit 100) t1
  cross join
  (select count(distinct clm_num) as clm_cnt
   from ids.clinical_med_claims_tst limit 100) t2);
 disconnect from hadoop;
quit;


**************************************************************************************************************************/;




























































/********************************************/
/*Creating Tables in Hadoop					*/
/********************************************/

/*Using Cima Scratch Schema*/

Proc Sql  NOERRORSTOP;
	connect to hadoop (port=25006 server='hive.sys.cigna.com');
	execute (set mapred.job.queue.name=root.g_hadoop_p_cima) by hadoop;
	execute (drop table cima_scratch.tmp_abc_epsd_preg) by hadoop;
	execute (create table cima_scratch.tmp_abc_epsd_preg) AS
	select 
		memberid, 
		masterepisodeid, 
		episodeacronym, 
		childmasterepisodeid, 
		childepisodeacronym
	From opensae_eoc.EpisodeLevelAssociation  
		where  episodeacronym = 'PREGN'
			and level = 5
			and associationpoint = 1
		group by memberid, masterepisodeid, episodeacronym, childmasterepisodeid, 
				childepisodeacronym 
		order by   masterepisodeid
	) by hadoop;
Quit;

proc sql;
 connect to hadoop (port=25006 server='hive.sys.cigna.com');
 execute (set mapred.job.queue.name=root.g_hadoop_p_cima) by hadoop;
 execute (drop table cima_scratch.m76982_pregepsd_temp_2015q4) by hadoop;
 execute (create table cima_scratch.m76982_pregepsd_temp_2015q4) as
  select memberid,
         masterepisodeid
  from opensae_eoc.episodelevelassociation
  where episodeacronym = 'PREGN'
  group by memberid, masterepisodeid) by hadoop;
quit;

proc sql; drop table scratch.m76982_pregepsd_temp_2015q4; quit;

proc sql;
 connect to hadoop (port=25006 server='hive.sys.cigna.com');
 create table test as select * from connection to hadoop (
 select *
 from opensae_eoc.episodelevelassociation limit 100);
 disconnect from hadoop;
quit;

