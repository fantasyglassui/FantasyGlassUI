import re, subprocess
rc = open('.luacheckrc').read()
a = rc.index('read_globals = {'); b = rc.index('\n}', a)
old = set(re.findall(r'"([^"]+)"', rc[a:b]))
import tempfile
T=tempfile.mkdtemp()+'/rc_tmp'
open(T, 'w').write(rc[:a] + 'read_globals = {}\n' + rc[b+2:])
out = subprocess.run(['luacheck', '.', '--config', T, '--formatter', 'plain', '--codes', '--no-color', '-q'], capture_output=True, text=True).stdout
new = set(re.findall(r"\(W113\) accessing undefined variable '([^']+)'", out))
print('removed:', sorted(old - new)); print('added:', sorted(new - old))
open('.luacheckrc', 'w').write(rc[:a] + 'read_globals = {\n' + '\n'.join(f'    "{n}",' for n in sorted(new)) + '\n}' + rc[b+2:])
