# The Changelog page's body (W3): every release in the repository's CHANGELOG.md, newest first, with a search, and
# the feed of releases (/feed.xml, written by extra() below). The changes themselves are in English in every language.
# The build calls body(ctx) and extra(out_dir, values); see site-src/PAGES.md.
import datetime, email.utils, html, os, re, subprocess, time

REPO = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..', '..'))
SITE_URL = 'https://fantasyglassui.com'

# ---- THE 13.0 ENTRY, FILLED FROM CHANGELOG.md ------------------------------------------------------------------
# 13.0's notes are written into CHANGELOG.md with the release (under "## 13.0.0"). Until CHANGELOG.md has a 13.0
# heading, the page shows this marked stand-in at the top, badged "Coming", with no "Current" badge and no place in the
# feed. Once CHANGELOG.md has it, the stand-in goes by itself and the real notes are drawn like every other release.
PENDING = {'v': '13.0.0', 'lines': [
    '**Guide and Gold**',
    '- A route planner that works out your quests as you level, and Ways to make gold, which lists what is worth your time.',
    '- The full notes come with the release.',
]}


def has_release(versions, v):
    major = '.'.join(v.split('.')[:2])                    # (13.0.0, 13.0 or 13.0.1 all count as 13.0)
    return any(x['v'] == major or x['v'].startswith(major + '.') for x in versions)


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


def read_changelog(repo):
    """The intro lines and the releases [{v, lines}] of repo/CHANGELOG.md, newest first."""
    lines = open(repo + '/CHANGELOG.md', encoding='utf-8').read().split('\n')
    intro, versions, cur = [], [], None
    for ln in lines:
        if ln.startswith('# '): continue
        m = re.match(r'^## (\S+)\s*$', ln)
        if m:
            cur = {'v': m.group(1), 'lines': []}; versions.append(cur); continue
        (cur['lines'] if cur else intro).append(ln)
    return intro, versions


def anchor(v): return 'v' + v.replace('.', '-')


# The "Big updates" email list: one paragraph, one phrase in site_tr.py. To drop the list, set EMAIL_LIST = '' and
# delete that phrase; the release feed stays.
EMAIL_LIST = ('<p>[[For big updates only, by email: write to <a href="mailto:email-forwarding@fantasyglassui.com?subject=Big%20updates">email-forwarding@fantasyglassui.com</a> with the subject “Big updates”. Your address is kept only in our mailbox, it is used only to send you a note when a big update comes out, and writing again stops it.]]</p>')
FOLLOW = ('<aside class="follow card" aria-labelledby="h-follow"><h2 id="h-follow">[[Hear about new versions]]</h2>'
          '<p>[[New versions come out on CurseForge, and the <a href="/feed.xml">release feed</a> lists each one for any feed reader.]]</p>'
          + EMAIL_LIST + '</aside>')


def body(ctx):
    intro, versions = read_changelog(ctx.repo)
    pending = not has_release(versions, PENDING['v'])
    if pending: versions = [dict(PENDING, pending=True)] + versions
    en = '' if ctx.lang == 'en' else ' lang="en"'           # (the changes are written in English)
    chips = ''.join(f'<a href="#{anchor(x["v"])}">{x["v"]}</a>' for x in versions)
    secs = []
    for i, x in enumerate(versions):
        badge = ' <span class="now">[[Current]]</span>' if i == (1 if pending else 0) else ''
        if x.get('pending'): badge = ' <span class="soon">[[Coming soon]]</span>'
        first = ' <span class="first">[[First release]]</span>' if i == len(versions) - 1 else ''
        cls = 'ver card pending' if x.get('pending') else 'ver card'
        secs.append(f'<section class="{cls}" id="{anchor(x["v"])}" data-v="{x["v"]}" aria-labelledby="h-{anchor(x["v"])}">\n'
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
  @@FOLLOW@@
  <p class="top"><a href="#main">[[Back to the top]]</a></p>
</div>
'''.replace('@@FOLLOW@@', FOLLOW)


# ---- the feed of releases: /feed.xml (RSS 2.0), the newest 20, each linking its place on the Changelog --------------
def release_days(repo):
    """{version: 'YYYY-MM-DD'}: the day each "## <version>" line came into CHANGELOG.md (git blame); {} without git."""
    try:
        r = subprocess.run(['git', 'blame', '--line-porcelain', '--', 'CHANGELOG.md'], cwd=repo, capture_output=True, text=True, timeout=60)
    except Exception:
        return {}
    days, when = {}, None
    for ln in r.stdout.split('\n'):
        if ln.startswith('committer-time '): when = int(ln.split()[1])
        elif ln.startswith('\t'):
            m = re.match(r'^## (\S+)\s*$', ln[1:])
            if m and when and m.group(1) not in days:
                days[m.group(1)] = time.strftime('%Y-%m-%d', time.gmtime(when))
    return days


def feed(repo, limit=20):
    _, versions = read_changelog(repo)
    days = release_days(repo)
    items = []
    for x in versions[:limit]:
        link = f'{SITE_URL}/changelog/#{anchor(x["v"])}'
        day = days.get(x['v'])
        date = ''
        if day:
            d = datetime.datetime.strptime(day, '%Y-%m-%d').replace(tzinfo=datetime.timezone.utc)
            date = f'<pubDate>{email.utils.format_datetime(d)}</pubDate>'
        desc = html.escape(_body(x['lines']), quote=False)
        items.append(f'<item><title>Fantasy Glass UI {html.escape(x["v"])}</title><link>{link}</link>'
                     f'<guid isPermaLink="true">{link}</guid>{date}<description>{desc}</description></item>')
    return ('<?xml version="1.0" encoding="UTF-8"?>\n<rss version="2.0" xmlns:atom="http://www.w3.org/2005/Atom">\n<channel>\n'
            '<title>Fantasy Glass UI releases</title>\n'
            f'<link>{SITE_URL}/changelog/</link>\n'
            '<description>Every release of Fantasy Glass UI, the WoW Forever add-on.</description>\n<language>en</language>\n'
            f'<atom:link href="{SITE_URL}/feed.xml" rel="self" type="application/rss+xml"/>\n'
            + '\n'.join(items) + '\n</channel>\n</rss>\n')


def extra(out_dir, values):
    open(os.path.join(out_dir, 'feed.xml'), 'w', encoding='utf-8').write(feed(REPO))
