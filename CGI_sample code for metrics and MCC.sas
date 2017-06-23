
data test (drop= diag3d icd_Cd rename=(diag3d_1=diag3d) rename=(icd_cd1=icd_cd));
set test;

/* Format dates */

 if benefit_start_dt ne . and year(benefit_start_dt)  <1960 then bsd=intnx('year',benefit_start_dt,100,'same');
else bsd=benefit_start_dt;
if benefit_termination_dt ne . and year(benefit_termination_dt)  <1960 then btd=intnx('year',benefit_termination_dt,100,'same');
else btd=benefit_termination_dt;
if incurred_date ne . and year(incurred_date)  <1960 then incd=intnx('year',incurred_date,100,'same');
else  incd=incurred_date;
if receive_date ne . and year(receive_date)  <1960 then rd=intnx('year',receive_date,100,'same');
else  rd=receive_date;
if current_status_dt ne . and year(current_status_dt)  <1960 then csd=intnx('year',current_status_dt,100,'same');
else csd=current_status_dt;
/*date2 = input(compress(medical_approved_thru_dt,'/'),mmddyy6.) ;*/
if medical_approved_thru_dt ne . and year(medical_approved_thru_dt)  <1960 then matd=intnx('year',medical_approved_thru_dt,100,'same');
else matd=medical_approved_thru_dt;
if Registration_Tp ne . and year(Registration_Tp)  <1960 then regd=intnx('year',Registration_Tp,100,'same');
else regd=Registration_Tp;
if paid_thru_dt ne . and year(paid_thru_dt)  <1960 then ptd=intnx('year',paid_thru_dt,100,'same');
else ptd=paid_thru_dt;

format bsd btd incd rd regd csd matd ptd date9.;

/* 3-digit diagnosis */

diag3d_1=put(diag3d, $3.);
icd_cd1=compress(put(icd_cd, $5.));


/* decision time */
if rec_to_dec_days>=0 and decisions=1 then dec_time=rec_to_dec_days; 
/* Percent decisions made within 5 days */
if product_group_cd="STD" and decisions=1 and 0<=rec_to_dec_days<=5 
     then within_5_days=1;else if decisions=1 and rec_to_dec_days>5 then within_5_days=0; 
 /* Percent decisions made within 10 days */
if product_group_cd="STD" and decisions=1 and 0<=rec_to_dec_days<=10 
     then within_10_days=1;else if decisions=1 and rec_to_dec_days>10 then within_10_days=0;
/* Age of claimant as of today */
age_backup = round(datdif(Birth_Dt,today(),'act/act')/365.25); 
/* Gender of claimant */
if gender_cd="M" then male=1; else male=0; 

/* Yearly Salary calculation */
  sal=compensation_amt;
if (Payroll_Frequency_Cd="M" and compensation_amt<=1) or (Payroll_Frequency_Cd="M" and compensation_amt>=15000) then sal=4637; 
if (Payroll_Frequency_Cd="Y" and compensation_amt<=100) or (Payroll_Frequency_Cd="Y" and compensation_amt>=500000) then sal=45000; 
if (Payroll_Frequency_Cd="W" and compensation_amt<=10) or (Payroll_Frequency_Cd="W" and compensation_amt>=3500) then sal=517; 
if (Payroll_Frequency_Cd="H" and compensation_amt<=1) or (Payroll_Frequency_Cd="H" and compensation_amt>=131) then sal=16; 
if (Payroll_Frequency_Cd="B" and compensation_amt<=45) or (Payroll_Frequency_Cd="B" and compensation_amt>=7350) then sal=1586; 
if Payroll_Frequency_Cd="W" then yrly_pay=sal*4*12;
else if Payroll_Frequency_Cd="Y" then yrly_pay=sal;
else if Payroll_Frequency_Cd="H" then yrly_pay=sal*160*12;
else if Payroll_Frequency_Cd="M" then yrly_pay=sal*12;
else if Payroll_Frequency_Cd="B" then yrly_pay=sal*26;

/* Impute salary and age with median values */

if yrly_pay<1000 then yrly_pay=41242;
if age_backup>=70 then age_backup=70;
  if age_backup<10 then age_backup=45;

/* Lag Time */
if rd>=incd then lag_time_new=rd-incd; 

/* Load Time */
load_time=Receive_To_Registration_Day; 

/* Complexity=1 --> Low-complex claims */
/* Complexity=3 --> High-complex claims */

if  compress(latest_complexity_desc) ne "" and compress(lowcase(latest_complexity_desc))="level3" then cmplx3=1;else cmplx3=0;
if compress(latest_complexity_desc) ne "" and compress(lowcase(latest_complexity_desc))="level1" then cmplx1=1;else cmplx1=0;

/* Logic for claim approval */
If (Rec_To_Dec_Days < 0 or Rec_To_Dec_Days=.) then approved_new =.;
else if (lowcase(claim_status_code)="activ" and Rec_To_Dec_Days >0) OR
(lowcase(claim_status_code)="pend" and lowcase(Status_Reason_Cd)='succi' and Rec_To_Dec_Days >0) OR 
(lowcase(claim_status_code)="close"and Paid_To_Date_Amt>0 and Rec_To_Dec_Days >0) OR 
(bsd = btd and matd >= bsd)  OR
(financial_arrangement_cd=2 and btd > bsd) then approved_new =1; 

/* Logic for claim duration for closed claims */
if lowcase(claim_status_code)="close" and (btd>=matd and matd ne .) and approved_new=1 then dur2_new=matd-incd;
if lowcase(claim_status_code)="close" and matd =. and (btd>=ptd and ptd ne .) and approved_new=1 then dur2_new=ptd-incd;
else if lowcase(claim_status_code)="close" and (btd<=matd and matd ne .) and approved_new=1 then dur2_new=btd-incd; 

/* Logic for claim duration for closed & active claims */
if product_group_cd="STD" and lowcase(claim_status_code)="close" and approved_new=1 then dur1_new=dur2_new;
else if product_group_cd="STD" and lowcase(claim_status_code) ne "close" and approved_new=1 and matd ne .  then dur1_new=matd-incd; 

/* Logic for Return-to-work rate for approved and closed claims */
if product_group_cd="STD" and lowcase(claim_status)="close" and approved_new=1 and lowcase(status_reason_cd)="rtw" 
 and 0<=dur2_new<=180 then rtw_new=1; 
else if product_group_cd="STD" and lowcase(claim_status)="close" and approved_new=1 and lowcase(status_reason_cd) ne "rtw" 
and 0<=dur2_new<=180 then rtw_new=0;

/* Logic for Liability acceptance rate */
if lowcase(claim_status) not in ('pend','pendm') and approved_new=. then lar_new=0; 
   else if lowcase(claim_status) not in ('pend','pendm') and approved_new=1 then lar_new=1;

   run;


  /* Match case code */

data test1;
set test;
if age_backup <= 34  then age = 1;
  else if 34< age_backup <=45 then age =2;
  else if 45<age_backup <= 62 then age = 3;
  else if age_backup > 62 then age = 4;
  ben_per=benefit_period_cd;

  if group="Control" then treatment_group=0;else treatment_group=1; 
  /*if matching across two groups use matching code between line 128 and  289 */

  if group="Control" then treatment_group=0;else if group="Study1" then treatment_group=1; else if group="Study2" then treatment_group=2;
/*if matching across three groups use matching code between line 294 and 470*/
run;

proc sort data=test1 out= test2;
by age male diag3d ben_per occupation_cd;* latest_complexity_Cd; /* list of matching variables */
run;


/* Matching between two groups */

/*START MATCHING MACRO ON MALE, AGE, and STD DIAGNOSIS */

* Step 1a: assign people to strata groups based on categories of stratification (i.e. stratum);
data work.samp4 (drop = n);
set TEST2;
by  age male diag3d ben_per occupation_cd ;* latest_complexity_Cd;
retain n  age_cat male_cat diag3d_cat ben_cat occup_cat;*cmplx_cat;
if _n_ = 1 then do;
	strata = 1;
	n = strata;
	age_cat = age;
	male_cat = male;
	diag3d_cat = diag3d;
	ben_cat=ben_per;
	occup_cat=occupation_cd;
/*	cmplx_cat=latest_complexity_cd;*/
end;
	else if age = age_cat and male = male_cat and diag3d = diag3d_cat 
            and ben_per=ben_cat and occupation_cd=occup_cat /*and 
            latest_complexity_Cd=cmplx_cat*/ then strata = n;
else if age ne age_cat then do;
	strata = n+1;
	n = strata;
	age_cat = age;
	male_cat = male;
	diag3d_cat = diag3d;
	ben_cat=ben_per;
	occup_cat=occupation_cd;
/*	cmplx_cat=latest_complexity_cd;*/
end;
	else if male ne male_cat then do;
	strata = n+1;
	n = strata;
	age_cat = age;
	male_cat = male;
	diag3d_cat = diag3d;
	ben_cat=ben_per;
	occup_cat=occupation_cd;
/*	cmplx_cat=latest_complexity_cd;*/
end;
	else if diag3d ne diag3d_cat then do;
	strata = n+1;
	n = strata;
	age_cat = age;
	male_cat = male;
	diag3d_cat = diag3d;
	ben_cat=ben_per;
	occup_cat=occupation_cd;
/*	cmplx_cat=latest_complexity_cd;*/
end;
else if ben_per ne ben_cat then do;
	strata = n+1;
	n = strata;
	age_cat = age;
	male_cat = male;
	diag3d_cat = diag3d;
	ben_cat=ben_per;
	occup_cat=occupation_cd;
/*	cmplx_cat=latest_complexity_cd;*/
end;
else if occupation_cd ne occup_cat then do;
	strata = n+1;
	n = strata;
	age_cat = age;
	male_cat = male;
	diag3d_cat = diag3d;
	ben_cat=ben_per;
	occup_cat=occupation_cd;
/*	cmplx_cat=latest_complexity_cd;*/
end;
/*else if latest_complexity_cd ne cmplx_cat then do;*/
/*	strata = n+1;*/
/*	n = strata;*/
/*	age_cat = age;*/
/*	male_cat = male;*/
/*	diag3d_cat = diag3d;*/
/*	ben_cat=ben_per;*/
/*	occup_cat=occupation_cd;*/
/*	cmplx_cat=latest_complexity_cd;*/
/*end;*/
run;


/*step 2: now randomize within each stratum and get best matches */

data sample;
set samp4;
run;

proc sql;
	create table work.min_cnt as
		select strata,
			min(cnt_0, cnt_1) as row_cnt
		from (select strata,
				sum(case
					when treatment_group = 0 then 1
					else 0
				end) as cnt_0,
				sum(case
					when treatment_group = 1 then 1
					else 0
				end) as cnt_1
			  from work.sample
			  group by strata)
		group by strata
		having calculated row_cnt > 0;
quit;

data work.sample_rs;
set work.sample;
ran_num = uniform(-1);
run;

Proc sort data=work.sample_rs;
by strata ran_num;
run;

%macro test;

data _null_;
        set work.min_cnt end=last;
        call symput('strata'||left(_n_), trim(strata));
        call symput('rowcnt'||left(_n_), trim(row_cnt));
        if last then call symput('cntr', _n_);
run;

%do i=1 %to &cntr;

proc sql outobs = &&rowcnt&i;
	create table work.mbrs0(drop= ran_num) as
		select *
		from work.sample_rs
		where treatment_group = 0
			and strata = &&strata&i;
quit;

proc sql outobs = &&rowcnt&i;
	create table work.mbrs1(drop= ran_num) as
		select *
		from work.sample_rs
		where treatment_group = 1
			and strata = &&strata&i;
quit;

proc append base=work.study_grps data=work.mbrs0;
run;

proc append base=work.study_grps data=work.mbrs1;
run;
DM "log; clear; ";

%end;

%mend;

%test;

proc freq data=study_grps;
tables treatment_group;
run;

**********************************************************************************;
**********************************************************************************;

/* Matching between three groups */

/*START MATCHING MACRO ON MALE, AGE, and STD DIAGNOSIS */

* Step 1a: assign people to strata groups based on categories of stratification (i.e. stratum);
data work.samp4 (drop = n);
set TEST2;
by  age male diag3d ben_per occupation_cd ;* latest_complexity_Cd;
retain n  age_cat male_cat diag3d_cat ben_cat occup_cat;*cmplx_cat;
if _n_ = 1 then do;
	strata = 1;
	n = strata;
	age_cat = age;
	male_cat = male;
	diag3d_cat = diag3d;
	ben_cat=ben_per;
	occup_cat=occupation_cd;
/*	cmplx_cat=latest_complexity_cd;*/
end;
	else if age = age_cat and male = male_cat and diag3d = diag3d_cat 
            and ben_per=ben_cat and occupation_cd=occup_cat /*and 
            latest_complexity_Cd=cmplx_cat*/ then strata = n;
else if age ne age_cat then do;
	strata = n+1;
	n = strata;
	age_cat = age;
	male_cat = male;
	diag3d_cat = diag3d;
	ben_cat=ben_per;
	occup_cat=occupation_cd;
/*	cmplx_cat=latest_complexity_cd;*/
end;
	else if male ne male_cat then do;
	strata = n+1;
	n = strata;
	age_cat = age;
	male_cat = male;
	diag3d_cat = diag3d;
	ben_cat=ben_per;
	occup_cat=occupation_cd;
/*	cmplx_cat=latest_complexity_cd;*/
end;
	else if diag3d ne diag3d_cat then do;
	strata = n+1;
	n = strata;
	age_cat = age;
	male_cat = male;
	diag3d_cat = diag3d;
	ben_cat=ben_per;
	occup_cat=occupation_cd;
/*	cmplx_cat=latest_complexity_cd;*/
end;
else if ben_per ne ben_cat then do;
	strata = n+1;
	n = strata;
	age_cat = age;
	male_cat = male;
	diag3d_cat = diag3d;
	ben_cat=ben_per;
	occup_cat=occupation_cd;
/*	cmplx_cat=latest_complexity_cd;*/
end;
else if occupation_cd ne occup_cat then do;
	strata = n+1;
	n = strata;
	age_cat = age;
	male_cat = male;
	diag3d_cat = diag3d;
	ben_cat=ben_per;
	occup_cat=occupation_cd;
/*	cmplx_cat=latest_complexity_cd;*/
end;
/*else if latest_complexity_cd ne cmplx_cat then do;*/
/*	strata = n+1;*/
/*	n = strata;*/
/*	age_cat = age;*/
/*	male_cat = male;*/
/*	diag3d_cat = diag3d;*/
/*	ben_cat=ben_per;*/
/*	occup_cat=occupation_cd;*/
/*	cmplx_cat=latest_complexity_cd;*/
/*end;*/
run;


/*step 2: now randomize within each stratum and get best matches */

data sample;
set samp4;
run;

proc sql;
	create table work.min_cnt as
		select strata,
			min(cnt_0, cnt_1) as row_cnt
		from (select strata,
				sum(case
					when treatment_group = 0 then 1
					else 0
				end) as cnt_0,
				sum(case
					when treatment_group = 1 then 1
					else 0
				end) as cnt_1,
				sum(case
					when treatment_group = 2 then 1
					else 0
				end) as cnt_2
			  from work.sample
			  group by strata)
		group by strata
		having calculated row_cnt > 0;
quit;

data work.sample_rs;
set work.sample;
ran_num = uniform(-1);
run;

Proc sort data=work.sample_rs;
by strata ran_num;
run;

%macro test;

data _null_;
        set work.min_cnt end=last;
        call symput('strata'||left(_n_), trim(strata));
        call symput('rowcnt'||left(_n_), trim(row_cnt));
        if last then call symput('cntr', _n_);
run;

%do i=1 %to &cntr;

proc sql outobs = &&rowcnt&i;
	create table work.mbrs0(drop= ran_num) as
		select *
		from work.sample_rs
		where treatment_group = 0
			and strata = &&strata&i;
quit;

proc sql outobs = &&rowcnt&i;
	create table work.mbrs1(drop= ran_num) as
		select *
		from work.sample_rs
		where treatment_group = 1
			and strata = &&strata&i;
quit;

proc sql outobs = &&rowcnt&i;
	create table work.mbrs2(drop= ran_num) as
		select *
		from work.sample_rs
		where treatment_group = 2
			and strata = &&strata&i;
quit;

proc append base=work.study_grps data=work.mbrs0;
run;

proc append base=work.study_grps data=work.mbrs1;
run;

proc append base=work.study_grps data=work.mbrs2;
run;
DM "log; clear; ";

%end;

%mend;

%test;

proc freq data=study_grps;
tables treatment_group;
run;
