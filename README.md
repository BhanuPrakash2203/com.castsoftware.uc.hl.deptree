# Highlight BOM Dependency Tree
The script is used to generate a dependency of Components upto the last level  

## Installation
* Download and unpack the latest release of the dependency tree tool from https://github.com/BhanuPrakash2203/com.castsoftware.uc.hl.deptree
   
* Unpack the Source Code zip file (arg)
* Unpack the com.castsoftware.uc.python.common.zip into a separate folder
* Install/update required third party packages. 
    * Open a command prompt 
    * run: pip install -r requrements.txt
    * Run py UploadResults.py from command prompt

## Usage
The script is designed to run on the command line. It internally uses a properties.txt file for input parameters.

    py UploadResults.py 

# Properties file
The Assessment Deck Generation Tool is configured using a plain test file.  The file is consists of various parameters which are required and need to be changed before running the tool.  
#### General Configuration
The general configuration section contains four parts,  
* hlJarPath - jar file of Higlight Automation (HighlightAutomation.jar)
* workingDir - Directory path where automations will do some intermediate activities
* analyzerDir - Path of the directory where Perl is installed
* companyId - Company ID of HIghlight Instance
* applicationId - Application ID of HIghlight Instance

#### Application list
This section contains a list of all applications that will be used in the report.  It is divided into three parts,  
* aip - the application schema triplet base
* highlight - the name of the application as it appears in the Highlight portal
* title - the name of the application to be used in the report

aip is the only required in this section.  If Highlight or title are empty or left out the aip value will be used.

#### REST Configuration
The REST configuration is divided into two parts, AIP and Highlight.  Both configurations contain 
* Active - toggle to turn REST service on/off
* URL - the service base URL 
* user - login user id
* password - login password (non-encrypted)

The Highlight configuration contains an additional field, instance, which refers to the login instance id.

#### Sample configuration

    {
        "company":"MMA Company Name",
        "project":"Project Name",
        "template":"C:/com.castsoftware.uc.arg/Template.pptx",
        "output":"C:/output/folder",
        "application":[
            {
                "aip":"triplet_base_name",
                "highlight":"highlight_name",
                "title":"application title"
            },
            {
                "aip":"triplet_base_name",
                "highlight":"highlight_name",
                "title":"application title"
            }, ...
        ],
        "rest":{
            "AIP":{
                "Active":true,
                "URL":"http://<URL>:<Port>/rest/",
                "user":"user_name",
                "password":"user_pasword"
            },
            "Highlight":{
                "Active":true,
                "URL":"https://<URL>/WS2/",
                "user":"user_name",
                "password":"user_pasword",
                "instance":"instance id"
            }
        }
    }


### Output
A single PowerPoint deck and one excel spread sheet is generated for each application configured in the properties file. The Deck is organized with an executive summary, one section per application containing detailed information and an appendix.  The excel sheets are hold the application action plan information and divided into two tabs, summary, and detail.  In the event an action plan is not configured, for the application, the sheets will be empty.    

This version of the script focus on CAST AIP content but not formatting.  For example, the executive summary section currently has a bullet point for only the first application.  This section concentrates on what manual formatting is required to make the deck client ready.  

#### <ins>Manual Formatting Required</ins>
The current version of this script only includes CAST AIP.  All items related to Open Source and Appmarq must be manually added.  This shortfall will be addressed in future releases. 

The following is a list of all known formatting issues:  

| Template Section | Issue | Workaround |
| -----------------| ----- | ---------- |
| Executive Summary | In the first paragraph, the number of applications is currently hard coded to “two”.  | Update his information manually. |
| Executive Summary | When generating a document containing more than one application the bullet points do not extend past the first application. | Use the paintbrush on the first bullet point to format the remaining applications. |
| Executive Summary | When generating a document containing more than one application the text is overrunning the page  | Select the textbox, right click the mouse, and select “Format Shape”.  In the “Text Options” tab and click on Textbox option.  Finally click on the “Shrink text on overflow” option. |
| Application Health | The second and third bullet points are not including grade improvements.  | Get the grade improvement scores from Action Plan Optimizer.  |
| Appendix | The appendix is not being included  | Manually insert the appendix from the appendix deck found in teams |


