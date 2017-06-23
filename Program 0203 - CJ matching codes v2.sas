LIBNAME IDS_STD TERADATA database=INSIGHT_STDVIEW_PVS user="C41621@LDAP" password=&password
server=lshtd mode=teradata connection=global direct_sql=yes; options compress=yes ;

LIBNAME IDS_INT TERADATA database=INSIGHT_INTVIEW_PVS user="C41621@LDAP" password=&password
server=lshtd mode=teradata connection=global direct_sql=yes; options compress=yes ;

libname c41621 oracle schema=&userid  path=CCDRPROD.CIGNA.COM user=&userid password=&password dbindex=no; *SASApp to Oracle;

LIBNAME DL TERADATA user="c41621@LDAP"  password=&password
database=dl_team_manocchia server=lshtd mode=teradata connection=global direct_sql=yes;

libname extract '\\WDCNAP532\Reposit1\WA_New4\Crystal';
libname perm '/sasem/sasusr/c41621';

/*Use pac_one_to_three to match - CAP agent*/
data agent;
set perm.pac_one_to_three;
where employee_id in ('361921','361882','364424','364480','364524');
run;*15;

data match(drop=n o xemployee_id xmatch_seq xmatch_grp);
	set agent;
retain n o xemployee_id;

if _n_ = 1 then do;
	match_grp = 1;
	n = match_grp;
	match_seq = 1;
	o = match_seq;
	xemployee_id = employee_id;
	xmatch_seq = match_seq;
	xmatch_grp = match_grp;
end;
	else if employee_id = xemployee_id then do;
	o + 1;
	match_grp = n;
	match_seq = o;
	xemployee_id = employee_id;
end;
	else if employee_id ne xemployee_id then do;
	n + 1;
	match_grp = n;
	match_seq = 1;
	o = match_seq;
	xemployee_id = employee_id;
	xmatch_seq = match_seq;
	xmatch_grp = match_grp;
end;
run;

/* Consolidate the study and treatment employees */

proc sql;
create table study as
select distinct employee_id, match_grp, 0 as match_seq
from match;
quit;

proc sql;
create table control as
select distinct c_employee_id as employee_id, match_grp, match_seq
from match;
quit;

data append;
	set study control;
run;

proc sort data=append;
	by match_grp match_seq;
run;

data pac_match_grp_seq;
	set append;
run;

/*Combine the match grp and match_seq to call data*/
proc sql;
create table pac_test as
select a.*, match_grp, match_seq
from perm.pac_proclaim_clm a, pac_match_grp_seq b
where a.cdp_emp_id = b.employee_id
and ((a.paid_date between '25mar2015'd and '24jun2015'd) or (a.paid_date between '13jul2015'd and '12oct2015'd))
and diagnosis_code ne '0'
;
quit;*96,870;

proc sort data=pac_test
	(keep=cdp_emp_id paid_date claim_number customer_age member_sex diagnosis_code orig_adj paid_denied match_grp match_seq) out=sort2;
	by match_grp match_seq diagnosis_code member_sex customer_age paid_date;
run;


/*START MATCHING ON 
•	Claim diagnosis - diagnosis_code
•	Customer gender - member_sex
•	Claim date (similar timeframe) - paid_date - within 10 days
•	Customer age band - customer_age within 5 yrs
*/

data stdy_clm;
set sort2;
where match_seq=0;
run; *12,301;

data cntrl_clm;
set sort2;
where match_seq ne 0;
run;*84,569;

proc sql;
create table a as
select distinct
a.cdp_emp_id as study_id,
b.cdp_emp_id as cntrl_id,
a.claim_number as s_clm,
b.claim_number as c_clm,
a.paid_date as s_paid_dt,
b.paid_date as c_paid_dt,
a.diagnosis_code as s_diag,
b.diagnosis_code as c_diag,
a.orig_adj as s_adj,
b.orig_adj as c_adj,
a.paid_denied as s_deny,
b.paid_denied as c_deny,
a.customer_age as s_age,
b.customer_age as c_age,
a.member_sex as s_sex,
b.member_sex as c_sex,
a.match_grp as s_grp,
b.match_grp as c_grp,
a.match_seq as s_seq,
b.match_seq as c_seq
from stdy_clm as a inner join cntrl_clm as b on a.match_grp=b.match_grp
where a.diagnosis_code=b.diagnosis_code
and a.member_sex=b.member_sex
and abs(a.customer_age-b.customer_age)<=5
and abs(a.paid_date - b.paid_date)<=10
order by 1,2
;
quit;*37562;

data b;
set a;
dt_diff=abs(s_paid_dt-c_paid_dt);
age_diff=abs(s_age-c_age);
weight_dt_diff=abs(s_paid_dt-c_paid_dt)/5;
if '25mar2015'd<=s_paid_dt<='24jun2015'd then period='pre';
else if '13jul2015'd<=s_paid_dt<='12oct2015'd then period='pst';
run;

data c;
set b;
if period='' then delete;
sum_diff=weight_dt_diff+age_diff;
run;*37562 - cntrl 15787 study 6050 ;

proc sort data=c;
by s_grp s_clm c_seq sum_diff;
run;

/*chk*/
proc sql;
create table chk as
select distinct 
s_clm, c_clm,s_grp,c_grp,s_seq, c_seq, sum_diff
from c;
quit;

proc sql;
create table cnt as
select distinct s_grp,c_grp,s_seq,c_seq, s_clm,
count(s_clm) as s_clm_cnt
from chk
group by 1,2,3,4,5
order by s_clm, s_grp, c_grp, s_seq, c_seq
;
quit;

proc sql;
create table cnt2 as
select distinct
*,
count(distinct s_clm||put(c_seq, date9.)) as row_cnt
from cnt
group by s_clm
order by s_clm, s_grp, c_grp, s_seq, c_seq
;quit;

data z;
set cnt2;
where row_cnt=3;
run;*4744;

proc sql;
create table y as
select distinct *, min(s_clm_cnt) as min_cnt
from z
group by s_clm
order by s_clm, s_grp, c_grp, s_seq, c_seq
;quit;
*using y as reference for how many records should be kept for each study case;

proc sql;
create table d as
select distinct *
from c where s_clm in (select s_clm from y)
;
quit;

proc sort data=d;
by s_clm c_seq sum_diff;
run;

data num;
set d;
by s_clm c_seq sum_diff;
if first.c_seq then n=1;
else n+1;
run;

proc sql;
create table e as
select distinct
a.*,
b.min_cnt
from num as a left join y as b on a.s_clm=b.s_clm
order by s_clm, c_seq, n;
quit;

data f;
set e;
if n>min_cnt then out=1; else out=0;
run;

proc sort data=f;
by c_clm sum_diff;
run;

data f0;
set f;
by c_clm sum_diff;
if first.c_clm then n_c=1;
else n_c+1;
run;

proc sort data=f0;
by s_clm c_seq n;
run;

*new try;
proc sql;
create table keep_list as 
select distinct *
from f0 
where out=0 and n_c=1;
quit;*4529;

proc sql;
create table rest as
select distinct *
from f0 where c_clm not in (select c_clm from keep_list)
;
quit;*9544;

data combo;
set keep_list rest;
drop n min_cnt out n_c;
run;*14073;

/*chk again*/
proc sql;
create table chk as
select distinct 
s_clm, c_clm,s_grp,c_grp,s_seq, c_seq, sum_diff
from combo;
quit;

proc sql;
create table cnt as
select distinct s_grp,c_grp,s_seq,c_seq, s_clm,
count(s_clm) as s_clm_cnt
from chk
group by 1,2,3,4,5
order by s_clm, s_grp, c_grp, s_seq, c_seq
;
quit;

proc sql;
create table cnt2 as
select distinct
*,
count(distinct s_clm||put(c_seq, date9.)) as row_cnt
from cnt
group by s_clm
order by s_clm, s_grp, c_grp, s_seq, c_seq
;quit;

data z;
set cnt2;
where row_cnt=3;
run;*2344 - 2314 - 2314 - 2314;

proc sql;
create table y as
select distinct *, min(s_clm_cnt) as min_cnt
from z
group by s_clm
order by s_clm, s_grp, c_grp, s_seq, c_seq
;quit;
*using y as reference for how many records should be kept for each study case;

proc sql;
create table g as
select distinct *
from combo where s_clm in (select s_clm from y)
;
quit;*8575 - 8449 - 8445;

proc sort data=g;
by s_clm c_seq sum_diff;
run;

data num;
set g;
by s_clm c_seq sum_diff;
if first.c_seq then n=1;
else n+1;
run;

proc sql;
create table h as
select distinct
a.*,
b.min_cnt
from num as a left join y as b on a.s_clm=b.s_clm
order by s_clm, c_seq, n;
quit;

data i;
set h;
if n>min_cnt then out=1; else out=0;
run;

proc sort data=i;
by c_clm sum_diff;
run;

data i0;
set i;
by c_clm sum_diff;
if first.c_clm then n_c=1;
else n_c+1;
run;

proc sort data=i0;
by s_clm c_seq n;
run;*8575 - 8449 - 8445;

*new try;
proc sql;
create table keep_list as 
select distinct *
from i0 
where out=0 and n_c=1;
quit;*3074 - 3061 -3060;

proc sql;
create table rest as
select distinct *
from i0 where c_clm not in (select c_clm from keep_list)
;
quit;*5421 - 5384 -5385;

data combo;
set keep_list rest;
drop n min_cnt out n_c;
run;*8495 - 8445 - 8445;

*re-run the above section - from line 271 to 380 until no new records from rest added to keep list;
data j;
set keep_list rest;
run; 

proc sort data=j;
by descending n_c c_clm;
run;

data j0;
set j;
where out=0;
run;
/*test*/
proc sql;
create table test as
select distinct
*,
count(c_clm) as cnt
from j0
group by c_clm
order by cnt desc, c_clm , n_c
;
quit;*4099 total;

data first;
set test;
by descending cnt c_clm n_c;
if first.c_clm;
run;*3189;
/*test end*/

/*chk*/
proc sql;
create table chk as
select distinct 
s_clm, c_clm,s_grp,c_grp,s_seq, c_seq, sum_diff
from first;
quit;

proc sql;
create table cnt as
select distinct s_grp,c_grp,s_seq,c_seq, s_clm,
count(s_clm) as s_clm_cnt
from chk
group by 1,2,3,4,5
order by s_clm, s_grp, c_grp, s_seq, c_seq
;
quit;

proc sql;
create table cnt2 as
select distinct
*,
count(distinct s_clm||put(c_seq, date9.)) as row_cnt
from cnt
group by s_clm
order by s_clm, s_grp, c_grp, s_seq, c_seq
;quit;

data z;
set cnt2;
where row_cnt=3;
run;*4744;

proc sql;
create table y as
select distinct *, min(s_clm_cnt) as min_cnt
from z
group by s_clm
order by s_clm, s_grp, c_grp, s_seq, c_seq
;quit;*2301;
*using y as reference for how many records should be kept for each study case;

proc sql;
create table g as
select distinct *
from first where s_clm in (select s_clm from y)
;
quit;*3181;

data g; set g; drop n min_cnt out n_c cnt; run;

proc sort data=g;
by s_clm c_seq sum_diff;
run;

data num;
set g;
by s_clm c_seq sum_diff;
if first.c_seq then n=1;
else n+1;
run;

proc sql;
create table h as
select distinct
a.*,
b.min_cnt
from num as a left join y as b on a.s_clm=b.s_clm
order by s_clm, c_seq, n;
quit;

data i;
set h;
if n>min_cnt then out=1; else out=0;
run;

proc sort data=i;
by c_clm sum_diff;
run;

data i0;
set i;
by c_clm sum_diff;
if first.c_clm then n_c=1;
else n_c+1;
run;*3181;

data i00;
set i0;
where out=0;
run;*3171;

/*test*/
proc sql;
create table test as
select distinct
*,
count(c_clm) as cnt
from i00
group by c_clm
order by cnt desc, c_clm , n_c
;
quit;*3171 total;

data first;
set test;
by descending cnt c_clm n_c;
if first.c_clm;
run;*3171;
/*test end*/

proc freq data=i00;
table period*s_grp*c_seq;
run;

* one claim splits by two agents - delete from analysis
364424	364390	9431512493979	4681521690259	13AUG2015	13AUG2015	780	780	Adjustment	Original	Denied	Paid	59	63	F	F	3	3	0	3	0	4	0	pst	4	1	1	0	1
364480	364398	9431512493979	7651513507384	14MAY2015	19MAY2015	780	780	Original	Original	Paid	Paid	59	56	F	F	4	4	0	1	5	3	1	pre	4	1	1	0	1
364480	364423	9431512493979	8431512702801	14MAY2015	09MAY2015	780	780	Original	Original	Paid	Paid	59	60	F	F	4	4	0	2	5	1	1	pre	2	1	1	0	1
;

data i000; set i00;
if s_clm='9431512493979' then delete;
run;*3168;

proc freq data=i000;
table period*s_grp*c_seq;
run;

proc sql; select distinct period, count(distinct s_clm) as cnt from i00 group by 1; quit; 

data perm.pac_proclaim_clm_matched;
set i000;
run; *total 3168 records;
*cntrol: 1057 claims in each group: 296 pre, 760 post ;
* study: 768 claims in study group: 251 pre, 517 post;

