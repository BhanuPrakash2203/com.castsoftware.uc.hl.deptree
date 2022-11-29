@echo off
SETLOCAL

REM set environment
set PATH=C:\strawberry\perl\bin;C:\strawberry\c\bin;%PATH%
set PERL5LIB=C:\strawberry\perl\lib;C:\strawberry\perl\site\lib;%PERL5LIB%
set PATH=C:\Users\JLE\hlhf\Client\Perl\Analyzers;C:\Users\JLE\hlhf\Client\Perl\Analyzers\technos;%PATH%
set PERL5LIB=C:\Users\JLE\hlhf\Client\Perl\Analyzers;%PERL5LIB%

REM clean dirs
RMDIR /S /Q .\output
RMDIR /S /Q .\dialog
RMDIR /S /Q .\tmp

REM launch keywordscan
REM test keywordGroup xml version
cls & perl -S Analyse.pl --dir=output --KeywordScan="keywordGroup.xml" --language=Cobol testfile.y

REM delete csv header
For %%A in (".\output\*KeywordScan*") do findstr /v /r #uuid %%~fA > .\output\tmp
For %%A in (".\output\*KeywordScan*") do findstr /v /r #start_date .\output\tmp > .\output\tmp1
For %%A in (".\output\*KeywordScan*") do findstr /v /r #version_highlight .\output\tmp1 > .\output\keywordGroup.csv

REM compare files
For %%A in (".\output\*KeywordScan*") do fc .\output\keywordGroup.csv keywordGroup.csv > nul
if errorlevel 1 goto error

:next
goto nextTest

:error
echo -------
echo KeywordScan tests keywordGroup : failed
goto end_failed

:nextTest
REM clean output
RMDIR /S /Q .\output
RMDIR /S /Q .\dialog
RMDIR /S /Q .\tmp

REM launch keywordscan
REM test patternGroup xml version
perl -S Analyse.pl --dir=output --KeywordScan="patternGroup.xml" --language=Cobol testfile.y

REM delete csv header
For %%A in (".\output\*KeywordScan*") do findstr /v /r #uuid %%~fA > .\output\tmp
For %%A in (".\output\*KeywordScan*") do findstr /v /r #start_date .\output\tmp > .\output\tmp1
For %%A in (".\output\*KeywordScan*") do findstr /v /r #version_highlight .\output\tmp1 > .\output\patternGroup.csv

REM compare files
For %%A in (".\output\*KeywordScan*") do fc .\output\patternGroup.csv patternGroup.csv > nul
if errorlevel 1 goto error2

:next
echo -------
echo RESULTS: all tests are succeeded
echo KeywordScan tests keywordGroup : succeeded
echo KeywordScan tests patternGroup : succeeded
echo -------
goto end2

:error2
echo -------
echo KeywordScan tests patternGroup : failed
goto end_failed

:end_failed
echo -------
echo RESULTS:
echo KeywordScan tests : failed (please see output folder for debug)
echo -------
goto end3

:end2
REM clean output
RMDIR /S /Q .\output
RMDIR /S /Q .\dialog
RMDIR /S /Q .\tmp

:end3
pause