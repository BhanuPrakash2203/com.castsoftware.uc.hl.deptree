from logging import DEBUG, info, warn
from logger import Logger
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

class UploadResults():

    def jarWrapper(self,*args):
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

    def checkScan(self,appl_id):
        url = f'domains/{self._hl_instance}/applications/{appl_id}/results'
        (status, json) = self.get(url)
        if status == codes.ok and len(json) > 0:
            return json
        else:
            raise KeyError (f'No applications not found')
    
    def checkSCA(self,appl_id):
        url = f'domains/{self._hl_instance}/applications/{appl_id}/results'
        (status, json) = self.get(url)
        if status == codes.ok and len(json) > 0:
            return json
        else:
            raise KeyError (f'No applications found')

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
            with open(cycloneDXPath, "w") as f:
                f.write(response.text)
    
    def xmlParsing(self,cycloneDXOutput,save_path_file,outputPOM):
        #mytree = ET.parse('C:\\DATA\\GITRepo\\com.castsoftware.uc.hl.dt\\response.xml',parser = ET.XMLParser(encoding = 'iso-8859-5'))
        mytree = ET.parse(cycloneDXOutput,parser = ET.XMLParser(encoding = 'iso-8859-5'))
        myroot = mytree.getroot()
        
        root = minidom.Document()
        
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

        for dep in myroot.iter('{http://cyclonedx.org/schema/bom/1.3}dependency'):
            components=dep.get('ref')
            print(dep.get('ref'))
            
            depsChild = root.createElement('dependency')
            xml.appendChild(depsChild)
            
            groupID = root.createElement('groupId')
            textgroupID=root.createTextNode(components.partition(':')[0])
            #textgroupID=root.createTextNode(components)
            depsChild.appendChild(groupID)
            groupID.appendChild(textgroupID)
            

            artifactId=root.createElement('artifactId')
            textartifactId=root.createTextNode(components.partition(':')[2].partition('@')[0])
            #textartifactId=root.createTextNode(components)
            depsChild.appendChild(artifactId)
            artifactId.appendChild(textartifactId)

            version=root.createElement('version')
            textversion=root.createTextNode(components.partition(':')[2].partition('@')[2])
            #textversion=root.createTextNode(components)
            depsChild.appendChild(version)
            version.appendChild(textversion)


        xml_str = root.toprettyxml(indent ="\t") 
        
        
        with open(save_path_file, "w") as f:
            f.write(xml_str) 
        
        self.removeDuplicateTags(save_path_file,outputPOM)
            
    def removeDuplicateTags(self,save_path_file,outputPOM):
        
        
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

        #combinig all the data together
        tag_list_1.extend(unique_tag_list)
        tag_list_1.extend(tag_list_3)

        #writing combined data together to a output xml file
        with open(outputPOM, "w") as f2:
            for i in tag_list_1:
                f2.write(i)
        file = open(outputPOM, "r")
        #read content of file to string
        data = file.read()
        #get number of occurrences of the substring in the string
        global occurrences_latest
        occurrences_latest = data.count("<dependency>")   

print('\nCAST HL Scan')
print('Copyright (c) 2022 CAST Software Inc.\n')
print('If you need assistance, please contact Bhanu Prakash (BBA) from the CAST IN PS team\n')

 
#HL Command line parameters
#extract parameters from properties.txt file
dirname = os.path.dirname(__file__)
properties_file=dirname+'\\Configuration\\Properties.txt'
with open(properties_file,'r') as f:
    path_list = f.read().split('\n')
    hlJarPath=path_list[0].strip()
    sourceDir=path_list[1].strip()
    workingDir=path_list[2].strip()
    analyzerDir=path_list[3].strip()
    companyId=path_list[4].strip()
    applicationId=path_list[5].strip()
    snapshotLabel=path_list[6].strip()
    serverUrl=path_list[7].strip()
    basicAuth=path_list[8].strip()
    cycloneDXOutput=path_list[9].strip()
    save_path_file=path_list[10].strip()
    outputPOM=path_list[11].strip()

hlJarPath=hlJarPath.split('=')
hlJarPath=hlJarPath[1]

sourceDir=sourceDir.split('=')
sourceDir=sourceDir[1]

workingDir=workingDir.split('=')
workingDir=workingDir[1]

analyzerDir=analyzerDir.split('=')
analyzerDir=analyzerDir[1]

companyId=companyId.split('=')
companyId=companyId[1]

applicationId=applicationId.split('=')
applicationId=applicationId[1]

snapshotLabel=snapshotLabel.split('=')
snapshotLabel=snapshotLabel[1]

serverUrl=serverUrl.split('=')
serverUrl=serverUrl[1]

basicAuth=basicAuth.split('=')
basicAuth=basicAuth[1]

cycloneDXOutput=cycloneDXOutput.split('=')
cycloneDXOutput=cycloneDXOutput[1]

save_path_file=save_path_file.split('=')
save_path_file=save_path_file[1]

outputPOM=outputPOM.split('=')
outputPOM=outputPOM[1]

#Arguments to pass in HighlightAutomation 
args = [f'{hlJarPath}', '--sourceDir', f'{sourceDir}', '--workingDir' , f'{workingDir}', '--analyzerDir', f'{analyzerDir}', '--companyId', f'{companyId}', '--applicationId', f'{applicationId}', '--snapshotLabel', f'{snapshotLabel}', '--basicAuth', f'{basicAuth}', '--serverUrl', f'{serverUrl}'] # Any number of args to be passed to the jar file

occurrences_previous=0
occurrences_latest=0
obj=UploadResults()
for iter in range(100):
    if occurrences_previous!=occurrences_latest or occurrences_previous==0:    
        #1. Run HL Scan and upload results
        result = obj.jarWrapper(*args)
        print(result)

        #2. Genarte BOM in Cyclone DX format
        obj.generateBOMRequest(applicationId,companyId,basicAuth,cycloneDXOutput)

        #3. Parse response XML (BOM) and generate a new pom.xml for HL Scan and relaunch the scan
        obj.xmlParsing(cycloneDXOutput,save_path_file,outputPOM)
    else:
        exit
    
