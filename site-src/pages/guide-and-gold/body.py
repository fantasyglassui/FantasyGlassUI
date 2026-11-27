# Guide and Gold (W3): body.html, with two things filled in at build time (see site-src/PAGES.md):
#
#   the example route   the first "ok" plan code in tests/plan_codes.txt (the add-on's own test reads the same
#                       file), drawn in the browser by the plan page's own reader (site-src/plan/reader.js),
#                       which extra() serves at /assets/plan-reader.js; script.js draws it zone by zone.
#   the short tour      plain HTML in body.html (the steps in a hidden list); script.js runs it.
import hashlib, html, os, urllib.parse

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.normpath(HERE + '/../..')
REPO = os.path.normpath(SRC + '/..')
READER = SRC + '/plan/reader.js'


def example_code():
    own = os.path.join(HERE, 'example_code.txt')       # (a hand-picked example from a real zone, when there is one)
    if os.path.exists(own): return open(own, encoding='utf-8').read().strip()
    for line in open(REPO + '/tests/plan_codes.txt', encoding='utf-8').read().splitlines():
        f = line.split('\t')
        if f[0] == 'ok' and len(f) > 5: return f[5]
    raise SystemExit('guide-and-gold: no "ok" plan code in tests/plan_codes.txt for the example route')


def _attr(t):
    # an attribute's value; braces and brackets written as entities, since the build reads {{ }} and [[ ]] as its own
    return html.escape(t, quote=True).replace('{', '&#123;').replace('}', '&#125;').replace('[', '&#91;').replace(']', '&#93;')


def _reader():
    return open(READER, encoding='utf-8').read()


def body(ctx):
    code = example_code()
    reader = '/assets/plan-reader.js?v=' + hashlib.sha1(_reader().encode('utf-8')).hexdigest()[:10]
    return (open(HERE + '/body.html', encoding='utf-8').read()
            .replace('@@EXAMPLE_CODE@@', _attr(code))
            .replace('@@EXAMPLE_LINK@@', '/plan/#c=' + urllib.parse.quote(code, safe=''))
            .replace('@@READER@@', reader))


def extra(out_dir, values):
    # the plan page's reader, as a file of its own for this page (the plan page keeps its inline copy)
    os.makedirs(out_dir + '/assets', exist_ok=True)
    open(out_dir + '/assets/plan-reader.js', 'w', encoding='utf-8').write(_reader())
