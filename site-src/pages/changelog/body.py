# The Changelog page's body (W3 adds 13.0 by adding it to CHANGELOG.md): every release in the repository's
# CHANGELOG.md, newest first, with a search. The changes themselves are in English in every language.
# The build calls body(ctx); see site-src/PAGES.md.
import html, re


def inline(t):
    t = html.escape(t, quote=False)
    t = re.sub(r'`([^`]+)`', r'<code>\1</code>', t)
    t = re.sub(r'\*\*(.+?)\*\*', r'<b>\1</b>', t)
    t = re.sub(r'\[([^\]]+)\]\((https?://[^)\s]+)\)', r'<a href="\2">\1</a>', t)
    return t


# bullets nest by depth (two spaces a level)
def ul(items):
    h, stack = [], []
    for d, t in items:
        d = min(d, len(stack))                       # (no jumping two levels at once)
        while len(stack) > d + 1: h.append('</li></ul>'); stack.pop()
        if len(stack) == d + 1: h.append('</li>')
        else: h.append('<ul>'); stack.append(d)
        h.append('<li>' + inline(t))
    while stack: h.append('</li></ul>'); stack.pop()
    return ''.join(h)


def _body(ls):
    out, para, items = [], [], []
    def fp():
        if para: out.append('<p>' + inline(' '.join(para)) + '</p>'); para.clear()
    def fi():
        if items: out.append(ul(items)); items.clear()
    for ln in ls:
        if not ln.strip(): fp(); continue
        m = re.match(r'^( *)- (.*)$', ln)
        if m: fp(); items.append([len(m.group(1)) // 2, m.group(2)]); continue
        if items and ln.startswith(' '): items[-1][1] += ' ' + ln.strip(); continue
        sub = re.match(r'^\*\*(.+)\*\*\s*$', ln)
        if sub and '**' not in sub.group(1):
            fp(); fi(); out.append('<h3>' + inline(sub.group(1)) + '</h3>'); continue
        fi(); para.append(ln.strip())
    fp(); fi()
    return '\n'.join(out)


def _safe(t):
    # the build reads double square brackets and double braces as its own markers; in the changelog they are only brackets
    return t.replace('[', '&#91;').replace(']', '&#93;').replace('{', '&#123;').replace('}', '&#125;')


def body(ctx):
    lines = open(ctx.repo + '/CHANGELOG.md', encoding='utf-8').read().split('\n')
    intro, versions, cur = [], [], None
    for ln in lines:
        if ln.startswith('# '): continue
        m = re.match(r'^## (\S+)\s*$', ln)
        if m:
            cur = {'v': m.group(1), 'lines': []}; versions.append(cur); continue
        (cur['lines'] if cur else intro).append(ln)
    anchor = lambda v: 'v' + v.replace('.', '-')
    en = '' if ctx.lang == 'en' else ' lang="en"'           # (the changes are written in English)
    chips = ''.join(f'<a href="#{anchor(x["v"])}">{x["v"]}</a>' for x in versions)
    secs = []
    for i, x in enumerate(versions):
        badge = ' <span class="now">[[Current]]</span>' if i == 0 else ''
        first = ' <span class="first">[[First release]]</span>' if i == len(versions) - 1 else ''
        secs.append(f'<section class="ver card" id="{anchor(x["v"])}" data-v="{x["v"]}" aria-labelledby="h-{anchor(x["v"])}">\n'
                    f'<h2 id="h-{anchor(x["v"])}"><a href="#{anchor(x["v"])}">{x["v"]}</a>{badge}{first}</h2>\n<div{en}>{_safe(_body(x["lines"]))}</div>\n</section>')
    note = '' if ctx.lang == 'en' else '<p class="faint">[[This page is in English for now.]]</p>'
    return f'''<!-- Changelog (W3). Built from CHANGELOG.md by pages/changelog/body.py; see site-src/PAGES.md. -->
<div class="wrap narrow page-head">
  <h1>[[Changelog]]</h1>
  <div class="intro"{en}>{_safe(_body(intro))}</div>
  {note}
  {{{{status}}}}
</div>
<div class="wrap narrow cl">
  <div class="tools"><input class="search" id="q" type="search" placeholder="[[Search the changes]]" aria-label="[[Search the changes]]" autocomplete="off"></div>
  <nav class="jump" aria-label="[[Versions]]">{chips}</nav>
  <div id="log">
{chr(10).join(secs)}
  </div>
  <p class="none" id="none" role="status" hidden>[[Nothing in the changelog matches that.]]</p>
  <p class="top"><a href="#main">[[Back to the top]]</a></p>
</div>
'''
