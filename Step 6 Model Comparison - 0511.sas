*data prep;
*scored modeling dataset;
*1. SAS LR;
PROC LOGISTIC INMODEL=mymart.LR_model/*model2*/  descending ; 
SCORE DATA=mymart.inov_test_l OUT=test_scored OUTROC=test_roc; 
RUN;

*2.attach ML LR prob back to file;

proc sql;
create table combo as
select 
a.*,
z.f3 as ML_SCORE
from test_scored as a left join z  as z on a.item_id=z.f2;
quit;

data mymart.inov_proj_score;
set combo;
SAS_SCORE=P_1;
run;