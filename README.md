# Highlight BOM Dependency Tree
The script is used to generate a dependency tree of Components upto the last level  

## Installation
* Download and unpack the latest release of the dependency tree tool from https://github.com/BhanuPrakash2203/com.castsoftware.uc.hl.deptree
   
* Install/update required third party packages. 
    * Open a command prompt 
    * run: pip install -r Configuration/requirements.txt   (requirements.txt file can be found inside configuration folder)
    * Run py UploadResults.py from command prompt

## Usage
The script is designed to run on the command line. It internally uses a properties.json file for input parameters.

    py UploadResults.py 

After running of UploadResults.py file, It ask users to enter diiferent numbers to use different parser.
1 - for JAVA parser
2 - for DOT NET parser
3 - for Python parser.

# Properties file
The HL Dependency Tool is configured using a properties.json file.  The file consists of various parameters which are required and need to be changed before running the tool.  
#### General Configuration
The general configuration section contains four parts,  
* hlJarPath - jar file of Higlight Automation (HighlightAutomation.jar)
* sourceDir - Path where source code is placed
* workingDir - Directory path where automations will do some intermediate activities
* analyzerDir - Path of the directory where Perl is installed
* companyId - Company ID of HIghlight Instance
* applicationId - Application ID of HIghlight Instance
* snapshotLabel - Provide the snapshot label, it can be any meaningful text(It should be different for different parser)
* serverUrl - Provide the HL server URL default is https://rpa.casthighlight.com/
* basicAuth - Base64 encoding of UserName:Password
* cyclodxOutput - Path to save the cyclonedx response.xml file
* save_path_file - Path to save the intermediate or newly generated response file
* outputfile - Path to save the filtered output file, this path should be in same as the source path which HL is going to consider for analysis

#### Tool Dependency file
This section contains a list of all the 3rd party dependencies which are used in the tool and need to be installed before running the tool,  
* subprocess - module allows you to spawn new processes
* requests - allows you to send HTTP requests using Python
* pandas - providing fast, flexible, and expressive data structures designed to make working with “relational” or “labeled” data both easy and intuitive
* xml -  for processing XML
* os - provides functions for interacting with the operating system
* re -  provides an interface to the regular expression engine
* lxml -  library for processing XML and HTML
* json - library to work with JSON data
* time - this module provides various time-related functions.
* shutil -  this module helps in automating process of copying and removal of files and directories.

These tools can be isntalled via the python PIP command 
pip install <COMPONENT NAME> or  pip install -r requirements.txt

#### Prerequisites
Python should have to be installed in the machine from where one need to run this tool

### How it works
* This is a three step process
   1) Run HL Scan and upload results - runs the source code analysis and uploads the result.
      * The utity uses the Highlight CLIs (HighlightAutomation.jar) to run the sscan and upload the reusults into mentioned Highlight instance.
         * Note : Always use the latest version of HighlightAutomation.jar downloading it from Highlight Instance https://rpa.casthighlight.com
      * All the required parameters to pass as an argument to the jar file can be configured in properties.json file, found under configuration folder.
   2) Genarte BOM in CycloneDX format - extacts the BOM report in cyclonedx format using a non public API.
      * Once the scan will be done it runs a non public API to generate the BOM
      * After generating the BOM it stores it in the location defined in properties.json file
   3) Parse response XML (BOM) and generate a new response file for HL Scan and relaunch the scan - Parses the BOM and extract the dependency information from there. Then injects the same for creating a new output file.
      1.Java Parser:- 
         * Once the BOM is been generated, the utility parses it and creates a dummy pom.xml file exracting the dependencies from BOM and placing the same in right tag inside of POM.xml.   
         * Then it saves the generated pom.xml in the source code location which is been picked up earlier for highlight scan.
         * It runs the HL scan again and repeats the same process i.e. generation of BOM, parsing it and creating a dummy pom.xml.
      2.DOT NET Parser:-
         * Once the BOM is been generated, the utility parses it and creates a dummy test.csproj file exracting the dependencies from BOM and placing the same in right tag inside of test.csproj.   
         * Then it saves the generated test.csproj in the source code location which is been picked up earlier for highlight scan.
         * It runs the HL scan again and repeats the same process i.e. generation of BOM, parsing it and creating a dummy test.csproj.
      3.Python Parser:-
         * Once the BOM is been generated, the utility parses it and creates a dummy app.py file exracting the packages from BOM and placing the same in right packages inside of app.py.   
         * Then it saves the generated app.py in the source code location which is been picked up earlier for highlight scan.
         * It runs the HL scan again and repeats the same process i.e. generation of BOM, parsing it and creating a dummy app.py.

   
Note : All the above steps runs in loop until these doesn't find any difference between previously analyzed and the latest output file or reaches the count of 100 loops which is the threshold.


