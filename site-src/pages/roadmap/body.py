# The Roadmap page's body (W3): every idea after 13.0 from roadmap.json (the one file to change), grouped, each with
# its status and no dates, a filter by status, and the "Ideas welcome" line. The words in roadmap.json are English,
# wrapped in the double square brackets here so the build translates them from site_tr.py's Roadmap block. See site-src/PAGES.md.
import html, json, os

DATA = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'roadmap.json')


def load():
    d = json.load(open(DATA, encoding='utf-8'))
    statuses = {s['id']: s for s in d['statuses']}
    groups = {g['id']: g for g in d['groups']}
    seen = set()
    for i in d['ideas']:
        if i['status'] not in statuses: raise SystemExit(f'roadmap.json: idea {i["n"]} has the status {i["status"]!r}')
        if i['group'] not in groups: raise SystemExit(f'roadmap.json: idea {i["n"]} has the group {i["group"]!r}')
        if i['n'] in seen: raise SystemExit(f'roadmap.json: two ideas numbered {i["n"]}')
        if i['status'] in ('ready', 'progress') and not i.get('version'): raise SystemExit(f'roadmap.json: {i["status"]} idea {i["n"]} has no "version"')
        seen.add(i['n'])
    return d


WELCOME = '<p>[[Something you would like to see, or an idea on this list you want sooner? Tell us on <a href="{{discord}}">Discord</a> or write to <a href="mailto:email-forwarding@fantasyglassui.com">email-forwarding@fantasyglassui.com</a>.]]</p>'


# ---- "Coming in <version>": the in-progress ideas that have a "preview", in plain words, under the Ready section --
# (Home and the Changelog link it with coming_link(), so a later release only changes roadmap.json.)
COMING = '[[Coming in %s]]'                                  # (these three are listed for translation by keys_all.py;
NOT_YET = '[[%s is not out yet and has no date. Any of this may change before it comes out.]]'   # the build fills
LINK = '[[A first look at %s: what is being built now]]'     # in the version with ctx.F)


def phrase(marked): return marked[2:-2]


def anchor(version): return 'coming-' + str(version).replace('.', '-')


def previews(d=None):
    """[(version, [ideas])] for every version with an in-progress idea that has a preview, oldest first."""
    d = d or load()
    out = {}
    for i in d['ideas']:
        if i['status'] == 'progress' and i.get('preview'): out.setdefault(str(i['version']), []).append(i)
    key = lambda v: [int(x) for x in v.split('.') if x.isdigit()]
    return [(v, out[v]) for v in sorted(out, key=key)]


def coming_link(ctx, cls='coming-link'):
    """A one-line link to the first "Coming in" section (for Home and the Changelog), or '' when there is none."""
    p = previews()
    if not p: return ''
    v = p[0][0]
    return f'<p class="{cls}"><a href="/roadmap/#{anchor(v)}">{ctx.F(phrase(LINK), html.escape(v))}</a> <span aria-hidden="true">→</span></p>'


def w(t):
    # the build's marker for words to translate (the data has no brackets or quotes of its own to escape)
    return '[' '[' + html.escape(t, quote=False) + ']' ']'      # (written apart, so keys_all.py does not take this line for a phrase)


def m(t):
    # a preview's words, which may hold <code>: marked for the build as they are (roadmap.json is ours)
    if any(x in t for x in ('[' '[', ']' ']', '{' '{', '}' '}')): raise SystemExit(f'roadmap.json: no double brackets or braces in {t!r}')
    return '[' '[' + t + ']' ']'


def sketch(sk):
    if not sk: return ''
    tag = 'ol' if sk.get('kind') == 'steps' else 'ul'
    lines = ''.join(f'<li>{m(x["text"])}</li>' for x in sk['lines'])
    return f'<figure class="sketch {html.escape(sk.get("kind", "list"))}"><figcaption>{w(sk["title"])}</figcaption><{tag}>{lines}</{tag}></figure>'


def coming(ctx, d, progress_name):
    secs = []
    for v, ideas in previews(d):
        a = anchor(v)
        cards = ''.join(f'<article class="pv card" id="pv-{i["n"]}" aria-labelledby="pv-h-{i["n"]}"><span class="tag progress">{w(progress_name)}</span>'
                        f'<h3 id="pv-h-{i["n"]}">{w(i["title"])}</h3>'
                        f'<p>{m(i["preview"])}</p>{sketch(i.get("sketch"))}' + (f'<p class="after">{m(i["after"])}</p>' if i.get('after') else '') + '</article>'
                        for i in sorted(ideas, key=lambda i: ({g['id']: k for k, g in enumerate(d['groups'])}[i['group']], i['n'])))
        secs.append(f'<section class="rm-coming" id="{a}" aria-labelledby="h-{a}"><header><span class="eyebrow">[[Preview]]</span>'
                    f'<h2 id="h-{a}">{ctx.F(phrase(COMING), html.escape(v))}</h2>'
                    f'<p class="dim">[[What the ideas marked In progress will do once they are out, in plain words.]]</p></header>'
                    f'<p class="notyet" role="note"><b class="tag-soon">[[Not out yet]]</b> {ctx.F(phrase(NOT_YET), html.escape(v))}</p>'
                    f'<div class="previews">{cards}</div></section>')
    return '\n'.join(secs)


def body(ctx):
    d = load()
    order = [s['id'] for s in d['statuses']]
    count = {s: sum(1 for i in d['ideas'] if i['status'] == s) for s in order}
    chips = [f'<button class="chip" type="button" data-show="all" aria-pressed="true">[[All]] <span>{len(d["ideas"])}</span></button>']
    chips += [f'<button class="chip" type="button" data-show="{s["id"]}" aria-pressed="false">{w(s["name"])} <span>{count[s["id"]]}</span></button>' for s in d['statuses']]
    legend = ''.join(f'<li><span class="tag {s["id"]}">{w(s["name"])}</span> {w(s["text"])}</li>' for s in d['statuses'])
    # the Ready section first: every idea that is out, newest version first (and not again in its group below)
    done = sorted((i for i in d['ideas'] if i['status'] == 'ready'), key=lambda i: ([-int(x) for x in str(i['version']).split('.') if x.isdigit()], i['n']))
    ready_name = next(s['name'] for s in d['statuses'] if s['id'] == 'ready')
    group_name = {g['id']: g['name'] for g in d['groups']}
    if done:
        ritems = ''.join(f'<li class="idea card" data-status="ready"><span class="tag ready">{w(ready_name)}</span><span class="ver">[[Version]] {html.escape(str(i["version"]))} · {w(group_name[i["group"]])}</span>'
                         f'<h3>{w(i["title"])}</h3><p>{w(i["text"])}</p></li>' for i in done)
    else:
        ritems = '<li class="empty dim">[[Nothing here yet: ideas move here as they come out.]]</li>'
    secs = [f'<section class="rm-group rm-ready" id="ready" data-keep="ready" aria-labelledby="h-ready"><header><h2 id="h-ready">{w(ready_name)}</h2>'
            f'<p class="dim">{w(next(s["text"] for s in d["statuses"] if s["id"] == "ready"))}</p></header><ul class="ideas">{ritems}</ul></section>']
    secs.append(coming(ctx, d, next(s['name'] for s in d['statuses'] if s['id'] == 'progress')))
    for g in d['groups']:
        ideas = sorted((i for i in d['ideas'] if i['group'] == g['id'] and i['status'] != 'ready'), key=lambda i: (order.index(i['status']), i['n']))
        items = ''.join(f'<li class="idea card" data-status="{i["status"]}"><span class="tag {i["status"]}">{w(next(s["name"] for s in d["statuses"] if s["id"] == i["status"]))}</span>'
                        + (f'<span class="ver">[[Expected in]] {html.escape(str(i["version"]))}</span>' if i['status'] == 'progress' else '')
                        + f'<h3>{w(i["title"])}</h3><p>{w(i["text"])}</p></li>' for i in ideas)
        secs.append(f'<section class="rm-group" id="{g["id"]}" aria-labelledby="h-{g["id"]}"><header><h2 id="h-{g["id"]}">{w(g["name"])}</h2>'
                    f'<p class="dim">{w(g["text"])}</p></header><ul class="ideas">{items}</ul></section>')
    return f'''<!-- Roadmap (W3). Drawn from pages/roadmap/roadmap.json by pages/roadmap/body.py; see site-src/PAGES.md. -->
<div class="wrap page-head">
  <span class="eyebrow">[[After 13.0]]</span>
  <h1>[[Roadmap]]</h1>
  <p class="lede">[[What is coming to Fantasy Glass UI after 13.0, and what is being thought about.]]</p>
  <p class="dim nodates">[[There are no dates: an idea moves up when it is ready, and the list changes as we go. Just out in 13.5: dungeon runs in your route, class quests on time and more, under <a href="#ready">Ready</a>.]]</p>
</div>
<div class="wrap rm">
  <ul class="legend">{legend}</ul>
  <div class="filters" role="group" aria-label="[[Show]]">{"".join(chips)}</div>
  <p class="sr-only" id="rm-count" role="status"></p>
{chr(10).join(secs)}
  <aside class="card filled welcome" aria-labelledby="h-welcome">
    <h2 id="h-welcome">[[Ideas welcome]]</h2>
    @@WELCOME@@
  </aside>
</div>
'''.replace('@@WELCOME@@', WELCOME)
