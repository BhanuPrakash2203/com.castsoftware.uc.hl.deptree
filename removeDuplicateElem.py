import xml.etree.ElementTree as ET

path = "C:\\DATA\\GITRepo\\com.castsoftware.uc.hl.dt\\response_pom.xml"

tree = ET.parse(path)
root = tree.getroot()
prev = None

def elements_equal(e1, e2):
    if type(e1) != type(e2):
        return False
    if e1.tag != e2.tag: return False
    if e1.text != e2.text: return False
    if e1.tail != e2.tail: return False
    if e1.attrib != e2.attrib: return False
    if len(e1) != len(e2): return False
    return all([elements_equal(c1, c2) for c1, c2 in zip(e1, e2)])

for page in root:                     # iterate over pages
    elems_to_remove = []
    for elem in page:
        if elements_equal(elem, prev):
            print("found duplicate: %s" % elem.text)   # equal function works well
            elems_to_remove.append(elem)
            continue
        prev = elem
    for elem_to_remove in elems_to_remove:
        page.remove(elem_to_remove)
# [...]
tree.write("C:\\DATA\\GITRepo\\com.castsoftware.uc.hl.dt\\out_pom.xml")