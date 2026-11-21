import re,json
import os
S=os.path.dirname(os.path.abspath(__file__))+'/'
s=open(S+'site/script.html').read()
dyn=set(re.findall(r'\b[LF]\("((?:[^"\\]|\\.)*)"',s))
about=re.search(r'var about = \{(.*?)\}\[t\.f\]',s).group(1); dyn|=set(re.findall(r': "([^"]+)"',about))
for m in re.finditer(r'\["[a-z-]+", "([^"]+)", "([^"]+)"\]',s): dyn|={m.group(1),m.group(2)}
dyn|={"All","Glass","Fantasy","Celestial","Search the switches, for example: loot, nameplate, threat","Search the commands"}
st=json.load(open(S+'keys_static.json'))
json.dump([k for k in st]+sorted(dyn-set(st)),open(S+'keys_all.json','w'),indent=1,ensure_ascii=False)
