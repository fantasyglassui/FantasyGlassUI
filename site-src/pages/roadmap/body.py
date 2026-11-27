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
        if i['status'] == 'ready' and not i.get('version'): raise SystemExit(f'roadmap.json: ready idea {i["n"]} has no "version"')
        seen.add(i['n'])
    return d


WELCOME = '<p>[[Something you would like to see, or an idea on this list you want sooner? Tell us on <a href="{{discord}}">Discord</a> or write to <a href="mailto:email-forwarding@fantasyglassui.com">email-forwarding@fantasyglassui.com</a>.]]</p>'


def w(t):
    # the build's marker for words to translate (the data has no brackets or quotes of its own to escape)
    return '[' '[' + html.escape(t, quote=False) + ']' ']'      # (written apart, so keys_all.py does not take this line for a phrase)


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
    for g in d['groups']:
        ideas = sorted((i for i in d['ideas'] if i['group'] == g['id'] and i['status'] != 'ready'), key=lambda i: (order.index(i['status']), i['n']))
        items = ''.join(f'<li class="idea card" data-status="{i["status"]}"><span class="tag {i["status"]}">{w(next(s["name"] for s in d["statuses"] if s["id"] == i["status"]))}</span>'
                        f'<h3>{w(i["title"])}</h3><p>{w(i["text"])}</p></li>' for i in ideas)
        secs.append(f'<section class="rm-group" id="{g["id"]}" aria-labelledby="h-{g["id"]}"><header><h2 id="h-{g["id"]}">{w(g["name"])}</h2>'
                    f'<p class="dim">{w(g["text"])}</p></header><ul class="ideas">{items}</ul></section>')
    return f'''<!-- Roadmap (W3). Drawn from pages/roadmap/roadmap.json by pages/roadmap/body.py; see site-src/PAGES.md. -->
<div class="wrap page-head">
  <span class="eyebrow">[[After 13.0]]</span>
  <h1>[[Roadmap]]</h1>
  <p class="lede">[[What is coming to Fantasy Glass UI after 13.0, and what is being thought about.]]</p>
  <p class="dim nodates">[[There are no dates: an idea moves up when it is ready, and the list changes as we go. Just out in 13.0: <a href="/guide-and-gold/">Guide and Gold</a>.]]</p>
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
