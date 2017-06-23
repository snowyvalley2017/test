/*---------------------------------------------------------------------------------
| Macro Name:	pg_missperc
|
| Created By:	Gu, Peihua 
*----------------------------------------------------------------------------------
| Purpose:
| 
| This macro is to generate a report which lists number of missing observations,  
| percentage of missing and total counts for a list of user specified variables 
*----------------------------------------------------------------------------------
| Macro Call:
| %include "/your unix directory/pg_missperc.sas"; 
| %pg_missperc(dsn_in=test, frq_lst=_all_, plt=N);
*----------------------------------------------------------------------------------
| Required Parameters:
|
| dsn_in:		The name of your SAS input data set
| frq_lst:	List of user specified variables (set it as _all_ if you want
|		to list all variables)
| plt:		Leave it as blank if you want to generate a plot (Please set it
|		as N if there are too many variables)
*----------------------------------------------------------------------------------
| Output Dataset :	missperc
*---------------------------------------------------------------------------------*/

%macro pg_missperc(dsn_in=, frq_lst=, plt=);
	proc format;
		value $ catfmt	' '='Missing'
			other='Non-Missing'
		;
		value 	numfmt . ='Missing'
			other='Non-Missing'
		;
	run;

	ods output onewayfreqs=missperc(keep=table frequency);
	proc freq data=&dsn_in;
		table &frq_lst;
		format _numeric_ numfmt. _character_ $catfmt.;
	run;

	proc sql noprint;
		select count(*) into :nobs from &dsn_in;
	quit;

	data missperc(drop=table n_nonmiss);
		set missperc (rename=(frequency=n_nonmiss));
		Variable=scan(table,2,' ');
		if n_nonmiss<0 then n_nonmiss=0;
		n_miss=&nobs-n_nonmiss;
		ttlcnt=&nobs;
		miss_perc=n_miss/&nobs;
		format miss_perc percent8.2;
	run;
	proc sort data=missperc;
		by miss_perc;
	run;

	%if &plt=N %then %do;
		%goto exit;
	%end;
	
	proc sgplot data=missperc;
		vbar Variable / response=miss_perc datalabel fillattrs=(color=green);
		xaxis discreteorder=data;
		xaxis label='Variable';
		yaxis label='Missing Percentage' values=(0 to 1.0 by 0.2) tickvalueformat=percent8.;
		format miss_perc percent8.2;
		run;
	quit;	
%exit: %mend;
%pg_missperc(dsn_in=inov_output_n, frq_lst=_ALL_, plt=N);


%pg_missperc(dsn_in=mymart.manual_output_l, frq_lst=_ALL_, plt=N);


%pg_missperc(dsn_in=mymart.eliza_output_l, frq_lst=_ALL_, plt=N);


%pg_missperc(dsn_in=select_var, frq_lst=_ALL_, plt=N);
