# Fantasy Glass UI: API for other add-ons

Fantasy Glass UI offers a small, stable API to other add-ons through the global table
`FantasyGlassUI_API`. Within one API `version` nothing listed here changes. Anything else in
Fantasy Glass UI may change between releases, so use only what is described here.

Add `## OptionalDeps: FantasyGlassUI` to your TOC so your add-on loads after this one, then:

```lua
local FG = FantasyGlassUI_API
if FG and FG.version >= 1 then
    -- your code
end
```

## Info bar

`FG.RegisterInfoPiece(key, label, textFunction, options)`

Adds a piece of text to the info bar at the top of the screen. `textFunction()` is called about
once a second and returns a string (it may hold color codes), or `nil` to show nothing. The piece
appears in the bar's right-click list under `label`, where players switch it on and off. Pass
`{ defaultOff = true }` as `options` to start it switched off. Returns the piece's key.

```lua
FG.RegisterInfoPiece("myaddon:honor", "Honor", function()
    return "|cffffffff" .. (MyAddon.honor or 0) .. "|r honor"
end)
```

## Themes

`FG.RegisterTheme(key, name, definition)`

Adds a theme to the Look tab, listed with the others of its family. `definition` is
`{ style = "GLASS" or "FANTASY", panel = { r, g, b }, rim = { r, g, b }, accent = { r, g, b } }`
with colors from 0 to 1. Returns the theme's id.

## Commands, Tools tab and the guide

- `FG.RegisterCommand(word, function(rest) end, helpLine)`: `/fgui <word> ...` runs your function
  with the rest of the line. `helpLine` is shown by `/fgui help`. A word that is taken raises an error.
- `FG.RegisterToolWindow(label, function() end)`: a button on the Tools tab that opens your window.
- `FG.RegisterGuideTopic({ title = ..., text = ..., keys = "words people might type", command = "/myaddon" })`:
  an answer for "Ask the guide" on the Tools tab.

## Panels

`FG.RegisterPanel(frame, key, label)`

Lets your frame be dragged with `/fgui move` and saves its place with the player's layout.

## Looking like Fantasy Glass UI

- `FG.GetColor(role)` returns r, g, b for `"accent"`, `"border"`, `"bg"`, `"text"`, `"dim"` or `"faint"`.
- `FG.GetFonts()` returns the body font file and the heading font file.
- `FG.GetStyle()` returns `"GLASS"` or `"FANTASY"`, and the theme's id.
- `FG.Style(frame, alpha)` dresses a frame made with `BackdropTemplate` as Fantasy Glass UI dresses
  its own windows (background, rim, and the theme's corner work). It follows theme changes.
- `FG.StyleText(fontString, size, isTitle)` sets a font string in the add-on's lettering.
- `FG.OnThemeChanged(function() end)` runs your function after every change of theme or accent.

## Messages

- `FG.Toast(title, text, icon)`: a notice in the corner of the screen.
- `FG.Flash(text, r, g, b)`: a line in the middle of the screen for a moment.
- `FG.Speak(text)`: says the text aloud, only when the player has spoken alerts switched on.

## Questions

- `FG.IsFeatureOn(key)`: is that feature switched on and running? (The keys are those `/fgui check` lists.)
- `FG.GetRole()`: `"TANK"`, `"HEALER"`, `"DAMAGE"`, or `nil` before the player has chosen.
- `FG.version` is the API version (1). `FG.addonVersion` is Fantasy Glass UI's version.
