# The site's pages

How fantasyglassui.com is put together from 13.0 on, for whoever builds or changes a page. Every page is the
shared shell (head, header, footer) around the page's own body. The shell belongs to the site base (W1); each body
belongs to the team that fills it. **One page is one folder, and nobody edits another team's folder.**

    python3 site-src/make_i18n.py     # the words in 9 languages (site/i18n/, from site_tr.py and the add-on)
    python3 site-src/build_site.py    # every page in every language into docs/
    python3 tests/sitecheck.py        # every page, its cards and the sitemap, the plan page and the feed (on a committed tree)
    python3 tests/sitebrowser.py      # every page in Chromium at 390 and 1280 px: contrast, focus, width, old links

## The pages

| Page | Folder (its body) | English | Other languages | Team |
|---|---|---|---|---|
| Home | `pages/home/` | `/` | `/de/` | W2 |
| Features | `pages/features/` | `/features/` | `/de/features/` | W2 |
| Themes | `pages/themes/` | `/themes/` | `/de/themes/` | W2 |
| Guide and Gold | `pages/guide-and-gold/` | `/guide-and-gold/` | `/de/guide-and-gold/` | W3 |
| Get started | `pages/get-started/` | `/get-started/` | `/de/get-started/` | W2 |
| Changelog | `pages/changelog/` | `/changelog/` | `/de/changelog/` | W3 |
| Roadmap | `pages/roadmap/` | `/roadmap/` | `/de/roadmap/` | W3 |
| Accessibility | `pages/accessibility/` | `/accessibility/` | `/de/accessibility/` | W3 |
| How-to pages (5) | `pages/guide-and-gold/<name>/` | `/guide-and-gold/<name>/` | `/de/guide-and-gold/<name>/` | W3 |
| Press kit | `pages/press/` | `/press/` | `/de/press/` | W3 |
| Plan page | `plan/` (`plan_page.py`) | `/plan/` (every language inside it) | | W3 |

The languages are en, de, fr, es, ru, pt, it, ko and zh (`/de/`, `/fr/` ... `/zh/`). The list of pages, their
names and descriptions are in `lang_meta.py` (`PAGES`); the top row shows them in that order (Accessibility is in
the footer instead).

What each body holds now: the old long page's parts were moved where they belong, so a team fills and polishes
rather than starts from nothing.
- Home (W2, `pages/home/body.py` around `body.html`): the hero with the trailer slot (below), Try a theme (`#try`,
  nine themes from `FG_THEMES` painted live, and wearing one on the site), what sets it apart (`#why`), the
  before-and-after with the screenshots (`#look`), the Guide and Gold teaser (`#guide-gold`), the three families
  (`#families`) and the newest version (`#new`).
- Features (W2): every switch from `site/features.json`, a section at a time from the list on the left
  (`/features/#s-bags-and-bag-rules` opens one) or one search across all, and the fair comparison with ElvUI and the
  game's own interface (`#compare`). Each line in the comparison is checkable: Fantasy Glass UI's from its code
  (`CONFLICTS` and `ns.OTHER_UIS` in the add-on) and wiki; ElvUI's and the game's only where anyone can see it.
- Themes (W2): the gallery with wearing a theme on the site (`#themes`), and the theme maker (`#maker`).
- Get started (W2): the guided tour (install, the setup `#setup` with "Coming from another UI?", a theme, three
  things to try), the help box, one search across the questions (`#faq`) and the commands (`#commands`), and the
  common problems (`#problems`).

### The trailer (Home)

The hero's right side takes the 13.0 trailer from `site-src/site/video/`; `pages/home/body.py` looks there at build
time and the files are served at `/video/`:

    video/trailer.webm     the loop, sound-free (VP9; offered first)
    video/trailer.mp4      the same loop for browsers without WebM (H.264)
    video/poster.jpg       its first frame: shown until the loop plays, and whenever it doesn't (sets the size)
    video/captions.json    the captions: cue times and English lines (below); the build makes captions-<lang>.vtt

- With a video: a muted, looping `<video>` that downloads nothing but the poster until it scrolls into view, plays by
  itself only when the reader has not asked for reduced motion, pauses when scrolled away, and has a visible
  play/pause button (its label says which). Under reduced motion it waits for the button.
- With only `poster.jpg`: the poster as a still. With nothing there (now): the drawn Starcut frames, as before.
- Keep the files small (a few MB); add them with `git add site-src/site/video/` and rebuild. No other change is
  needed.

#### Captions, once the trailer is cut

The captions come from one file, `site/video/captions.json`, like every other word on the site. It ships with an
empty cue list (`"cues": []`), and while it is empty no caption file and no `<track>` is made. To fill it:

1. Watch the cut and write one cue per line shown, in English, with its start and end in seconds from the start of
   the trailer (decimals are fine; a cue may not start before the one above it ends; `\n` breaks a line):

       {"_translate": ["text"], "cues": [
         {"start": 0.0, "end": 2.8, "text": "Your whole interface in one look"},
         {"start": 2.8, "end": 6.0, "text": "A route planner for levelling"}
       ]}

2. Run `python3 site-src/keys_all.py && python3 site-src/make_i18n.py`: the new lines are listed as missing. Add
   them to the Home block of `site_tr.py` in all 8 other languages (German in "du"), and run `make_i18n.py` again.
3. Run `python3 site-src/build_site.py`. It writes `/video/captions-<lang>.vtt` (WebVTT) for all 9 languages, and
   the video gets a `<track kind="captions">` for each, labelled with the language's own name, with the page's
   language on by default (a reader can pick another from the player's captions menu). The build stops on a cue
   with no translation, or one whose times are wrong.

`python3 -m pytest tests -q -k site_captions` checks that a sample file makes valid WebVTT in every language.

- Changelog: built from the repository's `CHANGELOG.md` by `pages/changelog/body.py` (anchors `#v12-4-1` as before).
- Accessibility: `pages/accessibility/body.py`, the text of the old page (anchors `#seeing-color` and so on as before).
- Guide and Gold: the planner, Questie, gold, the hints, links to the five how-to pages and to the plan page (/plan/).
  Also a short tour (six steps, each outlining a part of the page; `#tour` and its steps in `#tour-steps` in
  `body.html`, run by `script.js`), and an example route (`#example`): the first `ok` plan code in
  `tests/plan_codes.txt`, read in the browser by the plan page's own reader (`plan/reader.js`, which `body.py`
  serves at `/assets/plan-reader.js`) and drawn zone by zone with its steps to tick.
- The zone maps, on the plan page and in the example route: one drawer, `plan/map.js` (inline in the plan page,
  `/assets/plan-map.js` for Guide and Gold). Each map is fitted to its zone's stops (one scale across and down, never
  closer than about 8 units of the zone's 0-100 map on a phone), its height follows them (150-420 px), and markers that
  would touch fan out around the spot or join into a run ("9–14"). A faint grid and N for north; no game map art.
  Markers are buttons named by their steps, and a step's number in the list is a button to its marker. Its words are
  in the Guide and Gold block of `site_tr.py`; `plan_page.py` copies them into the plan page (`MAP_WORDS`).
- Roadmap: drawn from `pages/roadmap/roadmap.json`; change an idea's status there (no dates).
  An in-progress idea may carry a `preview` (what it will do, in a player's words), a `sketch` (a small text sketch:
  `{"kind": "steps" | "list", "title": ..., "lines": [{"text": ...}]}`) and an `after` line; those ideas then show in a
  "Coming in <version>" section under Ready (`/roadmap/#coming-13-5`), marked as not out yet, with no date. Home
  (beside the latest version) and the Changelog (under its heading) link the first such section in one line, made by
  `coming_link()` in `pages/roadmap/body.py`. For a later release, give its in-progress ideas a preview; once they
  are out (status `ready`), the section and the links go by themselves.
- Changelog: also writes `/feed.xml` (RSS, linked in every head and footer). Until CHANGELOG.md has a `## 13.0.x`
  heading, a marked 13.0 stand-in ("Coming soon") stands at the top and stays out of the feed.
- A page can sit in a sub-folder (`pages/guide-and-gold/duo/` is `/guide-and-gold/duo/`); a data file with
  `"_translate": ["title", "text"]` has those fields listed for translation by `keys_all.py`.

Old links keep working: on Home, `/#features`, `/#themes`, `/#maker`, `/#commands`, `/#faq` and `/#start` (and the
same under `/de/` and so on), `/?theme=...` and `/?code=...#maker` open the page that now has that part (a small
script at the top of Home's head; `#look` and `#new` stay on Home). `?lang=de` on any page opens that page in German.
So keep those ids (`themes`, `maker`, `faq`, `commands`, `look`, `new`) on the parts that carry them.

## A page's folder

    pages/<slug>/
      body.html     the page's body, in English with [[...]] around every word to translate   (or body.py, below)
      style.css     optional: the page's own styles, put inline in its head, after the shared ones
      script.js     optional: the page's own script, served as /assets/<slug>.js, run after the shared one (defer)
      page.json     optional: {"data": true} also loads /assets/data.js (window.FG_THEMES, window.FG_NEWS);
                    {"noindex": true}; {"head": "<link ...>"} adds a line to the head (an RSS link, say)
      files/        optional: files served at the page's English address (/press-kit/logo.png, say)
      *.json, *.py  the page's own data, read by its body.py or its script

`body.py` instead of `body.html`: a page made from data defines `def body(ctx)` and returns the body's HTML (the
same markers work in it). `ctx.lang` is the language, `ctx.T("English")` translates, `ctx.F("Version %s", v)`
fills in, `ctx.url("features")` is a page's address in this language, `ctx.repo` is the repository's folder,
`ctx.version` the add-on's version and `ctx.values` the shared values below. It may also define
`def extra(out_dir, values)`, called once per build, to write files of its own (an RSS feed at `out_dir + "/feed.xml"`).

The body goes inside `<main id="main">`, between the shared header and footer. It has exactly one `<h1>`. Use
`<div class="wrap">` (or `wrap narrow`) for the page's width. Start it with an HTML comment naming the page.

### Words

- Every word a visitor reads is in all 9 languages. In a body, write the English inside `[[` and `]]`:
  `<h2>[[Asked often]]</h2>`, `alt="[[The bag window]]"`. The build puts in the translation from `site_tr.py`, and
  stops with a list of any phrase that has none.
- Add your page's new words to `site_tr.py`, **inside your page's own block** at the end of the file
  (`# -- Home (W2)`, `# -- Roadmap (W3)` and so on): English, then de, fr, es, ru, pt, it, ko, zh. Keep inline markup
  (`<code>`, `<b>`, `<a href="...">`) exactly the same in every language. German says "du" (and "Anleitung" for the
  guide); the tests check it.
- A link to another page inside a translated sentence, such as `<a href="/changelog/">`, is turned into the
  language's own address by the build (`/de/changelog/`).
- Words a script writes: `FG.L("Copied")`, `FG.F("Show all %d", n)`. They come from `/i18n/<lang>.json`, so wrap your
  first draw in `FG.ready(fn)` (or draw in English and again in `FG.ready`). They also go in your block in `site_tr.py`.
- Then run `python3 site-src/keys_all.py && python3 site-src/make_i18n.py`: the last line lists any phrase still
  missing.

### Shared values

Write these in a body (or in `body.py`'s output); the build fills them in:

| | |
|---|---|
| `{{status}}` | the status line: version, last update, the WoW: Forever build it is checked against, and a link to the source |
| `{{version}}`, `{{version_short}}` | the add-on's version, from `FantasyGlassUI.toc` (12.4.1, 12.4) |
| `{{updated}}` | the day `CHANGELOG.md` last changed (from git) |
| `{{forever}}` | the WoW: Forever client it is checked against (from `tests/forever_api.json.gz`) |
| `{{themes}}`, `{{switches}}`, `{{commands}}` | how many, from `site/data.js` and `site/features.json`; never type a count: they work inside translated words too (`[[{{themes}} themes]]`, with `{{themes}}` in each translation), and `{{themes}}` in Home's `META` in `lang_meta.py` |
| `{{url:<slug>}}` | a page's address in this language: `href="{{url:themes}}"` |
| `{{lang}}` | the language's code |
| `{{curseforge}}`, `{{discord}}`, `{{github}}`, `{{contact}}` | the addresses (the contact is email-forwarding@fantasyglassui.com) |

### Screenshots

`<fg-shot name="glass-bags" alt="[[The bag window]]" sizes="(max-width: 900px) 100vw, 560px" class="cut">` becomes
an `<img>` with every size there is of `site/shots/glass-bags.webp` (`-480`, `-800`, `-1600` and the full one) in
its `srcset`, its width and height, and `loading="lazy"`. Add `eager` to the one picture at the top of a page.
Any other attribute (`id`, `class`, `draggable`) is kept. A new screenshot goes in `site/shots/` as `<name>.webp`
with smaller copies `<name>-480.webp`, `<name>-800.webp` (and `<name>-1600.webp` when the full one is wider).

## The shared look (`site/base.css`)

Colours follow the roadmap's ruling ("Colours (23:07)"): a neutral dark ground, **gold for everything you press**,
**frost blue for links only**, eyebrow labels in dim gold, line-only cards, and a light mode with a darker gold.
A page uses the tokens and never sets a colour of its own for text on the ground; then light mode, dark mode, a
worn theme and the contrast check all keep working. Light mode redefines every token; `.night` keeps a part dark in
both (Home's hero over a screenshot).

Tokens (dark / light):

| Token | Dark | Light | For |
|---|---|---|---|
| `--ground` | #12141a | #f4f5f8 | the page |
| `--bar` | #14161d | #ffffff | header and footer |
| `--band` | #15181f | #eceef3 | a full-width band (`.band`) |
| `--card` | #181b22 | #ffffff | a filled box, sparingly (`.card.filled`) |
| `--shot` | #1c2029 | #e3e6ed | behind a screenshot while it loads |
| `--raised` | #1e222b | #ffffff | a raised control (a chip, a select) |
| `--rule` | #22262f | #dde0e7 | dividers |
| `--line` | #2c313c | #c9cdd8 | card outlines |
| `--edge` | #6b7287 | #767d8f | the outline of a field or a select (3:1) |
| `--text` | #e7e9f4 | #15171e | text |
| `--dim` | #a4abc7 | #454b5c | second text (ledes, descriptions) |
| `--faint` | #8a91b0 | #5b6173 | small print (still AA) |
| `--nav` | #c3c8dc | #2f3442 | the top row's links |
| `--gold`, `--gold-hover` | #f0c66b | #80560a | buttons, chips, what you press |
| `--on-gold` | #14110a | #ffffff | text on gold |
| `--eyebrow` | #c9a85a | #7a5512 | small labels above headings |
| `--frost`, `--frost-hover` | #8fd3ff | #1a5fa0 | links |
| `--focus` | #ffffff | #15171e | the focus ring |
| `--hp`, `--mana`, `--danger` | | | game colours for drawn bars |

Also `--display` (Marcellus, the add-on's lettering), `--body` (Source Sans 3), `--mono` (JetBrains Mono): all three
served from this site (`site/fonts/` -> `/fonts/`, woff2 from @fontsource in Latin, Latin Extended and Cyrillic, with
their SIL Open Font License files beside them; Korean and Chinese use the system's font). No font comes from another
site. `--cut` (12px, the corner cut), `--wrap` (1160px), `--gutter` (24px, 16px on a phone).
Older names still work for the moved parts: `--ink` = `--ground`, `--ink-2` = `--card`, `--ink-3` = `--raised`.

Classes:

| Class | What |
|---|---|
| `.wrap`, `.wrap.narrow` | the page's width (1160 / 920 px) with the side gutters |
| `.section` | vertical room for a section; `.band` a full-width band with rules |
| `.page-head` | a page's top: `.eyebrow`, `h1`, `.lede`, then `{{status}}` |
| `.eyebrow`, `.lede`, `.dim`, `.faint` | type |
| `.cut` | the corner cut (top left and bottom right) on anything |
| `.card` | a line-only card with the cut (its outline follows the corners); `a.card` turns gold on hover; `.card.filled` |
| `.grid` | cards in columns that fold on a phone |
| `.btn` | a gold button; `.btn.line` the gold outline one (`.ghost`, `.soft` are older names for it); `.btn.small` |
| `.cta` | a row of buttons (full width each on a phone) |
| `.chip`, `.filters` | a row of choices; the chosen one has `aria-pressed="true"` and turns gold |
| `.search`, `.field`, `.tools`, `.count` | a text field, a row for it, and a count beside it |
| `.status` | the status line |
| `.placeholder` | "more here soon" text |
| `.sr-only` | for screen readers only |
| `section.block` | the moved sections: a `header` (eyebrow, heading, lede) over the content |

Focus: every control shows a ring; a cut element draws it inside itself (the cut would clip one outside). Motion:
anything that moves stops under `prefers-reduced-motion` (the shared CSS sets that for every animation and
transition; a script that moves things checks `FG.reduce`).

## The shared script (`site/site.js`, `window.FG`)

`FG.lang`, `FG.base` (`/` or `/de/`), `FG.url("themes/")` (an address in this language), `FG.site`, `FG.$(id)`,
`FG.esc(text)`, `FG.L(words)`, `FG.F(words, ...)`, `FG.ready(fn)`, `FG.reduce`, `FG.copy(text, done)`,
`FG.wear(theme)`, `FG.unwear()`, `FG.worn()`. It also runs the phone menu, the language switcher (remembered),
light and dark (remembered; the system's choice until pressed) and a worn theme on every page.

## What belongs to whom

- **W1, the base** (change only by agreement, as both teams rely on it): `build_site.py`, `lang_meta.py`,
  `site/base.css`, `site/site.js`, `keys_all.py`, `make_i18n.py`, `tests/sitecheck.py`, `tests/sitebrowser.py`,
  `tests/test_site.py`, and the shared words at the top of `site_tr.py`.
- **A page's team**: everything in its `pages/<slug>/` folder, and its own block at the end of `site_tr.py`.
- Shared data (`site/features.json`, `site/data.js`, `site/shots/`): add to it; don't reorder or rename what is there.
- A page's name or description changes on its own line in `lang_meta.py` `PAGES`, with the translation in the
  page's block of `site_tr.py`.

## Adding a page

1. Add it to `PAGES` in `lang_meta.py`: `{"slug": "compare", "nav": "Coming from another UI", "desc": "...", "top": False}`.
   W2 adds its new pages right after `get-started`, W3 after `accessibility`, so the two never touch the same line.
   `"top": False` keeps it out of the top row; `"foot": True` lists it in the footer.
2. Make `pages/<slug>/` with a `body.html` (or `body.py`), and add its words (its name and description too) to your
   block in `site_tr.py`.
3. Run `make_i18n.py` and `build_site.py`. The page is built in all 9 languages, with its card, its alternates and
   its place in the sitemap. Then the two checks above.
