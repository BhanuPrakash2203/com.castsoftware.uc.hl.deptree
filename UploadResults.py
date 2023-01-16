import json
from subprocess import *
import subprocess
from requests import codes
from pandas import DataFrame
from pandas import json_normalize
from pandas import concat
import requests
import time 
import xml.etree.ElementTree as ET
import xml.dom.minidom
from xml.dom import minidom
import os
import re
from lxml import etree
import shutil

class UploadResults():
    
    # Routine 1 : Runs the HL analysis using highlight automation jar file
    def runHLAnalysis(self,*args):
        process = Popen(['java', '-jar']+list(args), stdout=PIPE, stderr=PIPE)
        ret = []
        while process.poll() is None:
            line = process.stdout.readline()
            print(line)
            if line != '' and line.endswith(b'\n'):
                ret.append(line[:-1])
        stdout, stderr = process.communicate()
        ret += str(stdout).split('\n')
        if stderr != b'':
            ret += str(stderr).split('\n')
        #ret.remove(b'')
        return ret
    
    #WIP - Will be used for validating if scan is completed successfully
    def checkScan(self,appl_id):
        url = f'domains/{self._hl_instance}/applications/{appl_id}/results'
        (status, json) = self.get(url)
        if status == codes.ok and len(json) > 0:
            return json
        else:
            raise KeyError (f'Applications not found')
    
    #WIP - Will be used for validating if scan is SCA is ready
    def checkSCA(self,appl_id):
        url = f'domains/{self._hl_instance}/applications/{appl_id}/results'
        (status, json) = self.get(url)
        if status == codes.ok and len(json) > 0:
            return json
        else:
            raise KeyError (f'No applications found')
    
    #Routine 2 - Used to initiate the BOM request using the highlight instance
    def generateBOMRequest(self,appID,compID,basicAuth,cycloneDXPath):
        time.sleep(120)
        data={"selector": {"applications": [appID]}, "reportConfig": ["SendMail","DependenciesAndCve"]}
        print(data)
        headers={"Accept": "application/octet-stream", "Content-Type":"application/json", "Authorization": f"Basic {basicAuth}"}
        print(headers)
        response=requests.post(f'https://rpa.casthighlight.com/WS/export/BOM/CycloneDX?companySwitch={compID}&lastResult=true', json=data, headers=headers)
        print(response)
        print(response.headers)
        apiResponse=response.headers
        responseHeader=apiResponse.get('Location')
        print(responseHeader)
        if response.status_code==202:
            self.generateBOM(responseHeader,basicAuth,cycloneDXPath)

    #Routine 3 - Used to generate the BOM in CycloneDX format (response.xml)
    def generateBOM(self,respHead,basicAuth,cycloneDXPath):
        iStatus=404
        iRetry=0
        while iStatus==404 and iRetry < 10*6:
            time.sleep(10)
            headers={"Authorization": f"Basic {basicAuth}"}
            response=requests.get(respHead, headers=headers)
            iStatus=response.status_code
            iRetry=iRetry+1
        sDownloadStatus=response.status_code
        if sDownloadStatus==200:
            #print(response.text)
            with open(cycloneDXPath, "w+") as f:
                f.write(response.text)
    
    #Routine 4 - XML Parser used to parse cyclonedx output and extract the dependecnies from these and generate a new POM.XML file
    # Note : This parser only works for generating pom.xml
    def xmlParsing(self,cycloneDXOutput,save_path_file,outputPOM,newOutputFolder):
        #mytree = ET.parse('C:\\DATA\\GITRepo\\com.castsoftware.uc.hl.dt\\response.xml',parser = ET.XMLParser(encoding = 'iso-8859-5'))
        
        # Start creating new pom.xml file
        mytree = ET.parse(cycloneDXOutput,parser = ET.XMLParser(encoding = 'iso-8859-5'))
        myroot = mytree.getroot()
        
        root = minidom.Document()
        
        # ADD elements and attributes in xml file
        project=root.createElement('project')
        root.appendChild(project)
        project.setAttribute('xmlns','http://maven.apache.org/POM/4.0.0')
        project.setAttribute('xmlns:xsi','http://www.w3.org/2001/XMLSchema-instance')
        project.setAttribute('xsi:schemaLocation','http://maven.apache.org/POM/4.0.0 http://maven.apache.org/xsd/maven-4.0.0.xsd')
        
        modelVersion=root.createElement('modelVersion')
        modelText=root.createTextNode('4.0.0')
        project.appendChild(modelVersion)
        modelVersion.appendChild(modelText)

        xml = root.createElement('dependencies') 
        project.appendChild(xml)

        #Reads cyclonedx output extract element values and place those in right location
        for dep in myroot.iter('{http://cyclonedx.org/schema/bom/1.3}dependency'):
            components=dep.get('ref')
            print(dep.get('ref'))
            
            depsChild = root.createElement('dependency')
            xml.appendChild(depsChild)
            
            #Extract group ID
            groupID = root.createElement('groupId')
            textgroupID=root.createTextNode(components.partition(':')[0])
            #textgroupID=root.createTextNode(components)
            depsChild.appendChild(groupID)
            groupID.appendChild(textgroupID)
            
            #Extract Artifact ID i.e. the name of component
            artifactId=root.createElement('artifactId')
            textartifactId=root.createTextNode(components.partition(':')[2].partition('@')[0])
            #textartifactId=root.createTextNode(components)
            depsChild.appendChild(artifactId)
            artifactId.appendChild(textartifactId)

            #Extract component's version
            version=root.createElement('version')
            textversion=root.createTextNode(components.partition(':')[2].partition('@')[2])
            #textversion=root.createTextNode(components)
            depsChild.appendChild(version)
            version.appendChild(textversion)

        #Make XML out of the extracted information
        xml_str = root.toprettyxml(indent ="\t") 
        
        #Create a new directory inside source directory to place newly generated pom.xml
        if not os.path.exists(newOutputFolder):
            # if the demo_folder directory is not present 
            # then create it.
            os.makedirs(newOutputFolder)
        outPath=os.listdir(newOutputFolder)

        #Copy the pom.xml file in the new directory inside source location    
        if len(outPath)==0:
            shutil.copy(outputPOM,newOutputFolder)
        
        #Read the file
        with open(save_path_file, "w+") as f:
            f.write(xml_str) 
        
        #Remove duplicate elements from the file
        self.removeDuplicateTags(save_path_file,newOutputFolder)

    #Routine 5 - This routine will delete the duplicate elements from the newly generate xml        
    def removeDuplicateTags(self,save_path_file,outputPOM):
        
        outputPOM=outputPOM+'\pom.xml'
        file = open(outputPOM, "r")
        #read content of file to string
        data = file.read()
        #get number of occurrences of the substring in the string
        global occurrences_previous
        occurrences_previous = data.count("<dependency>")   

        unique_tag_list=[]
        unwanted_tag_list=[]
        tag_list_1=[]
        tag_list_2=[]
        tag_list_3=['\n\t</dependencies>\n','</project>']

        #extrating required data from xml using regex
        with open(save_path_file, 'r') as f:
            content = f.read()

            #
            tag_pattern_1='(<\?xml (?:.|\n)+?.*<dependencies>)'
            tag_list_1=re.findall(tag_pattern_1,content)

            #extracting all the dependencies 
            tag_pattern_2='(<dependency>(?:.|\n)+?.*</dependency>)'
            tag_list_2=re.findall(tag_pattern_2,content)

            if len(tag_list_2)>0:
                for tag in tag_list_2:
                    if tag not in unique_tag_list:
                        #storing unqing dependencies to unique_tag_list
                        unique_tag_list.append(tag)
                    else:
                        unwanted_tag_list.append(tag)

        for i in range(len(unique_tag_list)):
            unique_tag_list[i]='\n\t\t'+unique_tag_list[i]

        #Combining all the data together
        tag_list_1.extend(unique_tag_list)
        tag_list_1.extend(tag_list_3)

        
        #writing combined data together to a output xml file
        with open(outputPOM, "w+") as f2:
            for i in tag_list_1:
                f2.write(i)
        file = open(outputPOM, "r")
        #read content of file to string
        data = file.read()
        #get number of occurrences of the substring in the string
        global occurrences_latest
        occurrences_latest = data.count("<dependency>")   


# -------------------START PROGRAM----------------------------------------------------------
print('\nCAST HL Scan - Version 1.0')
print('Copyright (c) 2022 CAST Software Inc.\n')
print('If you need assistance, please contact Bhanu Prakash (BBA) from the CAST IN PS team\n')

 
#HL Command line parameters
#Extract parameters from properties.json file
dirname = os.path.dirname(__file__)
properties_file=dirname+'\\Configuration\\properties.json'

with open(properties_file, 'r') as f:
  data = json.load(f)

hlJarPath=data["hlJarPath"] #Location of highlight automation jar file
sourceDir=data["sourceDir"] #Location of source directory
workingDir=data["workingDir"] #Location of highlight working directory
analyzerDir=data["analyzerDir"] #Location of highlight analyze directory
companyId=data["companyId"] #Company ID
applicationId=data["applicationId"] #Application ID
snapshotLabel=data["snapshotLabel"] #Highlight Snapshot label
serverUrl=data["serverUrl"] #Highlight instance URL
basicAuth=data["basicAuth"] #Basic authentication combination of user_name:password
cycloneDXOutput=data["cyclodxOutput"] #Location of generated cycloneDX file
save_path_file=data["save_path_file"] #Location newly generated pom file
outputPOM=data["outputpom"] #Intermediate Location of pom.xml file having duplicate tags removed
newOutputFolder=data["newOutputFolder"] #New folder inside source code where newly generated pom.xml will be saved

#Validation of parameters
if hlJarPath=='' or str(hlJarPath).isspace():
    print('HL Aoutmation JAR path is not defined')
    exit()
if not os.path.exists(hlJarPath):  
    print('HL Aoutmation JAR path does not exist')
    exit()
if not hlJarPath.endswith('.jar'):
    print('HL Aoutmation JAR file does not exist')
    exit()

if sourceDir=='' or str(sourceDir).isspace():
    print('Source Directory path is not defined')
    exit()
if not os.path.exists(sourceDir):  
    print('Source Directory path does not exist')
    exit()
if not os.listdir(sourceDir):
    print('Source Directory is empty')
    exit()
    

if workingDir=='' or str(workingDir).isspace():
    print('Working Directory path is not defined')
    exit()
if not os.path.exists(workingDir):  
    print('Working Directory does not exist')
    exit()


if analyzerDir=='' or str(analyzerDir).isspace():
    print('Analyze Directory path is not defined')
    exit()
if not os.path.exists(analyzerDir):  
    print('Analyze Directory does not exist')
    exit()

flag=0
for subdir, dirs, files in os.walk(analyzerDir):
    for file in files:
        if file.endswith('.pm'):
            flag=1
            break
if flag==0:
    print('Analyze Directory does not contain perl libraries')
    exit()


if companyId=='' or str(companyId).isspace():
    print('Company ID is not defined')
    exit()
if not companyId.isnumeric():
    print('Company ID is not a numeric value')
    exit()


if applicationId=='' or str(applicationId).isspace():
    print('Application ID is not defined')
    exit()
if not applicationId.isnumeric():
    print('Application ID is not a numeric value')
    exit()


if snapshotLabel=='' or str(snapshotLabel).isspace():
    print('Snapshot Lable is not defined')
    exit()


if serverUrl=='' or str(serverUrl).isspace():
    print('Highlight Instance Server URL is not defined')
    exit()


if basicAuth=='' or str(basicAuth).isspace():
    print('Basic Authentication(UserID:Password) is not defined')
    exit()


if cycloneDXOutput=='' or str(cycloneDXOutput).isspace():
    print('Output CycloneDX path is not defined')
    exit()
if not os.path.exists(cycloneDXOutput):  
    print('Output CycloneDX path does not exist')
    exit()
if cycloneDXOutput==sourceDir:
    print('cycloneDXOutput path and sourceDir path should not be the same')
    exit()


if save_path_file=='' or str(save_path_file).isspace():
    print('Parsed POM.xml path is not defined')
    exit()
if not os.path.exists(save_path_file):  
    print('save_path_file path does not exist')
    exit()  
if save_path_file==sourceDir:
    print('save_path_file path and sourceDir path should not be the same')
    exit()         


if outputPOM=='' or str(outputPOM).isspace():
    print('Output POM location is not defined')
    exit()   
if not os.path.exists(outputPOM):  
    print('outputPOM path does not exist')
    exit()
flag=0
for subdir, dirs, files in os.walk(outputPOM):
    for file in files:
        if file=='pom.xml':
            flag=1
            break
if flag==0:
    print('outputPOM path does not contain pom.xml file')
    exit()            


if newOutputFolder=='' or str(newOutputFolder).isspace():
    print('New output POM directory path is not defined')
    exit()
if not os.path.exists(newOutputFolder):  
    print('New output POM directory path does not exist')
    print('Creating '+newOutputFolder)
    os.makedirs(newOutputFolder)



#Arguments to be passed in HighlightAutomation JAR (Routine 1) 
args = [f'{hlJarPath}', '--sourceDir', f'{sourceDir}', '--workingDir' , f'{workingDir}', '--analyzerDir', f'{analyzerDir}', '--companyId', f'{companyId}', '--applicationId', f'{applicationId}', '--snapshotLabel', f'{snapshotLabel}', '--basicAuth', f'{basicAuth}', '--serverUrl', f'{serverUrl}'] # Any number of args to be passed to the jar file

#Number of <dependency> tags pereviously and in latest POM XML
occurrences_previous=0
occurrences_latest=0

#Instantiating main class 
obj=UploadResults()

#Iteration exit criteria
# Criteria 1 - If Previous occurrences of tags are equal to latest occurrences
# Criteria 2 - If occurrences reach 100
for iter in range(100):
    if occurrences_previous!=occurrences_latest or occurrences_previous==0:    
        #1. Run HL Scan and upload results
        try:
            result = obj.runHLAnalysis(*args)
            print(result)
        except:
            print('Error occurred during Highlight scan')
            exit()

        #2. Genarte BOM in Cyclone DX format
        try:
            obj.generateBOMRequest(applicationId,companyId,basicAuth,cycloneDXOutput+'\\response.xml')
        except:
            print('Error occurred during generating BOM')
            exit()

        #3. Parse response XML (BOM) and generate a new pom.xml for HL Scan and relaunch the scan
        try:
            obj.xmlParsing(cycloneDXOutput+'\\response.xml',save_path_file+'\\response_pom.xml',outputPOM+'\\pom.xml',newOutputFolder)
        except:
            print('Error occurred during Parsing BOM')
            exit()
    else:
        #Remove intermediate cyclonedx output file
        if os.path.exists(cycloneDXOutput):
            for subdir, dirs, files in os.walk(cycloneDXOutput):
                for file in files:
                    if file.endswith('response.xml'):
                        os.remove(file)

        #Remove intermediate POM file
        if os.path.exists(save_path_file):
            for subdir, dirs, files in os.walk(cycloneDXOutput):
                for file in files:
                    if file.endswith('response_pom.xml'):
                        os.remove(file)

        exit()