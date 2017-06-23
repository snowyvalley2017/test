/*---------------------------------------------------------------------------------------------*
| Macro Name :   pg_sql_grp.sas
|
| Created By :   Gu, Peihua 
*----------------------------------------------------------------------------------------------*
| Purpose:
|
| This macro is to summarize user specified variables by grouping certain fields;
*----------------------------------------------------------------------------------------------*
| Macro Call:
| %include "/your unix directory/pg_sql_grp.sas"; 
| %pg_sql_grp(dsn_in=sashelp.cars, dsn_out=cars_sum, ord=N, fmt=comma20., func=avg, 
|	    grp=make enginesize, var=invoice weight,nm=_avg);
*----------------------------------------------------------------------------------------------*
| Required Parameters:
|
| dsn_in: 	Input dataset
| dsn_out: 	Output dataset
| ord: 		Leave it as blank if users want to sort data by groups (Please set it as N 
|		if users don't want to sort data)
| fmt: 		Format for summarized variables
| func: 		One function which is used to summarize variables (ex: max / sum / mean)
| grp:		A list of grouping fields separated by space (ex: acct_num membr_num)
| var:		A list of variables which users want to summarize (ex: Rx_cost med_cost)
| nm: 		Suffix for summarized variable names (ex: _max);
|		leave it as blank if you want to keep the same name as original variables
*---------------------------------------------------------------------------------------------*/
%macro pg_sql_grp(dsn_in=, dsn_out=, ord=, fmt=, func=, grp=, var=,nm=);
	%let _grpcnt=%sysfunc(countw(&grp));
	%let _varcnt=%sysfunc(countw(&var));

	proc sql;
		create table &dsn_out. as
			select
			%do _i=1 %to &_grpcnt;
				%scan(&grp, &_i),
			%end;

			%do _j=1 %to &_varcnt;
				%if &_j>1 %then
					,;
				&func.(%scan(&var, &_j)) as %scan(&var, &_j)&nm format=&fmt
			%end;

			,count(*) as cnt

			from &dsn_in.
				group by
				%do _i=1 %to &_grpcnt;
					%if &_i>1 %then
						,;
					%scan(&grp, &_i)
				%end;

				%if &ord=N %then
				%do;
					%goto exit;
				%end;

				order by
				%do _i=1 %to &_grpcnt;
					%if &_i>1 %then
						,;
					%scan(&grp, &_i)
				%end;
		;
	quit;
%exit: %mend;
