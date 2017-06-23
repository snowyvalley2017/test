/************************************************************/
/* Match-Case Control: 1:3 matching   */
/************************************************************/

libname pac '/sasem/sasusr/c70189';
*The HR dataset is titled 'PAC_HR_DATA';

/*First separate into study and control*/
/*The study group are the PACs and CAPS*/


/*prep the data*/
data posture;
	set pac.pac_hr_data;
	where time_in_current_role_years_ ge 0.8 and role in ('K00099', 'K00146', 'K00501');
	if employee_id in ('345947','320003','340429','360314','321985','358495'
					'353676','322610','361921','361882','364424','364480','364524')
	then treatment_group = 1; else treatment_group = 0;
run;

/*split into study and control-candidate groups*/
data pac_study pac_control;
	set posture;
	if treatment_group=1 then output pac_study;
	if treatment_group=0 then output pac_control;
run;

/*rename the control variables*/
data pac_control;
	set pac_control;
	c_employee_id = employee_id;
	c_time_in_current_role_years_ = time_in_current_role_years_;
	c_time_in_current_band_years_ = time_in_current_band_years_;
	c_time_in_current_department_y = time_in_current_department_years;
	c_role = role;
	c_department_id = department_id;
	c_work_location = work_location;
	c_manager_hierarchy_5 = manager_hierarchy_5;
run;

%let number=0.5;
*	Note that for 1:1 match, the allowable variation was 0.3 instead of 0.5 and the employees were
	also matched on work.location;
/*perform simple match using study and control datasets*/
proc sql;
create table controls_id as
select a.employee_id, b.c_employee_id,
		a.time_in_current_role_years_, b.c_time_in_current_role_years_,
		a.time_in_current_band_years_, b.c_time_in_current_band_years_,
		a.time_in_current_department_years, b.c_time_in_current_department_y,
		a.role, b.c_role, a.department_id, b.c_department_id, a.work_location, b.c_work_location,
		a.manager_hierarchy_5, b.c_manager_hierarchy_5
from pac_study a, pac_control b
where 
	abs (a.time_in_current_role_years_ - b.c_time_in_current_role_years_) <= &number
	and abs (a.time_in_current_band_years_ - b.c_time_in_current_band_years_) <= &number
/*	and abs (a.time_in_current_department_years - b.c_time_in_current_department_y) <= &number*/
	and a.role = b.c_role
/*	and a.department_id = b.c_department_id*/
	and a.manager_hierarchy_5 = b.c_manager_hierarchy_5
/*	and a.work_location = b.c_work_location */
order by employee_id;
quit;

data controls_id;
	set controls_id;
	if work_location = c_work_location then work_loc_flg = 1; 
	else work_loc_flg = 0;
	time_dif_role = abs(time_in_current_role_years_ - c_time_in_current_role_years_);
	time_dif_band = abs(time_in_current_band_years_ - c_time_in_current_band_years_);
	time_dif_dept = abs(time_in_current_department_years - c_time_in_current_department_y);
	time_dif = sum(time_dif_role, time_dif_band, time_dif_dept);
run;


proc sort data=controls_id;
	by employee_id descending work_loc_flg time_dif;
run;

data controls_id2;
	set controls_id;
	by employee_id;
	retain num_controls;
	if first.employee_id then num_controls=1;
		else num_controls=num_controls + 1;
	if last.employee_id then output;
run;

proc sql;
create table controls_id3 as
select a.*, b.num_controls, ranuni(8675309) as rand_num
from controls_id a left join controls_id2 b
on a.employee_id = b.employee_id
/*order by employee_id*/
;
quit;

proc sort data=controls_id3;
	by employee_id descending work_loc_flg time_dif rand_num;
run;

data one_to_one;
	set controls_id3;
	by employee_id;
	if first.employee_id then output one_to_one;
run;

*This 1:3 match does not provide unique control members - some duplication so I don't want to use it;
data one_to_three;
	set controls_id3;
	by employee_id;
	retain count;
	if first.employee_id then count=1;
		else count=count + 1;
	if count < 4 then output;
run;

data pac.pac_one_to_one;
	set one_to_one;
run;

proc sql;
create table study as
select distinct employee_id
from pac.pac_one_to_one;
quit;

proc sql;
create table control as
select distinct c_employee_id as employee_id
from pac.pac_one_to_one;
quit;

data append;
	set study control;
run;

proc sql; 
create table summary as 
select count(distinct employee_id) as dist_emp, count(distinct c_employee_id) as dist_c_emp 
from pac.pac_one_to_one;
quit;

/*	This is a 1:3 selection done manually to remove duplicates. The selection is still random because
	the list was ordered according to random numbers			*/
data pac.pac_one_to_three;
	set controls_id3;
	if _n_ in (1,2,3,19,20,21,24,25,26,35,36,37,59,60,61,75,76,77,81,82,83
				,107,108,109,130,131,132,195,196,198,258,259,260,306,307,308
				,354,357,356);
run;

*Further revision needed to replace employee 358494 with 359899. 358494 had claims history which makes them ineligible
	for a call-only option. 359899 does not have claims history for time period;

data one_to_three_rev;
	set pac.pac_one_to_three;
	if c_employee_id = '358494' then delete;
run;

data sub;
	set controls_id3;
	where employee_id = '358495' and c_employee_id = '359899';
run;

data rev;
	set one_to_three_rev sub;
run;

proc sql;
create table one_to_three_rev as
select *
from rev
order by employee_id, work_loc_flg desc, time_dif, rand_num;
quit;

data pac.pac_one_to_three;
	set one_to_three_rev;
run;

proc sql;
create table study1 as
select distinct employee_id
from pac.pac_one_to_three;
quit;

proc sql;
create table control1 as
select distinct c_employee_id as employee_id
from pac.pac_one_to_three;
quit;

data append;
	set study1 control1;
run;


/*Difference testing*/
proc sql;
create table tests as
select * 
from posture
where employee_id in (select distinct employee_id from append)
order by employee_id
;
quit;

proc sort data=tests;
	by treatment_group;
run;

proc univariate data=tests normal;
by treatment_group;
var time_in_current_role_years_ 
	time_in_current_band_years_
	time_in_current_department_years;
qqplot /Normal(mu=est sigma=est color=red l=1);
/*histogram;*/
run;

/*No reasonable assupmtion of Normality*/
/*Use nonparametric tests*/

/* Tests of difference*/
proc NPAR1WAY data=tests wilcoxon;
	title "Nonparametric test to compare Study vs. Control groups";
	class treatment_group;
	var time_in_current_role_years_ 
	time_in_current_band_years_
	time_in_current_department_years
	;
	exact wilcoxon;
run;
title;

data tests;
	set tests;
	if employee_id in('321539','324084') then work_loc_flg = 0;
		else work_loc_flg = 1;
run;

title 'Frequency tests for work location vs. treatment group';
title 'Work_loc_flg = 1 indicates matched with same work locations';
proc freq data=tests;
tables work_loc_flg*treatment_group /chisq;
run;
/*Groups not statistically different from each other using 1:1 match*/
/*Groups not statistically different from each other using 1:3 match*/

*Check managers;
proc sql;
create table mgr as
select distinct employee_id, manager_hierarchy_5, c_manager_hierarchy_5
from controls_id3
;
quit;