# The website's source

fantasyglassui.com is built from here into `../docs/` (served by GitHub Pages). Nothing here goes into the add-on's zip.

    python3 site-src/make_i18n.py     # the 9 languages: site/i18n/<code>.json, from site_tr.py, words/ and the add-on's Locales.lua
    python3 site-src/build_site.py    # the pages: docs/index.html and one per language, the sitemap, the changelog and accessibility pages

- `site/`: the page's parts (head.html, body.html, script.html), its data (data.js: themes and news; features.json: every switch and command), images and screenshots.
- `site_tr.py`: the site's own words in every language. `lang_meta.py`: each language page's title and description.
- `changelog_page.py`, `accessibility_page.py`: the /changelog/ and /accessibility/ pages.
- `words/`: translation tables the site's lists are filled from.
- `keys_all.py` / `keys_all.json` / `keys_static.json`: which phrases the site needs translated.
- `tools/`: `add_tr.py` adds phrases to the add-on's Locales.lua, `missing_tr.py` lists what is untranslated, `regen_rc.py` refreshes `.luacheckrc`.
