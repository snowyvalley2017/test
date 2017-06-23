%macro rocplot ( version, inroc=, inpred=, p=, id=, idstat=, 
                 outrocdata=_rocplot, 
                 
                 mindist=, round=1e-12, thinsens=0.05, thinvar=, thiny=0.5,
                 labelstyle=, format=best5., charlen=5, split=%str( ), 

                 optcrit=, costratio=, pevent=, 
                 optbyx=no, x=, multoptplot=no, multoptlist=no, 

                 grid=yes, altaxislabel=no, offsetmin=0.1, offsetmax=0.1, 
                 linestyle=, optsymbolstyle=, markerstyle=, markers=yes,
                 marker=circlefilled,                  
                 
                 out=, outroc=, plotchar=, roffset=, font=, size=, color=,
                 plottype=high, markersymbol=, linecolor=, linepattern=, linethickness=
               );

%let time = %sysfunc(datetime());

%let _version=1.3;
%if &version ne %then %put ROCPLOT macro Version &_version;

%let opts = %sysfunc(getoption(notes));
%if &version ne debug %then %str(options nonotes;);

/* -------------- Check for newer version -------------- */
 %if %sysevalf(&sysver >= 8.2) %then %do;
  %let _notfound=0;
  filename _ver url 'http://ftp.sas.com/techsup/download/stat/versions.dat' termstr=crlf;
  data _null_;
    infile _ver end=_eof;
    input name:$15. ver;
    if upcase(name)="&sysmacroname" then do;
       call symput("_newver",ver); stop;
    end;
    if _eof then call symput("_notfound",1);
    run;
  %if &syserr ne 0 or &_notfound=1 %then
    %put &sysmacroname: Unable to check for newer version;
  %else %if %sysevalf(&_newver > &_version) %then %do;
    %put &sysmacroname: A newer version of the &sysmacroname macro is available.;
    %put %str(         ) You can get the newer version at this location:;
    %put %str(         ) http://support.sas.com/ctx/samples/index.jsp;
  %end;
 %end;

/* -------------------- Check inputs -------------------- */

/* Convert pre-v1.2 syntax as possible */
%if %quote(&out) ne and %quote(&inpred)= %then %let inpred=&out;
%if %quote(&outroc) ne and %quote(&inroc)= %then %let inroc=&outroc;
%if %quote(&plotchar) ne and %quote(&marker)= %then %let marker=&plotchar;
%if %quote(&roffset) ne and (&offsetmin= and &offsetmax=) %then %do;
  %let offsetmin=&roffset; %let offsetmax=&roffset;
%end;
%if %quote(&font) ne and %index(&labelstyle,family)=0 %then 
  %let labelstyle=&labelstyle family=&font;
%if %quote(&size) ne and %index(&labelstyle,size)=0 %then 
  %let labelstyle=&labelstyle size=&size;
%if %quote(&color) ne and %index(&labelstyle,color)=0 %then 
  %let labelstyle=&labelstyle color=&color;
  
/* Convert v1.2 syntax as possible */
%if %quote(&markersymbol) ne and %quote(&marker)= %then %let marker=&markersymbol;
%if %quote(&linestyle)= %then %do;
  %let ls=;
  %if %quote(&linecolor) ne %then %let ls=&ls color=&linecolor;
  %if %quote(&linepattern) ne %then %let ls=&ls pattern=&linepattern;
  %if %quote(&linethickness) ne %then %let ls=&ls thickness=&linethickness;
  %let linestyle=&ls;
%end;

/* Set to default if specified without value */
%if &marker= %then %let marker=circlefilled;
%if &multoptplot= %then %let multoptplot=no;
%if &multoptlist= %then %let multoptlist=no;
%if &grid= %then %let grid=yes;
%if &altaxislabel= %then %let altaxislabel=no;
%if &optbyx= %then %let optbyx=no;

/* Verify ID= is specified */
%if %quote(&id)= %then %do;
  %put ERROR: At least one ID= variable is required.;
  %goto exit;
%end;

/* Verify P= is specified */
%if %quote(&p)= %then %do;
  %put ERROR: The P= option is required.;
  %goto exit;
%end;

/* Verify INROC= is specified and the data set exists */
%if %quote(&inroc) ne %then %do;
  %if %sysfunc(exist(&inroc)) ne 1 %then %do;
    %put ERROR: INROC= data set &inroc not found.;
    %goto exit;
  %end;
%end;
%else %do;
  %put ERROR: The INROC= option is required.;
  %goto exit;
%end;

/* Verify INPRED= is specified and the data set exists */
%if %quote(&inpred) ne %then %do;
  %if %sysfunc(exist(&inpred)) ne 1 %then %do;
    %put ERROR: INPRED= data set &inpred not found.;
    %goto exit;
  %end;
%end;
%else %do;
  %put ERROR: The INPRED= option is required.;
  %goto exit;
%end;

/* Verify THINSENS= is valid */
%if %sysevalf(&thinsens<0) or %sysevalf(&thinsens>1) %then %do;
  %put ERROR: The THINSENS= value must be between 0 and 1.;
  %goto exit;
%end;

/* Verify THINY= is valid */
%if %sysevalf(&thiny<-1) or %sysevalf(&thiny>1) %then %do;
  %put ERROR: The THINY= value must be between -1 and 1.;
  %goto exit;
%end;

/* Verify THINVAR= specified if MINDIST= is specified */
%if %sysevalf(&mindist ne and &thinvar=) %then %do;
  %put ERROR: THINVAR= must be specified when MINDIST= is specified;
  %goto exit;
%end;

/* Verify MINDIST= specified if THINVAR= is specified */
%if %sysevalf(&mindist= and &thinvar ne) %then %do;
  %put ERROR: MINDIST= must be specified when THINVAR= is specified;
  %goto exit;
%end;

/* Verify MINDIST= is valid */
%if %sysevalf(&mindist ne and &mindist<0) %then %do;
  %put ERROR: The MINDIST= value must be zero or greater.;
  %goto exit;
%end;

/* Verify OPTCRIT= values are valid */
%let i=1; %let nmultcrit=0;
%if %index(%upcase(&optcrit),ALL) ne 0 %then %do;
    %let optcrit=CORRECT DIST SESPDIFF COST EFF MCT YOUDEN;
    %let ncrit=7; %let nmultcrit=3;
%end;
%else %do %while (%scan(&optcrit,&i) ne %str() );
  %let opttoken=%scan(%upcase(&optcrit),&i);
  %if &opttoken ne CORRECT and &opttoken ne DIST and
      &opttoken ne YOUDEN and &opttoken ne COST and 
      &opttoken ne SESPDIFF and &opttoken ne EFF and 
      &opttoken ne MCT and &opttoken ne ALL
  %then %do;
    %put ERROR: Valid OPTCRIT= values are CORRECT, DIST, YOUDEN, SESPDIFF, EFF, MCT, COST, and ALL.;
    %goto exit;
  %end;
  %if &opttoken=COST or &opttoken=MCT or &opttoken=EFF 
    %then %let nmultcrit=%eval(&nmultcrit+1);
  %let i=%eval(&i+1);
  %let ncrit=%eval(&i-1);
%end;

/* Verify OPTBYX= is valid */
%if %upcase(&optbyx) ne YES and %upcase(&optbyx) ne PANELALL and 
    %upcase(&optbyx) ne PANELEACH and %upcase(&optbyx) ne NO
%then %do;
  %put ERROR: Valid OPTBYX= values are YES, PANELALL, PANELEACH, or NO.;
  %goto exit;
%end;

/* Verify X= is specified if OPTBYX=YES or PANELALL or PANELEACH */
%if (%upcase(&optbyx)=YES or %upcase(&optbyx)=PANELALL or 
    %upcase(&optbyx)=PANELALL) and &x= %then %do;
  %put ERROR: X= option required when OPTBYX=YES|PANELALL|PANELEACH.;
  %goto exit;
%end;
%if %scan(&x,2) ne %then %do;
  %put ERROR: Specify only one variable name in the X= option.;
  %goto exit;
%end;

/* Verify MULTOPTPLOT= is valid */
%if %upcase(&multoptplot) ne YES and %upcase(&multoptplot) ne PANELALL and 
    %upcase(&multoptplot) ne NO
%then %do;
  %put ERROR: Valid MULTOPTPLOT= values are YES, PANELALL, or NO.;
  %goto exit;
%end;

/* Verify MULTOPTLIST= is valid */
%if %upcase(&multoptlist) ne YES and %upcase(&multoptlist) ne NO
%then %do;
  %put ERROR: Valid MULTOPTLIST= values are YES or NO.;
  %goto exit;
%end;

/* Expand _OPTALL_ */
%if %index(%upcase(&id),_OPTALL_) ne 0 %then %do;
  %let updtid=; %let i=1;
  %do %while (%scan(&id,&i,%str( )) ne %str() );
    %let var=%scan(&id,&i); %let lvar=%length(&var);
    %if &lvar < 4 %then %let updtid=&updtid &var;
    %else %if %upcase(%substr(&var,1,4)) ne _OPT %then %let updtid=&updtid &var;
    %let i=%eval(&i+1);
  %end;
  %let id=&updtid _OPTCORR_ _OPTDIST_ _OPTY_ _OPTSESP_ _OPTCOST_ _OPTMCT_ _OPTEFF_;
%end;

/* Create DOCOST indicator for when cost criterion is requested */
%let docost=0;
%if %index(%upcase(&optcrit),COST) ne 0 or 
    %index(%upcase(&id),_OPTCOST_) ne 0
%then %let docost=1;

/* Create DOMCT indicator for when MCT criterion is requested */
%let domct=0;
%if %index(%upcase(&optcrit),MCT) ne 0 or 
    %index(%upcase(&id),_OPTMCT_) ne 0
%then %let domct=1;

/* Verify COSTRATIO= specified if cost or mct criterion requested */
%if (&docost=1 or &domct=1) and %sysevalf(&costratio=)
%then %do;
  %put ERROR: COSTRATIO= is required when the cost or MCT criterion or variable is requested.;
  %goto exit;
%end;

/* Verify PEVENT= is valid */
%let i=1;
%do %while (%sysevalf(%scan(&pevent,&i,%str( )) ne %str()) );
  %let prev=%scan(&pevent,&i,%str( ));
  %if %sysevalf(&prev ne and (&prev<0 or &prev>1)) %then %do;
    %put ERROR: All PEVENT= values must be between 0 and 1.;
    %goto exit;
  %end;
  %let i=%eval(&i+1);
%end;

/* Verify CHARLEN= is valid */
%if &charlen ne and (%sysevalf(&charlen<1) or %index(&charlen,%str(.)) ne 0) %then %do;
  %put ERROR: The CHARLEN= value must an integer greater than 0.;
  %goto exit;
%end;

/* Verify P=,ID=, THINVAR=, X= variables exist. Create IDCHAR and IDNUM macro 
   variables for char. and num. ID variables 
*/
%let idchar=; %let idcstat=; 
%let idnum=; %let idnstat=;
%let idnc=;
%let dsid=%sysfunc(open(&inpred));
%if &dsid %then %do;
  %if %sysfunc(varnum(&dsid,%upcase(&p)))=0 %then %do;
    %put ERROR: P= variable &p not found.;
    %goto exit;
  %end;
  %if %quote(&thinvar) ne %then %do;
    %let tvnum=%sysfunc(varnum(&dsid,%upcase(&thinvar)));
    %if &tvnum=0 %then %do;
      %put ERROR: THINVAR= variable &thinvar not found.;
      %goto exit;
    %end;
    %else %if %sysfunc(vartype(&dsid,&tvnum))=C %then %do;
      %put ERROR: THINVAR= variable must be numeric.;
      %goto exit;
    %end;
  %end;
  %if %quote(&x) ne %then %do;
  %if %sysfunc(varnum(&dsid,%upcase(&x)))=0 %then %do;
    %put ERROR: X= variable &x not found in the INPRED= data set.;
    %goto exit;
  %end;
  %end;  
  %let i=1;
  %do %while (%scan(&id,&i) ne %str() );
    %let var=%scan(&id,&i);
    %let stat=%scan(&idstat,&i,%str( ));
    %let idnc=&idnc C;
    %if &idstat ne and &stat= %then %do;
        %put ERROR: You must specify a statistic for each ID variable.;
        %goto exit;
    %end;
    %if %substr(&var,1,1) ne _ or %substr(&var,%length(&var),1) ne _
    %then %do;
       %let vnum=%sysfunc(varnum(&dsid,&var));
       %if &vnum=0 %then %do;
          %put ERROR: Variable &var not found.;
          %goto exit;
       %end;
       %if %sysfunc(vartype(&dsid,&vnum))=C %then %do;
           %let idchar=&idchar &var;
           %let idcstat=&idcstat &stat;
       %end;
       %else %do;
           %let idnum=&idnum &var;
           %let idnstat=&idnstat &stat;
           %if &i=1 %then %let idnc=N;
           %else %let idnc=%substr(&idnc,1,%length(&idnc)-1)N;
       %end;
    %end;
    %let i=%eval(&i+1);
  %end;
  %let rc=%sysfunc(close(&dsid));
%end;

/* Construct char variable list for PROC SORT BY statement */
%let sortby=; %let i=1;
%do %while (%scan(&idchar,&i) ne %str() );
   %let stat=%scan(&idcstat,&i);
   %if &stat= %then %let sortby=&sortby %scan(&idchar,&i);
   %else %if %upcase(%substr(&stat,1,1))=F %then 
     %let sortby=&sortby %scan(&idchar,&i);
   %else %if %upcase(%substr(&stat,1,1))=L %then 
     %let sortby=&sortby descending %scan(&idchar,&i);
   %else %do;
     %put ERROR: IDSTAT= option value for &idchar must be FIRST or LAST.;
     %goto exit;
   %end;
   %let i=%eval(&i+1);
%end;

/* Construct num variable statistic list for PROC SUMMARY OUTPUT statement */
%let labstats=; %let i=1;
%do %while (%scan(&idnum,&i) ne %str() );
   %let stat=%scan(&idnstat,&i);
   %if &stat= %then %let labstats=&labstats median(%scan(&idnum,&i))=;
   %else %let labstats=&labstats &stat(%scan(&idnum,&i))=;
   %let i=%eval(&i+1);
%end;


/* --------------------- Create plot data ------------------------ */

data _inpred;
   set &inpred;
   _OBS_=_n_;
   _prob_=round(&p,&round);
   run;
proc sort data=_inpred;
   by _prob_ &sortby;
   run;

%if &idnum ne %then %do;   
  proc summary data=_inpred;
     by _prob_;
     var &idnum;
     output out=_labstats (drop=_TYPE_)
     &labstats
     ;
     run;
     %if &syserr ne 0 %then %do;
        %put ERROR: Specify a valid statistic:;
        %goto exit;
     %end;
  data _labstats;
     set _labstats;
     _prob_=round(_prob_,&round);
     run;
%end;

data _inroc;
   set &inroc;
   _prob_=round(_prob_,&round);
   _PEVENT_=(_pos_+_falneg_)/(_POS_+_NEG_+_FALPOS_+_FALNEG_);
   %if &pevent= %then call symput("pevent",_pevent_);;
   run;
proc sort data=_inroc;
   by _prob_;
   run;

/* Merge the original and ROC data by the predicted probabilities 
   Create optimality and formatted statistic variables 
*/
data &outrocdata;
   merge _inroc(in=_inroc) 
         _inpred 
         %if &idnum ne %then _labstats;
         ;
   by _prob_;
   if _inroc and first._prob_;
   _SENS_=put(_sensit_,&format);
   __SPEC_=1-_1mspec_;
   _SPEC_=put(__SPEC_,&format);
   _CSPEC_=put(_1mspec_,&format);
   if _falpos_+_pos_=0 then __FPOS_=0;
      else __FPOS_=_falpos_/(_falpos_+_pos_);
   _FPOS_=put(__FPOS_,&format);
   if _falneg_+_neg_=0 then __FNEG_=0;
      else __FNEG_=_falneg_/(_falneg_+_neg_);
   _FNEG_=put(__FNEG_,&format);
   _PPRED_=put(1-__FPOS_,&format);
   _NPRED_=put(1-__FNEG_,&format);
   _CUTPT_=put(_prob_,&format);
   __CORRECT_=(_POS_+_NEG_)/(_POS_+_NEG_+_FALPOS_+_FALNEG_);
   _CORRECT_=put(__CORRECT_,&format);
   __MISCLASS_=1-__CORRECT_;
   _MISCLASS_=put(__MISCLASS_,&format);
   __DIST01_=sqrt((1-_SENSIT_)**2 + _1MSPEC_**2);
   _DIST01_=put(__DIST01_,&format);
   __YOUDEN_=_SENSIT_+__SPEC_-1;
   _YOUDEN_=put(__YOUDEN_,&format);
   __SESPDIFF_=abs(_SENSIT_-__SPEC_);
   _SESPDIFF_=put(__SESPDIFF_,&format);
   
   /* Create efficiency variables for each pevent */
   %let j=1; %let effp=; %let maxeffp=;
   %do %while ( %sysevalf(%scan(&pevent,&j,%str( )) ne) );
       _effp&j=%sysevalf(%scan(&pevent,&j,%str( )))*_SENSIT_ + 
              (1-%sysevalf(%scan(&pevent,&j,%str( ))))*__SPEC_; 
       %let effp=&effp _effp&j;
       %let maxeffp=&maxeffp _effp&j._max;
       %let j=%eval(&j+1);
   %end;
  
   /* Create cost variables for costratio-pevent combinations */
   %if &docost %then %do;
     %let i=1; %let j=1; %let crp=; %let maxcrp=;
     %do %while ( %sysevalf(%scan(&costratio,&i,%str( )) ne) ); 
        %do %while ( %sysevalf(%scan(&pevent,&j,%str( )) ne) );
          _cr&i.p&j=_SENSIT_-_1MSPEC_*
                    ((1-%sysevalf(%scan(&pevent,&j,%str( ))))
                    /%sysevalf(%scan(&pevent,&j,%str( ))))*
                    %sysevalf(%scan(&costratio,&i,%str( )));
          %let crp=&crp _cr&i.p&j;
          %let maxcrp=&maxcrp _cr&i.p&j._max;
          %let j=%eval(&j+1);
        %end;
        %let j=1;
        %let i=%eval(&i+1);
     %end;
     label _cr1p1="Value";
   %end;

   /* Create mct variables for costratio-pevent combinations */
   %if &domct %then %do;
     %let i=1; %let j=1; %let mcrp=; %let minmcrp=;
     %do %while ( %sysevalf(%scan(&costratio,&i,%str( )) ne) ); 
        %do %while ( %sysevalf(%scan(&pevent,&j,%str( )) ne) );
          _mcr&i.p&j=(1/%sysevalf(%scan(&costratio,&i,%str( ))))*
                     %sysevalf(%scan(&pevent,&j,%str( )))*(1-_SENSIT_) +
                     (1-%sysevalf(%scan(&pevent,&j,%str( ))))*_1MSPEC_
                    ;
          %let mcrp=&mcrp _mcr&i.p&j;
          %let minmcrp=&minmcrp _mcr&i.p&j._min;
          %let j=%eval(&j+1);
        %end;
        %let j=1;
        %let i=%eval(&i+1);
     %end;
     label _mcr1p1="Value";
   %end;

   drop __FNEG_ __FPOS_;
   run;
   
proc summary data=&outrocdata;
  output out=_optvals 
         max(__CORRECT_ __YOUDEN_)=_maxcorr _maxy
         min(__DIST01_ __SESPDIFF_)=_mindist _minsespdiff
         max(_eff:)=
     %if &docost %then max(_cr:)= ;
     %if &domct %then min(_mcr:)= ;
     / autoname;
  ;
  run;

data &outrocdata (drop= _type_ _freq_ _prv _value
   %if &version ne debug %then %do;
      _maxcorr _mindist _minsespdiff &maxeffp  _prev: _j
      %if &docost or &domct %then _cr _i; 
      %if &docost %then  _cost: &maxcrp;
      %if &domct %then &minmcrp;
   %end;
     )
   %if &docost %then %do;
     _mincosts
     %if &version ne debug %then %do;
       (keep=_prob_ _cr _prv _value _id)
     %end;
   %end;
   %if &domct %then %do;
     _minmct
     %if &version ne debug %then %do;
       (keep=_prob_ _cr _prv _value _id)
     %end;
   %end;
     _maxeff
     %if &version ne debug %then %do;
       (keep=_prob_ _prv _value _id)
     %end;
;
  set &outrocdata;
  if _n_=1 then do;
    set _optvals;
    %let i=1;
    %do %while ( %sysevalf(%scan(&pevent,&i,%str( )) ne) );
      _prev&i=%sysevalf(%scan(&pevent,&i,%str( )));
      %let i=%eval(&i+1);
    %end;
    %let np=%eval(&i-1);
    %let ncr=0;
    retain _prev:;
    %if &docost or &domct %then %do;
      %let i=1;
      %do %while ( %sysevalf(%scan(&costratio,&i,%str( )) ne) ); 
        _cost&i=%sysevalf(%scan(&costratio,&i,%str( )));
        %let i=%eval(&i+1);
      %end;
      %let ncr=%eval(&i-1);
      retain _cost:;
    %end;
  end;
  _OPTCORR_=substr(" C",(abs(__CORRECT_-_maxcorr)<&round)+1,1);
  _OPTDIST_=substr(" D",(abs(__DIST01_-_mindist)<&round)+1,1);
  _OPTY_=substr(" Y",(abs(__YOUDEN_-_maxy)<&round)+1,1);
  _OPTSESP_=substr(" =",(abs(__SESPDIFF_-_minsespdiff)<&round)+1,1);
  array _effa (&np) &effp;
  array _meffa (&np) &maxeffp;
  _maxeff=
    %if &np > 1 %then max(of &maxeffp);
    %else &maxeffp;
  ;
  do _j=1 to &np;
    if abs(_effa(_j)-_maxeff) < &round then _OPTEFF_="E";
  end; 
  array _pa (&np) _prev:;
 %if &docost or &domct %then array _ca (&ncr) _cost:;;
 %if &docost %then %do;
   array _costa (&ncr,&np) &crp;
   array _minca (&ncr,&np) &maxcrp;
   _mincost=
     %if &np >1 or &ncr > 1 %then max(of &maxcrp);
     %else &maxcrp;
   ;
   _OPTCOST_=" ";
   do _i=1 to &ncr;
     do _j=1 to &np;
       if abs(_costa(_i,_j)-_mincost) < &round then _OPTCOST_="$";
     end; 
   end; 
 %end; 
 %if &domct %then %do;
   array _mcta (&ncr,&np) &mcrp;
   array _minmcta (&ncr,&np) &minmcrp;
   _minmct=
     %if &np >1 or &ncr > 1 %then min(of &minmcrp);
     %else &minmcrp;
   ;
   _OPTMCT_=" ";
   do _i=1 to &ncr;
     do _j=1 to &np;
       if abs(_mcta(_i,_j)-_minmct) < &round then _OPTMCT_="M";
     end; 
   end; 
 %end; 
  _opt=0;
  %if %index(%upcase(&id),_OPTCORR_) ne 0 %then
    if _optcorr_="C" then _opt=1;;
  %if %index(%upcase(&id),_OPTDIST_) ne 0 %then
    if _optdist_="D" then _opt=1;;
  %if %index(%upcase(&id),_OPTY_) ne 0 %then
    if _opty_="Y" then _opt=1;;
  %if %index(%upcase(&id),_OPTSESP_) ne 0 %then
    if _optsesp_="=" then _opt=1;;
  %if %index(%upcase(&id),_OPTEFF_) ne 0 %then
    if _opteff_="E" then _opt=1;;
  %if %index(%upcase(&id),_OPTCOST_) ne 0 %then
    if _optcost_="$" then _opt=1;;
  %if %index(%upcase(&id),_OPTMCT_) ne 0 %then
    if _optmct_="M" then _opt=1;;
  /* Create single label variable */
  length _id $ 200;
  _id=
       %let i=1;
       %do %while (%scan(&id,&i) ne %str() );
         %if &i ne 1 %then ||"&split"||;
         %if %scan(&idnc,&i)=C %then cats(put(%scan(&id,&i),$&charlen..));
         %else cats(put(%scan(&id,&i),&format));
         %let i=%eval(&i+1);
       %end;
  ;
  output &outrocdata;
 %if &docost %then %do;
  do _i=1 to &ncr;
    do _j=1 to &np;
      if abs(_costa(_i,_j)-_minca(_i,_j))<&round then do;
        _cr=_ca(_i); _prv=_pa(_j); _value=_minca(_i,_j); 
        output _mincosts;
      end;
    end; 
  end; 
  label _cr="Cost Ratio";
 %end; 
 %if &domct %then %do;
  do _i=1 to &ncr;
    do _j=1 to &np;
      if abs(_mcta(_i,_j)-_minmcta(_i,_j))<&round then do;
        _cr=_ca(_i); _prv=_pa(_j); _value=_minmcta(_i,_j); 
        output _minmct;
      end;
    end; 
  end; 
  label _cr="Cost Ratio";
 %end; 
  do _j=1 to &np;
    if abs(_effa(_j)-_meffa(_j)) < &round then do;
      _prv=_pa(_j); _value=_meffa(_j); 
      output _maxeff;
    end;
  end; 
  label _prv="Prevalance" _prob_="Cutpoint" _id="Label" _value="Value";
  run;

%if &optcrit ne or %index(%upcase(&id),_OPT) ne 0 %then %do;
data _optcrit;
  set &outrocdata;
  length Criterion $ 11;
  %if %index(%upcase(&optcrit),CORRECT) ne 0 or 
  %index(%upcase(&id),_OPTCORR_) ne 0 %then %do;
    if _optcorr_="C" then do; 
      Criterion="Correct"; Symbol="C"; _value=__correct_; output; 
    end;
  %end;
  %if %index(%upcase(&optcrit),DIST) ne 0 or 
  %index(%upcase(&id),_OPTDIST_) ne 0 %then %do;
    if _optdist_="D" then do; 
      Criterion="Dist To 0,1"; Symbol="D"; _value=__dist01_; output; 
    end;
  %end;
  %if %index(%upcase(&optcrit),YOUDEN) ne 0 or 
  %index(%upcase(&id),_OPTY_) ne 0 %then %do;
    if _opty_="Y" then do; 
      Criterion="Youden"; Symbol="Y"; _value=__youden_; output; 
    end;
  %end;
  %if %index(%upcase(&optcrit),SESPDIFF) ne 0 or 
  %index(%upcase(&id),_OPTSESP_) ne 0 %then %do;
    if _optsesp_="=" then do; 
      Criterion="Sens-Spec"; Symbol="="; _value=__SESPDIFF_; output; 
    end;
  %end;
  %if %index(%upcase(&optcrit),EFF) ne 0 or 
  %index(%upcase(&id),_OPTEFF_) ne 0 %then %do;
    if _opteff_="E" then do; 
      Criterion="Efficiency"; Symbol="E"; _value=_maxeff; output; 
    end;
  %end;
  %if &docost %then %do;
    if _optcost_="$" then do; 
      Criterion="Cost"; Symbol="$"; _value=_mincost; output; 
    end;
  %end;
  %if &domct %then %do;
    if _optmct_="M" then do; 
      Criterion="MCT"; Symbol="M"; _value=_minmct; output; 
    end;
  %end;
  keep _prob_ _id Criterion Symbol _value;
  label _id="Label" _prob_="Cutpoint" _value="Value";
  run;
%end;

/* -------------------- Point Labeling --------------------- */

/* Label points only if Youden statistic is big enough, sensitivities 
   differ enough. Or if optimality indicator requested in label.
*/
proc sort data=&outrocdata out=_rpdesc; 
   by descending _prob_; 
   run;
data _rpdesc;
   set _rpdesc;
   retain _se _sp;
   if _1mspec_=_sp then _slpup=.; 
   else _slpup=(_sensit_-_se)/(_1mspec_-_sp);
   _se=_sensit_; _sp=_1mspec_;
   drop _se _sp;
   run;
proc sort data=_rpdesc out=&outrocdata; 
   by _prob_; 
   run;
data &outrocdata;
   set &outrocdata end=eof;
   retain _prevsens 1;
   by _sensit_ notsorted;
   _labelgrp=0;
   drop _prevsens _labcnt
     %if &version ne debug %then %do;
        _maxeff _slpup _slpdn
        %if &docost %then _mincost;
        %if &domct %then _minmct;
     %end;
   ;
   _slpdn=lag(_slpup);
   if _opt=1 or
      %if &thinsens ne 1 %then (last._sensit_ and _sensit_=1) or;
      (_slpup ne _slpdn and _slpdn ne . and _slpup ne 0 and
      _prevsens - _sensit_ >= &thinsens and
      __youden_/_maxy > &thiny)
   then do;
     _thinid=_id; _labcnt+1; _prevsens=_sensit_; _labelgrp=1;
   end;
   if eof then put "&sysmacroname: " _labcnt "points labeled by THINY=&thiny and THINSENS=&thinsens..";
   run;

/* Add (0.0) data point */
data _add00;
   _prob_=1; _sensit_=0; _1mspec_=0; _labelgrp=0;
   run;
data &outrocdata;
   set &outrocdata _add00;
   run;

/* Label additional points MINDIST or more apart on THINVAR variable */
%if &thinvar ne %then %do;
   proc sort data=&outrocdata;
      by &thinvar;
      run;

   data &outrocdata;
      set &outrocdata end=eof;
      retain _prev;
      drop _prev _labcnt;
      if _n_=2 then _prev=&thinvar;
      if _n_>1 then do;
         if abs(_prev - &thinvar) >= &mindist then do;
            if _thinid="" then do;
               _prev=&thinvar;
               if _labelgrp=0 then do;
                  _thinid=_id; _labcnt+1; _labelgrp=1;
               end;
            end;
         end;
      end;
      if eof then put "&sysmacroname: " _labcnt "points labeled by THINVAR=&thinvar, MINDIST=&mindist..";
      run;

   proc sort data=&outrocdata;
      by _prob_;
      run; 
%end;

/* ----------------- Produce the ROC plot ----------------- */

%if %upcase(%substr(&plottype,1,1))=L %then %do;
   /* Plot once without labels so ROC curve is visible */
   proc plot data=&outrocdata;
      plot _sensit_*_1mspec_ /
           haxis=0 to 1 by .1 vaxis=0 to 1 by .1;
    %if %upcase(%substr(&altaxislabel,1,1))=Y %then
      label _1mspec_="False Positive Rate" _sensit_="True Positive Rate";;
      run; quit;

   /* Plot ROC curve again with labeled points */
   footnote "Points labeled by: &id";
   proc plot data=&outrocdata;
      plot _sensit_*_1mspec_ $ _thinid /
           haxis=0 to 1 by .1 vaxis=0 to 1 by .1;
    %if %upcase(%substr(&altaxislabel,1,1))=Y %then
      label _1mspec_="False Positive Rate" _sensit_="True Positive Rate";;
      run; quit;
%end;

%if %upcase(%substr(&plottype,1,1))=H %then %do;
   %if %sysevalf(&sysver < 9.4) %then %do;
      ods graphics / height=480px width=480px; 
   %end;
   
   proc sgplot data=&outrocdata noautolegend 
     %if %sysevalf(&sysver >= 9.4) %then aspect=1;
     ;
    xaxis values=(0 to 1 by 0.25) 
      %if %upcase(%substr(&grid,1,1))=Y %then grid;
      offsetmin=&offsetmin offsetmax=&offsetmax; 
    yaxis values=(0 to 1 by 0.25) 
      %if %upcase(%substr(&grid,1,1))=Y %then grid;
      offsetmin=.05 offsetmax=.05;
    lineparm x=0 y=0 slope=1 / transparency=.7;
    series x=_1mspec_ y=_sensit_ / datalabel=_thinid 
           %if &linestyle ne %then lineattrs=(&linestyle);
           %if &labelstyle ne %then datalabelattrs=(&labelstyle);
    ;
    %if %upcase(%substr(&markers,1,1))=Y %then %do;
    scatter x=_1mspec_ y=_sensit_ / freq=_labelgrp
           markerattrs=(symbol=&marker)
           %if &markerstyle ne %then markerattrs=(&markerstyle);
    ;
    %end;
    %if %index(%upcase(&optcrit),CORRECT) ne 0 %then %do;
    scatter x=_1mspec_ y=_sensit_ / markerchar=_OPTCORR_ 
      %if &optsymbolstyle ne %then markercharattrs=(&optsymbolstyle);;
    %end;
    %if %index(%upcase(&optcrit),DIST) ne 0 %then %do;
    scatter x=_1mspec_ y=_sensit_ / markerchar=_OPTDIST_ 
      %if &optsymbolstyle ne %then markercharattrs=(&optsymbolstyle);;
    %end;
    %if %index(%upcase(&optcrit),YOUDEN) ne 0 %then %do;
    scatter x=_1mspec_ y=_sensit_ / markerchar=_OPTY_ 
      %if &optsymbolstyle ne %then markercharattrs=(&optsymbolstyle);;
    %end;
    %if %index(%upcase(&optcrit),SESPDIFF) ne 0 %then %do;
    scatter x=_1mspec_ y=_sensit_ / markerchar=_OPTSESP_ 
      %if &optsymbolstyle ne %then markercharattrs=(&optsymbolstyle);;
    %end;
    %if %index(%upcase(&optcrit),EFF) ne 0 %then %do;
    scatter x=_1mspec_ y=_sensit_ / markerchar=_OPTEFF_ 
      %if &optsymbolstyle ne %then markercharattrs=(&optsymbolstyle);;
    %end;
    %if %index(%upcase(&optcrit),COST) ne 0 %then %do;
    scatter x=_1mspec_ y=_sensit_ / markerchar=_OPTCOST_ 
      %if &optsymbolstyle ne %then markercharattrs=(&optsymbolstyle);;
    %end;
    %if %index(%upcase(&optcrit),MCT) %then %do;
    scatter x=_1mspec_ y=_sensit_ / markerchar=_OPTMCT_ 
      %if &optsymbolstyle ne %then markercharattrs=(&optsymbolstyle);;
    %end;
    %if %upcase(%substr(&altaxislabel,1,1))=Y %then
    label _1mspec_="False Positive Rate" _sensit_="True Positive Rate";;
    footnote "Points labeled by: &id";
    run;

   %if %sysevalf(&sysver < 9.4) %then %do;
      ods graphics / reset=height reset=width; 
   %end;
   
%end;

/* ----------------- Table of global optimal cutpoints ----------------- */

%if &optcrit ne or %index(%upcase(&id),_OPT) ne 0 %then %do;
  proc sort data=_optcrit;
    by Criterion Symbol;
    run;
  proc print data=_optcrit label;
    var _prob_ _id _value; 
    id Criterion Symbol;
    title "Optimal Cutpoints";
    run;
  title;
  footnote;
%end;


/* ================= PLOTTING OF OPTIMALITY CRITERIA ================= */
%if &optcrit ne %then %do;


/* ------------ Prepare data for plotting ------------ */
%if %upcase(&optbyx) ne NO and &x ne %then %do;
  proc sort data=&outrocdata out=_sortroc;
    by &x;
    run;
  proc means data=_sortroc noprint;
    by &x;
    output out=_pltcrit 
         max(__CORRECT_ __YOUDEN_)=_maxcorrbyx _maxybyx
         min(__DIST01_ __SESPDIFF_)=_mindistbyx _minsespbyx
         max(_eff:)=
     %if &docost %then max(_cr:)= ;
     %if &domct %then min(_mcr:)= ;
     / autoname;
    ;
    run;
%end;

%if %index(%upcase(&optcrit),COST) ne 0 %then %do;
    proc sort data=_mincosts;
      by _cr _prv;
      run;
%end;
%if %index(%upcase(&optcrit),MCT) ne 0 %then %do;
    proc sort data=_minmct;
      by _cr _prv;
      run;
%end;
%if %index(%upcase(&optcrit),EFF) ne 0 %then %do;
    proc sort data=_maxeff;
      by _prv;
      run;
%end;

/* ------------ Panel plot of all criteria by predictor ------------ */
%if &ncrit=1 and %upcase(&optbyx)=PANELALL and &x ne %then 
  %let optbyx=PANELEACH;
%else %if &ncrit > 1 and %upcase(&optbyx)=PANELALL and &x ne %then %do;
   proc template;
      define statgraph OptCritPanel;
      begingraph/ designheight=defaultdesignwidth;
         layout lattice / columns=2 columndatarange=union
                columngutter=2%;
            columnaxes;
              columnaxis;
              columnaxis;
            endcolumnaxes;
         %if %index(%upcase(&optcrit),CORRECT) ne 0 %then %do;
            cell;
              cellheader;
                entry "Correct";
              endcellheader;
              seriesplot y=_maxcorrbyx x=&x / 
              %if %upcase(%substr(&markers,1,1))=Y %then display=all; 
                         markerattrs=(symbol=&marker)
              %if &markerstyle ne %then markerattrs=(&markerstyle);
              %if &linestyle ne %then lineattrs=(&linestyle);
              ;
            endcell;
         %end;
         %if %index(%upcase(&optcrit),DIST) ne 0 %then %do;
            cell;
              cellheader;
                entry "Distance";
              endcellheader;
              seriesplot y=_mindistbyx x=&x / 
              %if %upcase(%substr(&markers,1,1))=Y %then display=all;
                         markerattrs=(symbol=&marker)
              %if &markerstyle ne %then markerattrs=(&markerstyle);
              %if &linestyle ne %then lineattrs=(&linestyle);
              ;
            endcell;
         %end;
         %if %index(%upcase(&optcrit),YOUDEN) ne 0 %then %do;
            cell;
              cellheader;
                entry "Youden";
              endcellheader;
              seriesplot y=_maxybyx x=&x / 
              %if %upcase(%substr(&markers,1,1))=Y %then display=all;
                         markerattrs=(symbol=&marker)
              %if &markerstyle ne %then markerattrs=(&markerstyle);
              %if &linestyle ne %then lineattrs=(&linestyle);
              ;
            endcell;
         %end;
         %if %index(%upcase(&optcrit),SESPDIFF) ne 0 %then %do;
            cell;
              cellheader;
                entry "Sens - Spec";
              endcellheader;
              seriesplot y=_minsespbyx x=&x / 
              %if %upcase(%substr(&markers,1,1))=Y %then display=all;
                         markerattrs=(symbol=&marker)
              %if &markerstyle ne %then markerattrs=(&markerstyle);
              %if &linestyle ne %then lineattrs=(&linestyle);
              ;
            endcell;
         %end;
         %if %index(%upcase(&optcrit),COST) ne 0 %then %do;
            cell;
              cellheader;
                entry "Cost";
              endcellheader;
              layout overlay;
               %let k=1;
               %do i=1 %to &ncr;
                %do j=1 %to &np;
                  seriesplot y=_cr&i.p&j._Max x=&x / 
                  %if %upcase(%substr(&markers,1,1))=Y %then display=all;
                  %if &ncr=1 and &np=1 %then %do;
                    markerattrs=(symbol=&marker)
                    %if &markerstyle ne %then markerattrs=(&markerstyle);
                    %if &linestyle ne %then lineattrs=(&linestyle);
                  %end;
                  %else %do;
                    markerattrs=GraphData&k(symbol=&marker)
                    lineattrs=GraphData&k
                  %end;
                  ;
                  %let k=%eval(&k+1);
                %end;
               %end;
              endlayout;
            endcell;
         %end;
         %if %index(%upcase(&optcrit),MCT) ne 0 %then %do;
            cell;
              cellheader;
                entry "MCT";
              endcellheader;
              layout overlay;
               %let k=1;
               %do i=1 %to &ncr;
                %do j=1 %to &np;
                  seriesplot y=_mcr&i.p&j._Min x=&x / 
                  %if %upcase(%substr(&markers,1,1))=Y %then display=all;
                  %if &ncr=1 and &np=1 %then %do;
                    markerattrs=(symbol=&marker)
                    %if &markerstyle ne %then markerattrs=(&markerstyle);
                    %if &linestyle ne %then lineattrs=(&linestyle);
                  %end;
                  %else %do;
                    markerattrs=GraphData&k(symbol=&marker)
                    lineattrs=GraphData&k
                  %end;
                  ;
                  %let k=%eval(&k+1);
                %end;
               %end;
              endlayout;
            endcell;
         %end;
         %if %index(%upcase(&optcrit),EFF) ne 0 %then %do;
            cell;
              cellheader;
                entry "Efficiency";
              endcellheader;
              layout overlay;
               %let k=1;
               %do j=1 %to &np;
                 seriesplot y=_effp&j._Max x=&x / 
                 %if %upcase(%substr(&markers,1,1))=Y %then display=all;
                  %if &np=1 %then %do;
                    markerattrs=(symbol=&marker)
                    %if &markerstyle ne %then markerattrs=(&markerstyle);
                    %if &linestyle ne %then lineattrs=(&linestyle);
                  %end;
                  %else %do;
                    markerattrs=GraphData&k(symbol=&marker)
                    lineattrs=GraphData&k
                  %end;
                 ;
                 %let k=%eval(&k+1);
               %end;
              endlayout;
            endcell;
         %end;
         endlayout;
      endgraph;
      end;
      run;
   proc sgrender data=_pltcrit template=OptCritPanel;
      label _maxcorrbyx="Correct rate"
            _mindistbyx="Distance to 0,1"
            _minsespbyx="Sens - Spec"
            _maxybyx="Value"
            _effp1_Max="Efficiency"
            ;
      title "Optimality Criteria By &x";
      run;
%end;


/* ------------ Panel plot of multiscenario criteria ------------ */
%if %upcase(&multoptplot)=PANELALL and 
    (&nmultcrit=1 or (&ncr <= 1 and &np = 1)) %then %let multoptplot=YES;
%else %if &nmultcrit > 1 and %upcase(&multoptplot)=PANELALL %then %do;
  data _multoptplot;
    merge 
     %if %index(%upcase(&optcrit),COST) ne 0 %then
      _mincosts(rename=(_value=_mopvcost _cr=_mopcrcost 
                        _prv=_moppcost _id=_mopidcost));
     %if %index(%upcase(&optcrit),MCT) ne 0 %then
      _minmct(rename=(_value=_mopvmct _cr=_mopcrmct
                      _prv=_moppmct _id=_mopidmct));
     %if %index(%upcase(&optcrit),EFF) ne 0 %then
      _maxeff(rename=(_value=_mopveff _prv=_moppeff _id=_mopideff));
    ;
    keep _mop:;
    run;
  proc template;
     define statgraph MultOptPlot;
     begingraph/ designheight=defaultdesignwidth;
        layout lattice / columns=2 columngutter=2% rowgutter=2%;
         %if %index(%upcase(&optcrit),COST) ne 0 %then %do;
          cell;
            cellheader;
             entry "Cost - Larger is better";
            endcellheader;
            layout overlay;
              seriesplot y=_mopvcost x=_mopcrcost / group=_moppcost 
                  datalabel=_mopidcost name="cost" 
                  %if %upcase(%substr(&markers,1,1))=Y %then display=all; 
                  markerattrs=(symbol=&marker)
                  %if &labelstyle ne %then datalabelattrs=(&labelstyle);
                  %if &np=1 %then %do;
                   %if &markerstyle ne %then markerattrs=(&markerstyle);
                   %if &linestyle ne %then lineattrs=(&linestyle);
                  %end;
              ;
            endlayout;
          endcell;
         %end;
         %if %index(%upcase(&optcrit),MCT) ne 0 %then %do;
          cell;
            cellheader;
             entry "MCT - Smaller is better";
            endcellheader;
            layout overlay;
              seriesplot y=_mopvmct x=_mopcrmct / group=_moppmct 
                  datalabel=_mopidmct name="mct" 
                  %if %upcase(%substr(&markers,1,1))=Y %then display=all; 
                  markerattrs=(symbol=&marker)
                  %if &labelstyle ne %then datalabelattrs=(&labelstyle);
                  %if &np=1 %then %do;
                   %if &markerstyle ne %then markerattrs=(&markerstyle);
                   %if &linestyle ne %then lineattrs=(&linestyle);
                  %end;
              ;
            endlayout;
          endcell;
         %end;
         %if %index(%upcase(&optcrit),EFF) ne 0 and &np > 1 %then %do;
          cell;
            cellheader;
             entry "Efficiency - Larger is better";
            endcellheader;
            layout overlay;
              seriesplot y=_mopveff x=_moppeff / datalabel=_mopideff 
                  %if %upcase(%substr(&markers,1,1))=Y %then display=all; 
                  markerattrs=(symbol=&marker)
                  %if &markerstyle ne %then markerattrs=(&markerstyle);
                  %if &linestyle ne %then lineattrs=(&linestyle);
                  %if &labelstyle ne %then datalabelattrs=(&labelstyle);
              ;
            endlayout;
          endcell;
         %end;
         %if &nmultcrit = 3 and &np > 1 %then %do;
           %if %index(%upcase(&optcrit),COST) ne 0 %then %do;
            cell;
              layout gridded / border=false;
                discretelegend "cost" / border=false title="Prevalence:";
              endlayout;
            endcell;
           %end;
           %else %do;
            cell;
              layout gridded / border=false;
                discretelegend "mct" / border=false title="Prevalence:";
              endlayout;
            endcell;
           %end;
         %end;
        endlayout;
       %if &nmultcrit = 2 or (&nmultcrit = 3 and &np = 1) %then %do;
         %if %index(%upcase(&optcrit),COST) ne 0 %then %do;
            layout globallegend / border=false;
              discretelegend "cost" / border=false title="Prevalence:";
            endlayout;
         %end;
         %else %do;
            layout globallegend / border=false;
              discretelegend "mct" / border=false title="Prevalence:";
            endlayout;
         %end;
       %end;
     endgraph;
     end;
     run;
  proc sgrender data=_multoptplot template=MultOptPlot;
     label 
      %if %index(%upcase(&optcrit),COST) ne 0 %then _mopvcost="Value";
      %if %index(%upcase(&optcrit),MCT) ne 0 %then _mopvmct="Value";
      %if %index(%upcase(&optcrit),EFF) ne 0 %then _mopveff="Efficiency";
     ;
     title "Prevalence-Dependent Optimality Criteria";
     footnote "Points labeled by: &id";
     run;
%end;

/* ----------- Correct classification plot ----------- */

%if %index(%upcase(&optcrit),CORRECT) ne 0 and 
    (%index(%upcase(&optbyx),YES) ne 0 or 
    %index(%upcase(&optbyx),PANELEACH) ne 0) and &x ne 
%then %do;
  proc sgplot data=_pltcrit;
    series y=_maxcorrbyx x=&x / 
           %if %upcase(%substr(&markers,1,1))=Y %then markers;
           markerattrs=(symbol=&marker)
           %if &markerstyle ne %then markerattrs=(&markerstyle);
           %if &linestyle ne %then lineattrs=(&linestyle);
    ;
    title "Correct Classification Criterion";
    footnote;
    label _maxcorrbyx="Correct rate";
    run;
%end;

/* -------------- Distance to 0,1 plot --------------- */

%if %index(%upcase(&optcrit),DIST) ne 0 and 
    (%index(%upcase(&optbyx),YES) ne 0 or 
    %index(%upcase(&optbyx),PANELEACH) ne 0) and &x ne 
%then %do;
  proc sgplot data=_pltcrit;
    series y=_mindistbyx x=&x / 
           %if %upcase(%substr(&markers,1,1))=Y %then markers;
           markerattrs=(symbol=&marker)
           %if &markerstyle ne %then markerattrs=(&markerstyle);
           %if &linestyle ne %then lineattrs=(&linestyle);
    ;
    title "Distance to 0,1 Criterion";
    title2 "Smaller distance is better";
    footnote;
    label _mindistbyx="Distance to 0,1";
    run;
%end;

/* ------------------ Sens=Spec plot ------------------ */

%if %index(%upcase(&optcrit),SESPDIFF) ne 0 and 
    (%index(%upcase(&optbyx),YES) ne 0 or 
    %index(%upcase(&optbyx),PANELEACH) ne 0) and &x ne 
%then %do;
  proc sgplot data=_pltcrit;
    series y=_minsespbyx x=&x / 
           %if %upcase(%substr(&markers,1,1))=Y %then markers;
           markerattrs=(symbol=&marker)
           %if &markerstyle ne %then markerattrs=(&markerstyle);
           %if &linestyle ne %then lineattrs=(&linestyle);
    ;
    title "Sensitivity - Specificity Criterion";
    title2 "Smaller difference is better";
    footnote;
    label _minsespbyx="Sens - Spec";
    run;
%end;

/* ------------------- Youden plot ------------------- */

%if %index(%upcase(&optcrit),YOUDEN) ne 0 and 
    (%index(%upcase(&optbyx),YES) ne 0 or 
    %index(%upcase(&optbyx),PANELEACH) ne 0) and &x ne 
%then %do;
  proc sgplot data=_pltcrit;
    series y=_maxybyx x=&x / 
           %if %upcase(%substr(&markers,1,1))=Y %then markers;
           markerattrs=(symbol=&marker)
           %if &markerstyle ne %then markerattrs=(&markerstyle);
           %if &linestyle ne %then lineattrs=(&linestyle);
    ;
    title "Youden Criterion";
    title2 "Larger Youden value is better";
    footnote;
    label _maxybyx="Value";
    run;
%end;

/* --------------- Cost plots and table -------------- */

%if %index(%upcase(&optcrit),COST) ne 0 %then %do;
  %if %index(%upcase(&optbyx),PANELEACH) ne 0 and &x ne %then %do;
    proc sql;
      create table _paneleach as 
      %do i=1 %to &ncr;
        %do j=1 %to &np;
          %let p=%scan(&pevent,&j,%str( ));
          %let c=%scan(&costratio,&i,%str( ));
          select "CostRatio=&c Prev=&p" as crp, _cr&i.p&j._Max as y, &x from _pltcrit
          %if &i < &ncr or &j < &np %then outer union corr;
        %end;
      %end;
    ;
    proc sgpanel data=_paneleach;
      panelby crp / novarname onepanel;
      series y=y x=&x / 
             %if %upcase(%substr(&markers,1,1))=Y %then markers;
             markerattrs=(symbol=&marker)
             %if &markerstyle ne %then markerattrs=(&markerstyle);
             %if &linestyle ne %then lineattrs=(&linestyle);
      ;
      title "Cost Criterion";
      title2 "Maximize Value to Minimize Cost";
      footnote;
      run;
  %end;
  %else %if %index(%upcase(&optbyx),YES) ne 0 and &x ne %then %do;
    %let pltnames=;
    proc sgplot data=_pltcrit;
      %do i=1 %to &ncr;
        %do j=1 %to &np;
          %let p=%scan(&pevent,&j,%str( ));
          %let c=%scan(&costratio,&i,%str( ));
          series y=_cr&i.p&j._Max x=&x / legendlabel="CostRatio=&c Prev=&p" 
                 name="c&i.p&j" 
                 %if %upcase(%substr(&markers,1,1))=Y %then markers;
                 markerattrs=(symbol=&marker)
                 %if &ncr=1 and &np=1 %then %do;
                   %if &markerstyle ne %then markerattrs=(&markerstyle);
                   %if &linestyle ne %then lineattrs=(&linestyle);
                 %end;
          ;
          %let pltnames=&pltnames %quote(")c&i.p&j%quote(");
        %end;
      %end;
      keylegend &pltnames;;
      title "Cost Criterion";
      title2 "Maximize Value to Minimize Cost";
      footnote;
      label _cr1p1_Max="Value";
      run;
  %end;
  %if (%index(%upcase(&multoptplot),YES) ne 0 or
      %index(%upcase(&multoptlist),YES) ne 0) 
  %then %do;
    proc sort data=_mincosts;
      by _prv _cr;
      run;
  %end;
  %if %index(%upcase(&multoptplot),YES) ne 0 and (&ncr > 1 or &np > 1)
  %then %do;
    proc sgplot data=_mincosts;
      series y=_value x=_cr / group=_prv datalabel=_id
             %if %upcase(%substr(&markers,1,1))=Y %then markers;
             markerattrs=(symbol=&marker)
             %if &labelstyle ne %then datalabelattrs=(&labelstyle);
             %if &np=1 %then %do;
                %if &markerstyle ne %then markerattrs=(&markerstyle);
                %if &linestyle ne %then lineattrs=(&linestyle);
             %end;
      ;
      title "Cost-Based Optimal Cutpoints";
      title2 "Maximize Value to Minimize Cost";
      footnote "Points labeled by: &id";
      run;
  %end;
  %if %index(%upcase(&multoptlist),YES) ne 0
  %then %do;
      proc print data=_mincosts label;
        var _prob_ _id _value;
        id _prv _cr;
        title "Cost-Based Optimal Cutpoints";
        title2 "Maximize Value to Minimize Cost";
        footnote "Points labeled by: &id";
        run;
  %end;
%end;

/* -------- Misclassification term (MCT) plot -------- */
%if %index(%upcase(&optcrit),MCT) ne 0 %then %do;
  %if %index(%upcase(&optbyx),PANELEACH) ne 0 and &x ne %then %do;
    proc sql;
      create table _paneleach as 
      %do i=1 %to &ncr;
        %do j=1 %to &np;
          %let p=%scan(&pevent,&j,%str( ));
          %let c=%scan(&costratio,&i,%str( ));
          select "CostRatio=&c Prev=&p" as crp, _mcr&i.p&j._Min as y, &x from _pltcrit
          %if &i < &ncr or &j < &np %then outer union corr;
        %end;
      %end;
    ;
    proc sgpanel data=_paneleach;
      panelby crp / novarname onepanel;
      series y=y x=&x / 
             %if %upcase(%substr(&markers,1,1))=Y %then markers;
             markerattrs=(symbol=&marker)
             %if &markerstyle ne %then markerattrs=(&markerstyle);
             %if &linestyle ne %then lineattrs=(&linestyle);
      ;
      title "Misclassification term (MCT) Criterion";
      title2 "Smaller MCT value is better";
      footnote;
      run;
  %end;
  %else %if %index(%upcase(&optbyx),YES) ne 0 and &x ne %then %do;
    %let pltnames=;
    proc sgplot data=_pltcrit;
      %do i=1 %to &ncr;
        %do j=1 %to &np;
          %let p=%scan(&pevent,&j,%str( ));
          %let c=%scan(&costratio,&i,%str( ));
          series y=_mcr&i.p&j._Min x=&x / legendlabel="CostRatio=&c Prev=&p" 
                 name="c&i.p&j" 
                 %if %upcase(%substr(&markers,1,1))=Y %then markers;
                 markerattrs=(symbol=&marker)
                 %if &ncr=1 and &np=1 %then %do;
                   %if &markerstyle ne %then markerattrs=(&markerstyle);
                   %if &linestyle ne %then lineattrs=(&linestyle);
                 %end;
          ;
          %let pltnames=&pltnames %quote(")c&i.p&j%quote(");
        %end;
      %end;
      keylegend &pltnames;;
      title "Misclassification term (MCT) Criterion";
      title2 "Smaller MCT value is better";
      footnote;
      label _mcr1p1_Min="Value";
      run;
  %end;
  %if (%index(%upcase(&multoptplot),YES) ne 0 or
      %index(%upcase(&multoptlist),YES) ne 0)
  %then %do;
    proc sort data=_minmct;
      by _prv _cr;
      run;
  %end;
  %if %index(%upcase(&multoptplot),YES) ne 0 and (&ncr > 1 or &np > 1)
  %then %do;
    proc sgplot data=_minmct;
      series y=_value x=_cr / group=_prv datalabel=_id
             %if %upcase(%substr(&markers,1,1))=Y %then markers;
             markerattrs=(symbol=&marker)
             %if &labelstyle ne %then datalabelattrs=(&labelstyle);
             %if &np=1 %then %do;
                %if &markerstyle ne %then markerattrs=(&markerstyle);
                %if &linestyle ne %then lineattrs=(&linestyle);
             %end;
      ;
      title "MCT-Based Optimal Cutpoints";
      title2 "Smaller MCT value is better";
      footnote "Points labeled by: &id";
      run;
  %end;
  %if %index(%upcase(&multoptlist),YES) ne 0
  %then %do;
      proc print data=_minmct label;
        var _prob_ _id _value;
        id _prv _cr;
        title "MCT-Based Optimal Cutpoints";
        title2 "Smaller MCT value is better";
        footnote "Points labeled by: &id";
        run;
  %end;
%end;


/* ----------------- Efficiency plot ----------------- */

%if %index(%upcase(&optcrit),EFF) ne 0 %then %do;
  %if %index(%upcase(&optbyx),PANELEACH) ne 0 and &x ne %then %do;
    proc sql;
      create table _paneleach as 
        %do j=1 %to &np;
          %let p=%scan(&pevent,&j,%str( ));
          select "Prev=&p" as crp, _effp&j._Max as y, &x from _pltcrit
          %if &j < &np %then outer union corr;
        %end;
    ;
    proc sgpanel data=_paneleach;
      panelby crp / novarname onepanel;
      series y=y x=&x / 
             %if %upcase(%substr(&markers,1,1))=Y %then markers;
             markerattrs=(symbol=&marker)
             %if &markerstyle ne %then markerattrs=(&markerstyle);
             %if &linestyle ne %then lineattrs=(&linestyle);
      ;
      label y="Efficiency";
      title "Efficiency";
      title2 "Larger efficiency is better";
      footnote;
      run;
  %end;
  %else %if %index(%upcase(&optbyx),YES) ne 0 and &x ne %then %do;
    %let pltnames=;
    proc sgplot data=_pltcrit;
        %do j=1 %to &np;
          %let p=%scan(&pevent,&j,%str( ));
          series y=_effp&j._Max x=&x / legendlabel="Prev=&p" 
                 name="p&j" 
                 %if %upcase(%substr(&markers,1,1))=Y %then markers; markerattrs=(symbol=&marker)
                  %if &np=1 %then %do;
                    %if &markerstyle ne %then markerattrs=(&markerstyle);
                    %if &linestyle ne %then lineattrs=(&linestyle);
                  %end;
          ;
          %let pltnames=&pltnames %quote(")p&j%quote(");
        %end;
      keylegend &pltnames;;
      title "Efficiency";
      title2 "Larger efficiency is better";
      footnote;
      label _effp1_Max="Value";
      run;
  %end;
  %if (%index(%upcase(&multoptplot),YES) ne 0 or
      %index(%upcase(&multoptlist),YES) ne 0)
  %then %do;
    proc sort data=_maxeff;
      by _prv;
      run;
  %end;
  %if %index(%upcase(&multoptplot),YES) ne 0 and &np > 1
  %then %do;
    proc sgplot data=_maxeff;
      series y=_value x=_prv / datalabel=_id
             %if %upcase(%substr(&markers,1,1))=Y %then markers;
             markerattrs=(symbol=&marker)
             %if &markerstyle ne %then markerattrs=(&markerstyle);
             %if &linestyle ne %then lineattrs=(&linestyle);
             %if &labelstyle ne %then datalabelattrs=(&labelstyle);
      ;
      title "Efficiency Optimal Cutpoints";
      title2 "Larger efficiency is better";
      footnote "Points labeled by: &id";
      run;
  %end;
  %if %index(%upcase(&multoptlist),YES) ne 0
  %then %do;
    proc print data=_maxeff label;
      var _prob_ _id _value;
      id _prv;
      title "Efficiency-Based Optimal Cutpoints";
      title2 "Larger efficiency is better";
      footnote "Points labeled by: &id";
      run;
  %end;
%end;

%end;

%if &version ne debug %then %do;
  options notes;
  data &outrocdata;
    set &outrocdata;
    drop _opt _labelgrp;
    run;
  options nonotes;

  proc datasets nolist; 
    delete _inpred _inroc _optvals _add00 _rpdesc
      %if &idnum ne %then _labstats;
      %if &optcrit ne %then %do;
        %if %upcase(&optbyx) ne NO and &x ne %then _sortroc _pltcrit;
        %if &nmultcrit > 1 and %upcase(&multoptplot)=PANELALL %then 
           _multoptplot;
      %end;
      %if %upcase(%substr(&plottype,1,1))=H %then _mrkrchars;
      %if %index(%upcase(&optbyx),PANELEACH) ne 0 and &x ne and
          (%index(%upcase(&optcrit),COST) ne 0 or 
           %index(%upcase(&optcrit),MCT) ne 0 or
           %index(%upcase(&optcrit),EFF) ne 0)
      %then _paneleach;
    ; 
    run; quit;
%end;

footnote; title;

%exit:
options &opts;

%let time = %sysfunc(round(%sysevalf(%sysfunc(datetime()) - &time), 0.01));
%put NOTE: The ROCPLOT macro used &time seconds.;

%mend;
%ROCplot( OUTROC=cv_roc, OUT=cv_scored, P=p_1, GRID=yes, RESPONSE=survived,
PATH=&outroot, FILENAME=ROC Chart2 );