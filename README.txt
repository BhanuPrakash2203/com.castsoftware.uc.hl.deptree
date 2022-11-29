                    `-/+syhhhhhhhhys+/-`
                ./shmmmmmmmmmmmmmmmmmmmmhs/.
             -+hmmmmmdyso+++++++++ooshdmmmmmh+-
          `/ymmmmds+/+shddmmmmmmmmddhso+oydmmmmy/`
        `/hmmmds/+ydmmmmmmdhhhhhddmmmmmmdy++ymmmmh/`
       -ymmmd+/sdmmmmhs++++ossssoo++oshmmmmdy+smmmmy-
      /dmmmo:smmmmy+/oydmmmmmmmmmmmmdyo+ohmmmmy/ymmmd/
     ommmd:+dmmmy/+hmmmmdys+///+osydmmmmho+hmmmdo+mmmmo
    +mmmh-smmmd//hmmmho-``        `.:sdmmmh+ommmms/dmmm+
   :mmmd-smmmy-smmmh/`                .+dmmms/dmmms/mmmm:
  `hmmm:+mmmh.ymmms`                    -hmmmy:dmmm+ommmh`
  :mmmy.dmmm:+mmms`                      .hmmm+ommmd:dmmm:
  smmm+/mmmh.dmmd.          `..           :mmmd-dmmm/ymmms
  ymmm:ommmo-mmmy         `/hddo          `dmmm-hmmmoommmy
  ymmm:ommmo-mmmy       `/hmmmd/          `dmmm-hmmmoommmy
  smmm+/mmmh.dmmd.    .+hmmmdo.           :mmmd-dmmm/ymmms
  :mmmy.dmmm:+mmms` `+hmmmd+.            .hmmmo+mmmd:dmmm:
  `hmmm:+mmmh.ymmy-+dmmmd+`             -hmmmy:dmmm+ommmh`
   :mmmd-smmmy-o/+hmmmd+`             `+dmmmy/dmmmy/mmmm:
    ommmh-smmy:+dmmmd+`               :dmmd++mmmmy/dmmmo
     ommmd:+/+hmmmd+`                  .s++hmmmdo+mmmmo
      +mmy//hmmmd+`                      -hmmmy/ymmmm+
       -:/dmmmd+`                         `os/smmmmh-
        /mmmdo`                             `ymmmd/`
        `/+/`                                 /y/`



----------------------------
Copyrights 2020 - CAST
----------------------------
Tested on Ubuntu 16.0.4, CentOS/7, Windows 10
----------------------------
For any question or feedback regarding this command line, please contact us at support@casthighlight.com

----------------------------
Mac OS is not supported
----------------------------
Please use the official docker image on docker hub: https://hub.docker.com/r/casthighlight/hl-agent-cli

Further instructions on how to use the docker version of the CLI can be found here:

https://doc.casthighlight.com/product-tutorials-third-party-tools/cast-highlights-docker-image-code-scans/

----------------------------
Requirements
----------------------------

### For Linux - Debian based systems

Perl
----
Perl 5, libjson-perl, libxml-libxml-perl, libmath-bigint-perl, libtime-hires-perl

To check perl version:
$>perl -v

To check required libraries are installed:
$>dpkg --get-selections libxml-libxml-perl libjson-perl 

To install the above libraries:
$>apt-get install libxml-libxml-perl libjson-perl libmath-bigint-perl libtime-hires-perl

### For Linux - RHEL/CENTOS based systems

Install the libraries: perl-XML-LibXML, perl-JSON and perl-Digest-SHA

$>yum -y install perl-Digest-SHA
$>yum -y install perl-JSON
$>yum -y install perl-XML-LibXML
$>yum -u install perl-Time-HiRes
$>yum -u install perl-Math-BigInt


Java
----
Java 11
$>java -version


### For Windows
Prior using the command line, you'll have to install the Highlight Local Agent on your machine, in order to embed the required Perl binaries.



======================
Option (* = required)              Description
---------------------              -----------
--help

Print supported technologies

--printTechnos

Scanning Options

* --sourceDir                      The absolute path to the directory that contains the source code to be scanned by Highlight.
* --workingDir                     This is the absolute path to the Highlight working directory. Within this directory, a Highlight temporary folder ("HLTemporary") will be created and will contain scan result files (CSVs).
--technologies                     Technologies you want to explicitly scan, separated by "," and sorted by preferences (e.g. "Java,Python"). See --printTechnos option above to get the technology list.
--ignoreFiles                      File name patterns (regex possibility) to ignore during a scan, separated by "," (e.g. "foo\.cs,bar\.cs,.*lo\.js,hel.*\.js").
--ignoreDirectories                Directory name patterns (regex possibility) to ignore during a scan, separated by "," (e.g. "test,\.git,COTS").
--ignorePaths                      Regex used to exclude paths (e.g. ^subproject/node_modules|^.*test - skip node_modules from subproject and all path with prefix ending with test) 
Note: Use slashes or anti slashes according to the OS

Scan result options
    By default result are directly uploaded to server
        --skipUpload                       Only CSV generation. No upload performed
        --zipResult <String>               Combined with skipUpload, create a zip file with all CSV results (this file might be uploaded on the portal or using command line)

    By default command line consider that we scan all sources at once
        --appendResult                     Allow to append results to previously uploaded results for application/label/date (see example Append Result)
        --skipSubmit                       Results submit will not be sent after upload process (see example Append Result)

Result upload options (after --skipUpload)
    --uploadZipFile <String>           Use this option to treat a file created with "zipResult". Take the zip file full path.

Login and upload to server options
  --serverUrl			               The Highlight server instance where the results has to be uploaded (user credentials have to work on this server)

  Classic login using credentials
    --login                            Login to Highlight portal
    --password                         Password for indicated login

  Login using encoded credential (Basic Auth )
    --basicAuth                        BasicAuth value <=> Base64 encode of   login:password

  Login using OAuth genereated token in HL portal
    --tokenAuth                        Token generated using HL portal

  --companyId <Integer>              Identification for the company (can be retrieved from the Highlight portal, it is the ID displayed in the url when clicking on "MANAGE PORTFOLIO" from the menu)

  Identifying the result (see Result Identification info)
    --applicationId <Integer>          Identification for the application (can be retried from the Highlight portal, it is the ID displayed in the url when editing an application in "MANAGE PORTFOLIO")
    --snapshotLabel <label>            The application snapshot label you want to display on the application result page on the portal (e.g. release version, build number, etc.)
    --snapshotDatetime <Long>          Time (epoch) to use for uploaded application snapshot

Advanced options

    --analyzerDir		                   Alternate directory for Highlight's analyzer scripts.
    --analyzeBigFiles                      Allow to analyze files with size up to 3MB
    --dbgSourceList <String>               File name for discover file list export for debugging
    --perlInstallDir                       Root directory for perl installation. (Use it when perl installation is not found)
    --perl                                 Perl executable command.

Special options for Keywork Scanner
    --keywordScan <list>                   List of xml files describing keywords to scan. Separated by ,

Logs
----

Logfile is HLAutomation.log in --workingDir

----------------------------
Command Line Usage
----------------------------
java -jar HighlightAutomation.jar --workingDir <working directory> --sourceDir <path to the source directory to be scanned> --analyzerDir <path to Highlight Perl analyzers and scripts>  --skipUpload

You may use Command Line assistant on Highlight Portal on application scan page to generate the command line for an application with pre-filed parameters

----------------------------
Identifying the result
----------------------------
Results are identified with the following elements: applicationId, snapshotLabel, snapshotDate
Following logic is used to define if existing result for applicationId should be updated

A result exists with same applicationId / snapshotLabel / snapshotDate => update the result
A result exists with same applicationId / snapshotDate  (but different snapshotLabel) => update the result and change it's snapshotLabel
A result exists with same applicationId / snapshotLabel (but different snapshotDate) => update the result and change it's snapshotDate

For last update (snapshotDate modification). Operation might be refused when there is already a result for same application on target snapshotDate


----------------------------
Append Result Examples
----------------------------
Usage: if for one application scan operation need to be done on different places by different people, operation allow you to aggregated multiple scan results
Limit:
    scope of the scan should be correctly defined else duplicated information might false the results
    for same application upload are not possible in parallel  so operation should be done in sequence

Direct mode (scan+upload)

java -jar HighlightAutomation.jar <scan conf first part> <upload config> --skipSubmit
java -jar HighlightAutomation.jar <scan conf second part> <upload config> --skipSubmit --appendResult
java -jar HighlightAutomation.jar <scan conf third part> <upload config> --skipSubmit --appendResult
java -jar HighlightAutomation.jar <scan conf last part> <upload config>

Other mode (scan + zipResult + uploadZip)

java -jar HighlightAutomation.jar <scan conf first part> --skipUpload --zipResult resutl1.zip
java -jar HighlightAutomation.jar <scan conf second part> --skipUpload --zipResult resutl2.zip
java -jar HighlightAutomation.jar <scan conf third part> --skipUpload --zipResult resutl3.zip
java -jar HighlightAutomation.jar <scan conf last part>  --skipUpload --zipResult resutl4.zip

java -jar HighlightAutomation.jar <upload config> --uploadZipFile result1.zip --skipSubmit
java -jar HighlightAutomation.jar <upload config> --uploadZipFile result2.zip --skipSubmit --appendResult
java -jar HighlightAutomation.jar <upload config> --uploadZipFile result3.zip --skipSubmit --appendResult
java -jar HighlightAutomation.jar <upload config> --uploadZipFile result4.zip



Examples:
[Linux]
Scan sources in /home/user/myproject/src with results in /home/user/highlight-myproject
java -jar HighlightAutomation.jar --workingDir "/home/user/highlight-myproject/" --sourceDir "/home/user/svn/myproject/src/"  --skipUpload

[Windows]
Scan sources in C:\myproject\src with results in C:\highlight-myproject
java -jar HighlightAutomation.jar --workingDir "C:\highlight-myproject" --sourceDir "C:\myproject\src"  --skipUpload

[zipResult/uploadZipFile]
Scan sources in C:\myproject\src with results in C:\highlight-myproject
java -jar HighlightAutomation.jar --workingDir "C:\highlight-myproject" --sourceDir "C:\myproject\src"  --skipUpload --zipResult C:\zipResult\analyze_xxx.zip

Upload results
java -jar HighlightAutomation.jar  -basicAuth 0EFXDFED --companyId 2 --applicationId 8 --snapshotLabel scan_2_2019 --uploadZipFile C:\analyzerResults\analyze_xxx.zip


---------------------------
Command Line Return status
---------------------------

The Command Line process returns the following exit status:

0 - Ok
1 - Command Line general failure
2 - Command Line options parse error
3 - Command Line techno discovery error
4 - Command Line analysis error
5 - Command Line result upload error
6 - Command Line source dir or output dir validation error
7 - Command Line result saving to zip file error
8 - Command Line upload from zip file error

----------------------------
Help
----------------------------
--workingDir is the directory where you want to store scan results.
--sourceDir is the absolute path to the directory that contains source files to be scanned by CAST Highlight.

--------------------------------------
Special configuration for proxy server
--------------------------------------
Using a proxy server for upload.

Proxy with no password :
-Dhttps.proxyHost=<your proxy host>
-Dhttps.proxyPort=<your proxy port>

If a password is requested for proxy add the following additional parameter
-Dhttps.proxyUser=<user>
-Dhttps.proxyPassword=<password>

Examples:
java -Dhttps.proxyHost=your proxy host -Dhttps.proxyPort=your proxy port -Dhttps.proxyUser=user -Dhttps.proxyPassword=password -jar HighlightAutomation.jar --workingDir "C:\highlight-myproject" --sourceDir "C:\myproject\src" --login xxx --password xxxx

As proxy provider and configuration are multiple. You may still experience issue on specific configuration.

----------------------------
Potential configuration for slow network
----------------------------
Default value for connection and read timeout when accessing API for upload have been set to 5000 and 60000
Increasing them in command line call is possible even if not encourage
--connectTimeout 5000
--readTimeout 60000


----------------------------
Known problems
----------------------------
The analysis fail when the --workingDir is mounted on a shared directory of a VirtualBox

