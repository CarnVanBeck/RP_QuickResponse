# RP - Quick Response

A World of Warcraft addon (WoW Forever, retail addon API) for role-play: a round button
that opens your categories in a ring around it. One click posts a random line from the chosen category.

## Usage

- **Main button** (shows your portrait): left-click opens or closes the ring, right-click opens
  the settings, dragging moves it (turn on "Lock button" to fix it in place).
- **Ring**: left-click a category to post a random line from it (never the same line twice in a row).
  Right-click a category to fan out its lines by their *Short* text and pick one.
  Escape or a click anywhere else closes the ring.
  The ring's buttons are secure macro buttons (the game blocks addons from sending `/s`, `/e` and `/y`
  themselves), so a click posts exactly like one of your own macros.
- **In combat** the ring works too. A left-click then steps through the category's lines in an order
  shuffled before the fight (out of combat it picks at random). A click elsewhere does not close it
  during combat; use the main button, a choice, or Escape. Changes in the settings reach the ring
  after the fight, and the button can only be moved out of combat.
- **Settings**: right-click the main button, click the minimap button, use the AddOns menu on the
  minimap, or type `/rpqr`. `/rpqr reset` puts the button back in the middle of the screen.

## Lines

Each line has:

- **Short**: shown in the ring.
- **Full**: run like a macro, one command per line. Any command works: `/s`, `/e`, `/y`,
  emotes such as `/wave` or `/bow`, `/p`, and so on. A line without a command is said.
  Long `/s`, `/e` and `/y` lines (and `/say`, `/emote`, `/em`, `/me`, `/yell`) are split at a space;
  any other line may be at most 255 characters.

Example:

```
/bow
/e smiles politely.
/s Welcome. May your road be a safe one.
```

The ring holds up to 12 categories. New players get Greeting, Farewell, Surprise and Cursing,
written in their game language.

## Icons

The settings window has an icon browser (click the category's icon): a grid of every icon
the game offers for macros, searchable by name (all words must appear: `holy heal`) or by file ID.
Click an icon to choose it; Enter chooses the only match.

The game hands addons file IDs only, so the names come from `IconData.lua`, generated from the
[wow-listfile](https://github.com/wowdev/wow-listfile) community listfile:

```
luajit Dev/build_icons.lua verified-listfile-withcapitals.csv > IconData.lua
```

## Translations

`Locales/<locale>.lua` holds one table per language, looked up by key (`ns.L.KEY`).
`enUS.lua` is the base and contains every key; a key missing from another language falls back to English.
To add a language, copy `enUS.lua` to `Locales/<locale>.lua` (for example `frFR.lua`), change the id in
`ns.RegisterLocale("frFR", ...)`, translate the values and add the file to `RP_QuickResponse.toc`.

## Saved data

`RPQuickResponseDB` (shared by the whole account). It has a `version` field: a change to its shape
bumps `ns.DB_VERSION` in `Core.lua` and adds a migration step to `STEPS`.

## Tests

```
luajit tests/run.lua
```

Runs offline against a small WoW API mock (`tests/mock.lua`) that also runs the secure snippets and
refuses insecure changes to secure frames during combat, so the ring's combat behaviour is covered.
`Dev/` and `tests/` are not needed in the game.

## Credits

- **Icon names**: `IconData.lua` is built from the community listfile of
  [wow-listfile](https://github.com/wowdev/wow-listfile) (wowdev). The icons themselves are the game's own.
- **Inspiration**: the look of the ring follows [EmoteForever](https://github.com/palanimForever/EmoteForever)
  by Palanim (MIT), the icon browser follows the one in [Total RP 3](https://github.com/Total-RP/Total-RP-3)
  (Apache 2.0). No code or art was taken from either; the ring is drawn from Blizzard's own textures.
- **Made with Claude**: this addon was written with the help of [Claude](https://claude.com/claude-code),
  Anthropic's AI assistant, directed and tested in game by CarnVanBeck.

## License

[MIT](LICENSE): anyone may use, change and share it, as long as the license notice stays with it.
