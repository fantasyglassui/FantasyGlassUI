# The website's source

fantasyglassui.com is built from here into `../docs/` (served by GitHub Pages). Nothing here goes into the add-on's zip.

    python3 site-src/make_i18n.py     # the 9 languages: site/i18n/<code>.json, from site_tr.py, words/ and the add-on's Locales.lua
    python3 site-src/build_site.py    # every page in every language into docs/, with the sitemap

How the pages are made, which file holds each page's body, and the shared look: **[PAGES.md](PAGES.md)**.

- `pages/<slug>/`: each page's own body (Home, Features, Themes, Guide and Gold, Get started, Changelog, Roadmap,
  Accessibility), with its styles, script and data.
- `site/`: what the pages share: `base.css` (the look), `site.js` (the shared script), `data.js` (themes and news),
  `features.json` (every switch and command), the logo, the lettering and the screenshots.
- `build_site.py`: the shell (head, header, footer, the status line, each page's link preview) and the build.
- `lang_meta.py`: the list of pages, and Home's title and description in each language.
- `site_tr.py`: the site's own words in every language. `words/`: translation tables the site's lists are filled from.
- `keys_all.py` / `keys_all.json`: which phrases the site needs translated.
- `plan/`, `plan_page.py`: the plan page, built only with `--plan` and never linked.
- `tools/`: `add_tr.py` adds phrases to the add-on's Locales.lua, `missing_tr.py` lists what is untranslated, `regen_rc.py` refreshes `.luacheckrc`.
