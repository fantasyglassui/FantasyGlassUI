# The plan page (<out>/plan/index.html): one page that reads a plan code in the browser and draws it.
# Built by every run of build_site.py, linked from Guide and Gold and listed in the sitemap (from 13.0).
# No counter, no network requests, no structured data; the font and every language are inline.
import json, os, re

S = os.path.dirname(os.path.abspath(__file__))
P = S + '/plan'


def build(out_dir):
    page = open(P + '/page.html', encoding='utf-8').read()
    reader = open(P + '/reader.js', encoding='utf-8').read()
    words = json.load(open(P + '/words.json', encoding='utf-8'))
    font = open(S + '/site/marcellus.b64').read().strip()
    blob = json.dumps(words, ensure_ascii=False, separators=(',', ':')).replace('</', '<\\/')
    page = page.replace('@@FONT@@', font).replace('/*@WORDS@*/', blob).replace('/*@READER@*/', reader.replace('</', '<\\/'))
    html = ('<!doctype html>\n<html lang="en" data-theme="dark">\n<head>\n<meta charset="utf-8">\n'
            '<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">\n'
            '<meta name="description" content="Paste a plan code from Fantasy Glass UI and follow the route on any screen, a phone too. Nothing leaves your browser.">\n'
            '<meta name="referrer" content="no-referrer">\n'
            '<title>Your route · Fantasy Glass UI</title>\n</head>\n<body>\n' + page + '</body>\n</html>\n')
    assert re.search(r'\bfetch\(|XMLHttpRequest|sendBeacon|WebSocket|<script src|<link|https?://', html) is None
    os.makedirs(out_dir + '/plan', exist_ok=True)
    open(out_dir + '/plan/index.html', 'w', encoding='utf-8').write(html)


if __name__ == '__main__':
    import sys
    build(sys.argv[1])
