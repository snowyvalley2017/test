

option SASTRACE = ",,,d" sastraceloc=saslog;
options dsaccel=any;  /*DSACCEL=any  enables the DATA step to execute in supported parallel environments*/
options ds2accel=any; /*DS2ACCEL=any enables the DATA step to execute in-database*/
options msglevel=i;   /*MSGLEVEL=I enables the user to see which options prevent or affect in-database processing*/
/*these are for encouraging in-db processing*/
options DBIDIRECTEXEC SQLGENERATION=DBMS;/* Avoids downloads when creating tables via IP; not a default setting */
options SQL_IP_TRACE=SOURCE; /*SQL_IP_TRACE=SOURCE - Shows SQL push down*/
options SPDEPARALLELREAD=yes FULLSTIMER SPOOL;	

LIBNAME HDP_CIMA HADOOP SERVER='cilhdedp0201.sys.cigna.com' subprotocol=hive2 HDFS_TEMPDIR='/saseg'  
SCHEMA=cima dbconinit="set hive.exec.parallel=true;set mapred.job.queue.name=model_1";
LIBNAME HDP_SCRH HADOOP SERVER='cilhdedp0201.sys.cigna.com' subprotocol=hive2 HDFS_TEMPDIR='/saseg'  
SCHEMA=cima_scratch;
LIBNAME sandbox HADOOP SERVER='cilhdedp0201.sys.cigna.com' subprotocol=hive2 HDFS_TEMPDIR='/saseg'  
SCHEMA=c53310_sandbox;

%LET DATETIME_START= %SYSFUNC(TIME());

/* to get a cord per member or based on your portioning variables  */

PROC SQL;
	CONNECT TO HADOOP (SERVER='CILHDEDP0201.SYS.CIGNA.COM' );
	EXECUTE(SELECT A.*
    FROM 
    (
    SELECT DISTINCT 
        ACCT_NUM,
        ASSMT_DT,
        MEMBR_NUM,
        C11_029_HHR_RC_BLKO_TPP,
        C14_008_ENRL_COLG_PP,
        C25_080_ROHU_AVG_GRS_RENT,
        C19_003_HH_INCM_MDN,
        AC_NIELSEN_CNTY_SZ_CD,
        ROW_NUMBER() OVER (PARTITION BY MEMBR_NUM
        ORDER BY ASSMT_DT DESC ) AS RNUM
        FROM INSIGHT_VIEW_PRD.CENSUS ) A
    WHERE RNUM =1 LIMIT 100
		) BY HADOOP;
	DISCONNECT FROM HADOOP;
QUIT;

/*  SELECT DISTINCT and GROUP BY can not be in the same query. 
remove either one depends on need */

PROC SQL;
	CONNECT TO HADOOP (SERVER='CILHDEDP0201.SYS.CIGNA.COM' );
	EXECUTE(
			SELECT DISTINCT MBR_NUM, 
			SUM(ELGBL_CHRG_AMT) AS ELGBL_CHRG_AMT 
			FROM ARCHIVE_INSIGHT_BASE_PVS_CLAIM 
				WHERE  ACCT_NUM = ('3331749')  
				AND TO_DATE(SVC_DT) BETWEEN '2014-01-01' AND '2014-01-10'    
				GROUP BY MBR_NUM LIMIT 100;
	) BY HADOOP;
	DISCONNECT FROM HADOOP;
QUIT;

/* Error while compiling statement: FAILED: SemanticException TOK_ALLCOLREF is not supported in current context 

can't use ' * ' to select all columns with joins in Hadoop, list all( as per need) columns

*/

PROC SQL;
	CONNECT TO HADOOP (SERVER='CILHDEDP0201.SYS.CIGNA.COM' );
	EXECUTE(
	SELECT DISTINCT A.*, B.VENDR_NM FROM 
    C53310_SANDBOX.TEMP_3331749 A LEFT JOIN  
    C53310_SANDBOX.CENCES   B
    ON A.MEMBR_NUM =B.MEMBR_NUM 
    LIMIT 100;
	) BY HADOOP;
	DISCONNECT FROM HADOOP;
QUIT;


/* TO GET A REOCRD PER MEMBER FROM MEMBR_DIM */
PROC SQL;
	CONNECT TO HADOOP (SERVER='CILHDEDP0201.SYS.CIGNA.COM' );
	EXECUTE(SELECT DISTINCT A.ACCT_NUM,A.MEMBR_NUM,MEMBR_STATE_CD ,
		MEMBR_ZIP_CD , 
		HOME_ADDR_CITY_NM,
	FROM (SELECT DISTINCT 
		ACCT_NUM,
		MEMBR_NUM,
		MEMBR_KEY,
		HOME_ADDR_STE_CD AS MEMBR_STATE_CD ,
		HOME_ADDR_POSTL_CD AS MEMBR_ZIP_CD , 
		HOME_ADDR_CITY_NM,
		DW_UPDT_AUD_KEY,
		ROW_NUMBER() OVER (PARTITION BY MEMBR_NUM, ACCT_NUM )  AS RNUM
	FROM CIMA.CCDM_MSTR_MEMBR_DIM  WHERE   
		DW_CURR_IND = 'Y' AND CHNL_SRC_CD NOT IN ('CBH') 
	ORDER by  DW_UPDT_AUD_KEY desc limit 100) A 

	WHERE RNUM= 1 ) BY HADOOP;
	DISCONNECT FROM HADOOP;
QUIT;


/* to get a cord per member or based on your portioning variables  */
--- Teradata
		SELECT DISTINCT 
		    ACCT_NUM,
		    ASSMT_DT,
		    MEMBR_NUM,
		    C11_029_HHR_RC_BLKO_TPP,
		    C14_008_ENRL_COLG_PP,
		    C25_080_ROHU_AVG_GRS_RENT,
		    C19_003_HH_INCM_MDN,
		    AC_NIELSEN_CNTY_SZ_CD
    FROM INSIGHT_VIEW_PRD.CENSUS
    QUALIFY ROW_NUMBER() OVER (PARTITION BY MEMBR_NUM
    ORDER BY ASSMT_DT DESC ) = 1  SAMPLE 100
    ;
			

---	Hadoop
	
	SELECT A.*
    FROM 
    (
    SELECT DISTINCT 
        ACCT_NUM,
        ASSMT_DT,
        MEMBR_NUM,
        C11_029_HHR_RC_BLKO_TPP,
        C14_008_ENRL_COLG_PP,
        C25_080_ROHU_AVG_GRS_RENT,
        C19_003_HH_INCM_MDN,
        AC_NIELSEN_CNTY_SZ_CD,
        ROW_NUMBER() OVER (PARTITION BY MEMBR_NUM
        ORDER BY ASSMT_DT DESC ) AS RNUM
        FROM INSIGHT_VIEW_PRD.CENSUS ) A
    WHERE RNUM =1 LIMIT 100
    ;



/* data loading */


LIBNAME SrxPhar TERADATA user= "&User_id@LDAP" password= "&td_pw"
database=rxSpecialty server=wdctd2 mode=teradata connection=global direct_sql=yes ;



/* load TD to Hadoop */

PROC SQL NOERRORSTOP;
	CONNECT TO TERADATA(USER= "&USER_ID@LDAP" PASSWORD= "&TD_PW"
		DATABASE=INSIGHT_VIEW_PRD SERVER=WDCTD2 MODE=TERADATA);
	create table SANDBOX.ACCOUNT_CLIENT as 
		Select * 
			From Connection to TERADATA 
				(select * from  INSIGHT_VIEW_PRD.ACCOUNT_CLIENT
);
	Disconnect FROM TERADATA;
QUIT;

/*  load Hadoop to TD */

PROC SQL  NOERRORSTOP;
	CONNECT TO HADOOP (SERVER='CILHDEDP0201.SYS.CIGNA.COM');
	CREATE  TABLE SRXPHAR.MED_ETG_HADOOP( TPT=yes fastload=yes tpt_max_sessions=10
dbcreate_table_opts='PRIMARY INDEX(MEMBR_NUM)') AS 
		SELECT * FROM CONNECTION TO HADOOP 
			(	SELECT * from C53310_SANDBOX.MED_ETG_TEMP 	);
	DISCONNECT FROM HADOOP;
QUIT;

/* load SAS to Teradata */
Proc Sql;
create table SRxphar.&etg_table. (TPT=yes fastload=yes tpt_max_sessions=5
dbcreate_table_opts='PRIMARY INDEX(mbr_num)') as
select * from   wdc6001.&etg_table.;
quit;


/* load SAS to Hadoop */
Proc Sql;
create table SANDBOX.&etg_table.  as
select * from   wdc6001.&etg_table.;
quit;
