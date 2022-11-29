import xml.etree.ElementTree as ET    
import re

path = "C:\\DATA\\GITRepo\\com.castsoftware.uc.hl.dt\\response_pom.xml"

unique_tag_list=[]
unwanted_tag_list=[]
tag_list_1=[]
tag_list_2=[]
tag_list_3=['\n\t<dependencies>\n','</project>']

#extrating required data from xml using regex
with open(path, 'r') as f:
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
with open("C:\\DATA\\GITRepo\\com.castsoftware.uc.hl.dt\\out.xml", "w") as f2:
    for i in tag_list_1:
        f2.write(i)