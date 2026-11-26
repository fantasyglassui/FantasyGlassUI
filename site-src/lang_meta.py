# Per-language <title>, description and link-preview title for the language pages (/de/ and so on).
META = {
 "en": ("Fantasy Glass UI", "A World of Warcraft add-on for WoW Forever: unit frames, action bars, raid frames, nameplates, bags and every window in one Starcut look, with {{themes}} themes.", "Fantasy Glass UI: your whole interface, cut like a gem", "Unit frames, bars, nameplates, bags and every window in one look, from {{themes}} themes. Free, for WoW Forever."),
 "de": ("Fantasy Glass UI", "Ein World-of-Warcraft-Add-on für WoW Forever: Einheitenfenster, Aktionsleisten, Schlachtzugsfenster, Namensplaketten, Taschen und jedes Fenster in einem Starcut-Look, mit {{themes}} Themen.", "Fantasy Glass UI: dein ganzes Interface, geschliffen wie ein Edelstein", "Einheitenfenster, Leisten, Namensplaketten, Taschen und jedes Fenster in einem Look, aus {{themes}} Themen. Kostenlos, für WoW Forever."),
 "fr": ("Fantasy Glass UI", "Un add-on World of Warcraft pour WoW Forever : cadres d'unité, barres d'action, cadres de raid, barres de nom, sacs et chaque fenêtre dans un même style Starcut, avec {{themes}} thèmes.", "Fantasy Glass UI : toute votre interface, taillée comme une gemme", "Cadres, barres, barres de nom, sacs et chaque fenêtre dans un même style, parmi {{themes}} thèmes. Gratuit, pour WoW Forever."),
 "es": ("Fantasy Glass UI", "Un accesorio de World of Warcraft para WoW Forever: marcos de unidad, barras de acción, marcos de banda, placas de nombre, bolsas y cada ventana con un aspecto Starcut, con {{themes}} temas.", "Fantasy Glass UI: toda tu interfaz, tallada como una gema", "Marcos, barras, placas de nombre, bolsas y cada ventana con un solo aspecto, entre {{themes}} temas. Gratis, para WoW Forever."),
 "ru": ("Fantasy Glass UI", "Аддон World of Warcraft для WoW Forever: рамки юнитов, панели команд, рамки рейда, индикаторы, сумки и все окна в едином стиле Starcut, {{themes}} тем.", "Fantasy Glass UI: весь интерфейс, огранённый, как самоцвет", "Рамки, панели, индикаторы, сумки и все окна в одном стиле на выбор из {{themes}} тем. Бесплатно, для WoW Forever."),
 "pt": ("Fantasy Glass UI", "Um addon de World of Warcraft para WoW Forever: quadros de unidade, barras de ação, quadros de raide, placas de nome, bolsas e cada janela num visual Starcut, com {{themes}} temas.", "Fantasy Glass UI: toda a sua interface, lapidada como uma gema", "Quadros, barras, placas de nome, bolsas e cada janela num só visual, entre {{themes}} temas. Grátis, para WoW Forever."),
 "it": ("Fantasy Glass UI", "Un add-on di World of Warcraft per WoW Forever: riquadri delle unità, barre delle azioni, riquadri d'incursione, barre dei nomi, borse e ogni finestra in uno stile Starcut, con {{themes}} temi.", "Fantasy Glass UI: tutta la tua interfaccia, tagliata come una gemma", "Riquadri, barre, barre dei nomi, borse e ogni finestra in un solo stile, tra {{themes}} temi. Gratis, per WoW Forever."),
 "ko": ("Fantasy Glass UI", "WoW Forever용 월드 오브 워크래프트 애드온: 유닛 프레임, 행동 단축바, 공격대 프레임, 이름표, 가방과 모든 창을 하나의 Starcut 외형으로, {{themes}}가지 테마.", "Fantasy Glass UI: 인터페이스 전체를 보석처럼", "프레임, 단축바, 이름표, 가방과 모든 창을 {{themes}}가지 테마 중 하나의 모습으로. WoW Forever용 무료 애드온."),
 "zh": ("Fantasy Glass UI", "适用于 WoW Forever 的魔兽世界插件：单位框体、动作条、团队框体、姓名板、背包和每一个窗口统一为 Starcut 外观，共 {{themes}} 款主题。", "Fantasy Glass UI：整个界面，如宝石般切琢", "框体、动作条、姓名板、背包和每个窗口统一外观，{{themes}} 款主题任选。免费，适用于 WoW Forever。"),
}
OG_LOCALE = {"en": "en_US", "de": "de_DE", "fr": "fr_FR", "es": "es_ES", "ru": "ru_RU", "pt": "pt_BR", "it": "it_IT", "ko": "ko_KR", "zh": "zh_CN"}

# The site's pages, in the order of the top row. Each page's folder is site-src/pages/<slug>/ and its address is
# /<slug>/ in English and /<code>/<slug>/ in the other languages (Home is / and /<code>/). "nav" is the page's name
# (in the top row, the tab title and the link preview); "desc" is its description (search results and the
# preview). Both are English here and translated in site_tr.py (the build stops if one is missing).
# Home's title and description are META above. Optional: "og_title" and "og_desc" for a preview that differs,
# "image" for a preview image of its own (a file in docs/, 1200 x 630), "top": False to leave it out of the top row,
# "foot": True to list it in the footer. W2 adds its new pages after "get-started", W3 at the end (see PAGES.md).
PAGES = [
    {"slug": "home", "nav": "Home"},
    {"slug": "features", "nav": "Features", "desc": "Every switch in Fantasy Glass UI and what it does, with one search across all of them."},
    {"slug": "themes", "nav": "Themes", "desc": "Themes in three families, Glass, Fantasy and Celestial, to try on this site, and a maker for your own."},
    {"slug": "guide-and-gold", "nav": "Guide and Gold", "desc": "What the quest guide and the gold advisor do, and how to use them."},
    {"slug": "get-started", "nav": "Get started", "desc": "Install Fantasy Glass UI and set it up in a few minutes, with answers to common questions and every command."},
    {"slug": "changelog", "nav": "Changelog", "desc": "Every release of Fantasy Glass UI, the WoW Forever add-on: what is new, what was fixed and what changed."},
    {"slug": "roadmap", "nav": "Roadmap", "desc": "What is coming to Fantasy Glass UI after 13.0, and what is being thought about."},
    {"slug": "accessibility", "nav": "Accessibility", "top": False, "foot": True, "desc": "What Fantasy Glass UI, the WoW Forever add-on, does for color blindness, low vision, blind players, deaf players, photosensitivity, one-handed play and more."},
]
LANG_NAMES = {"en": "English", "de": "Deutsch", "fr": "Français", "es": "Español", "ru": "Русский", "pt": "Português", "it": "Italiano", "ko": "한국어", "zh": "中文"}
# the structured data on Home (search engines read it); the theme count is filled in by the build
LD = {"@context": "https://schema.org", "@type": "SoftwareApplication", "name": "Fantasy Glass UI", "applicationCategory": "GameApplication",
      "applicationSubCategory": "World of Warcraft add-on", "operatingSystem": "Windows, macOS",
      "description": "A complete interface for WoW Forever: unit frames, action bars, raid frames, nameplates, bags and every window in one Starcut look, with %d themes.",
      "url": "https://fantasyglassui.com/", "image": "https://fantasyglassui.com/og.jpg", "downloadUrl": "https://www.curseforge.com/wow/addons/fantasy-glass-ui",
      "author": {"@type": "Person", "name": "DustyMouse"}, "offers": {"@type": "Offer", "price": "0", "priceCurrency": "USD"},
      "sameAs": ["https://discord.gg/qeSMwQWyPR", "https://www.curseforge.com/wow/addons/fantasy-glass-ui", "https://github.com/fantasyglassui/FantasyGlassUI"],
      "inLanguage": ["en", "de", "fr", "es", "ru", "pt", "it", "ko", "zh"]}
