/*----------------------------------------------------------------------------------------------------------------------------------------*
| Macro Name :   	pg_pearson_corr.sas
|
| Created By :   	Gu, Peihua 
*-----------------------------------------------------------------------------------------------------------------------------------------*
| Purpose:
|
| This macro is to generate a correlation table for a list of covariates and response;
*-----------------------------------------------------------------------------------------------------------------------------------------*
| Macro Call:
| %include "/.../pg_pearson_corr.sas";
| %pg_pearson_corr(dsn_in=sashelp.cars, dsn_out=cars_corr, response=invoice, 
|	                 var_lst=enginesize weight msrp);
*-----------------------------------------------------------------------------------------------------------------------------------------*
| Required Parameters:
|
| dsn_in: 		Input dataset
| dsn_out: 		Output dataset
| response: 	Response variable name
| var_lst: 		A list of variables which users want to test their correlation with response
*----------------------------------------------------------------------------------------------------------------------------------------*/

%macro pg_pearson_corr (dsn_in=, dsn_out=, response=, var_lst=);

	ods output PearsonCorr = corr;

	proc corr data = &dsn_in pearson;
		var &var_lst;
		with &response;
	run;

	data &dsn_out (keep= Resp Pred Corr Abs_Corr);
		set corr;
		array _var(*) &var_lst;
		do i = 1 to dim(_var);
			Resp = variable;
			Pred = vname(_var(i));
			Corr= _var(i);
			Abs_Corr= abs(_var(i));
			output;
		end;
	run;

	proc sort data=&dsn_out;
		by descending Abs_Corr;
	run;

%mend;
%pg_pearson_corr (dsn_in=mymart.inov_proj_output, dsn_out=corr, response=PCT_BELOW_PVRTY_HSHLD

, var_lst=PCT_HSHLD_URBAN AVG_VEHCL_AVAIL_HSHLD PCT_LESS_HIGH_SCHL_EDUCTN
PCT_HIGH_SCHL_EDUCTN
PCT_SOME_COLLEGE
PCT_COLLEGE_GRADT
UNEMP_RT
PCT_WHITE
PCT_BLACK
PCT_AMER_INDIAN
PCT_ASIAN_PACIFIC
PCT_OTH_RACE
PCT_HISPANIC
avg_vehcl_hshld
oohu_mdn_norm
hh_incm_norm
sae_1327_norm
);