from lxml import objectify
import pandas as pd
xml1 = objectify.parse(open("C:\\DATA\\GITRepo\\com.castsoftware.uc.hl.dt\\response_pom.xml"))
root = xml1.getroot()
print(root)
print(root.getchildren()[1].getchildren())
f=pd.DataFrame(columns=('String','String','String'))
for i in range(0,4):
    obj=root.getchildren()[i].getchildern()
    row=dict(zip('String','String','String'),[obj[0].text,obj[1].text,obj[2].text])
    row_s=pd.Series(row)
    row_s.name=i
    df=df.append(row_s)
print(df)    