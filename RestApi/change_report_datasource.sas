/* USed report : default samples Retail Insights */
/* Create new source - public.rand_retail_demo_new - from sample data with only west coast region */
/* Reference : https://github.com/sassoftware/devsascom-rest-api-samples/blob/master/Visualization/reportTransforms.md
	https://blogs.sas.com/content/sgf/2020/09/15/using-rest-api-to-transform-a-visual-analytics-report/#:~:text=The%20Report%20Transforms%20API%20provides%20simple%20alterations%20to,transform%20performs%20editing%20or%20modifications%20to%20a%20report. */

cas mysess;
caslib _ALL_ assign;
proc cas; table.droptable / name='rand_retail_demo_new' caslib='public' quiet=true; run;
data public.rand_retail_demo_new(promote=yes); set samples.rand_retaildemo(where=(Region='US_WC')); run;
cas mysess terminate;

/*
Reference : 
https://github.com/sassoftware/devsascom-rest-api-samples/blob/master/Visualization/reportTransforms.md
*/

* * GLOBAL VARIABLES **********************************************************;
* Base URI for the service call;
%let BASE_URI=%sysfunc(getoption(servicesbaseurl));

* Name of the report;
%let REPORT_NAME=Retail Insights;

* *Get ID of the report *********************************************************;

FILENAME rptFile TEMP ENCODING='UTF-8';

PROC HTTP METHOD = "GET" oauth_bearer=sas_services OUT = rptFile
      URL = "&BASE_URI/reports/reports?filter=eq(name,'&REPORT_NAME')";
      HEADERS "Accept" = "application/vnd.sas.collection+json"
               "Accept-Item" = "application/vnd.sas.summary+json";
RUN;
LIBNAME rptFile json;
proc sql noprint;
  select id into :report_id trimmed from rptFile.items;
quit;

* *change report data source *********************************************************;

* * Prepare json for body REST API call **********************************************;
* * to change samples.rand_retaildemo to public.rand_retail_demo_new;

filename json_in filesrvc folderpath="/Public" filename="json_in.json";

/* JSON body for parameters to change data source of a specific report and saving it to specific folder */
/* New report saved in /public as RetailInsightNew */

data _null_;
	file json_in;
	put '{'/
	  '"inputReportUri" : "/reports/reports/' "&report_id" '",'/
	  '"resultReportName" : "RetailInsightNew",'/
	  '"resultReport": {'/
      '"name": "RetailInsightNew",'/
      '"description": "TEST report transform"'/
      '},'/
	  '"resultParentFolderUri": "/folders/folders/f70b054e-ba40-4b5f-9038-cc0e2824af01",'/
	  '"dataSources": ['/
      '{'/
      '     "namePattern": "serverLibraryTable",'/
      '     "purpose": "original",'/
      '     "server": "cas-shared-default",'/
      '     "library": "samples",'/
      '     "table": "RAND_RETAILDEMO"'/
      ' },'/
      ' {'/
      '     "namePattern": "serverLibraryTable",'/
      '     "purpose": "replacement",'/
      '     "server": "cas-shared-default",'/
      '     "library": "PUBLIC",'/
      '     "table": "RAND_RETAIL_DEMO_NEW",'/
      '     "replacementLabel": "NEW RETAIL DEMO"'/
      ' }'/
	  ']'/
	  '}';
run;

%let REST_QUERY_URI=&BASE_URI/reportTransforms/dataMappedReports/?validate=true%str(&)useSavedReport=true%str(&)saveResult=true%str(&)failOnDataSourceError=true;

PROC HTTP METHOD = "POST" oauth_bearer=sas_services OUT = rptFile IN = json_in
      URL = "&REST_QUERY_URI";
      HEADERS "Accept" = "application/vnd.sas.report.transform+json"
               "Content-Type" = "application/vnd.sas.report.transform+json";
RUN;


