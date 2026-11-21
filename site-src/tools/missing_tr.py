import re,json,sys
loc=open('FantasyGlassUI_Locales/Locales.lua',encoding='utf-8').read()
at=loc.index('ns.locales.deDE = {'); end=loc.index('\n}',at)
have=set(re.findall(r'^    \["((?:[^"\\]|\\.)*)"\]',loc[at:end],re.M))
files=sys.argv[1:]
lit=r'"((?:[^"\\]|\\.)*)"'
pats=[r'ns:Tr\(\s*'+lit, r'ns:TrN\([^,]+,\s*'+lit+r'\s*,\s*'+lit, r'CreateButton\([^,]+,\s*'+lit, r'CreateCheckbox\([^,]+,\s*'+lit, r'CreateSlider\([^,]+,\s*'+lit,
      r'CreateEditBox\([^,]+,[^,]+,[^,]+,\s*'+lit, r'O\.Tip\([^,]+,\s*'+lit+r'(?:\s*,\s*'+lit+')?', r'\b(?:label|desc|title|note|hint|chooseLabel)\s*=\s*'+lit, r'Head\(\s*'+lit, r'Header\([^,]+,\s*'+lit,r'Heading\([^,]+,\s*'+lit,
      r'(?:and|or)\s+'+lit]
out=[]
for f in files:
    s=open(f,encoding='utf-8').read()
    for p in pats:
        for m in re.finditer(p,s):
            for g in m.groups():
                if g and re.search(r'[a-z]{2,}',g) and g not in have and g not in out: out.append(g)
for o in out: print(o)
