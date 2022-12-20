# Highlight BOM Dependency Tree
The script is used to generate a dependency tree of Components upto the last level  

## Installation
* Download and unpack the latest release of the dependency tree tool from https://github.com/BhanuPrakash2203/com.castsoftware.uc.hl.deptree
   
* Install/update required third party packages. 
    * Open a command prompt 
    * run: pip install -r requrements.txt   (requirements.txt file can be found inside configuration folder)
    * Run py UploadResults.py from command prompt

## Usage
The script is designed to run on the command line. It internally uses a properties.txt file for input parameters.

    py UploadResults.py 

# Properties file
The HL Dependency Tool is configured using a plain text file.  The file consists of various parameters which are required and need to be changed before running the tool.  
#### General Configuration
The general configuration section contains four parts,  
* hlJarPath - jar file of Higlight Automation (HighlightAutomation.jar)
* sourceDir - Path where source code is placed
* workingDir - Directory path where automations will do some intermediate activities
* analyzerDir - Path of the directory where Perl is installed
* companyId - Company ID of HIghlight Instance
* applicationId - Application ID of HIghlight Instance
* snapshotLabel - Provide the snapshot label, it can be any meaningful text
* serverUrl - Provide the HL server URL default is https://rpa.casthighlight.com/
* basicAuth - Base64 encoding of UserName:Password
* cyclodxOutput - Path to save the cyclonedx out xml file
* save_path_file - Path to save the intermediate POM file
* outputpom - Path to save the filtered POM file, this path should be in same as the source path which HL is going to consider for analysis

#### Tool Dependency file
This section contains a list of all the 3rd party dependencies which are used in the tool and need to be installed before running the tool,  
* subprocess - module allows you to spawn new processes
* requests - allows you to send HTTP requests using Python
* pandas - providing fast, flexible, and expressive data structures designed to make working with “relational” or “labeled” data both easy and intuitive
* xml -  for processing XML
* os - provides functions for interacting with the operating system
* re -  provides an interface to the regular expression engine
* lxml -  library for processing XML and HTML

These tools can be isntalled via the python PIP command 
pip install <COMPONENT NAME> or  pip install -r requrements.txt

#### Prerequisites
Python should have to be installed in the machine from where one need to run this tool

### How it works
* This is a three step process
   * Run HL Scan and upload results - runs the source code analysis and uploads the result.
      * The utity uses the Highlight CLIs (HighlightAutomation.jar) to run the sscan and upload the reusults into mentioned Highlight instance.
         * Note : Always use the latest version of HighlightAutomation.jar downloading it from Highlight Instance https://rpa.casthighlight.com
      * All the required parameters to pass as an argument to the jar file can be configured in properties.txt file, found under configuration folder.
   * Genarte BOM in CycloneDX format - extacts the BOM report in cyclonedx format using a non public API.
      * Once the scan will be done it runs a non public API to generate the BOM
      * After generating the BOM it stores it in the location defined in properties.txt file
   * Parse response XML (BOM) and generate a new pom.xml for HL Scan and relaunch the scan - Parses the BOM and extract the dependency information from there. Then          injects the same for creating a new POM.xml file.
      * Once the BOM is been generated, the utility parses it and creates a dummy pom.xml file exracting the dependencies from BOM and placing the same in right tag           inside of POM.xml   
      * Then it saves the generated pom.xml in the source code location which is been picked up earlier for highlight scan
      * It runs the HL scan again and repeats the same process i.e. generation of BOM, parsing it and creating a dummy pom.xml
   
Note : All the above steps runs in loop until these doesn't find any difference between previously analyzed and the latest pom.xml files or reaches the count of 100 loops which is the threshold.


