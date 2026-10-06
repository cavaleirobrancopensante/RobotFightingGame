# Robot Fighting (Godot 4.7)

## Versioning
- The version lives in `GameData.VERSION` (game_data.gd) and `config/version` in project.godot; the main menu shows "Salgadoido's version <VERSION>".
- 1.0a was the first alpha. Every change after that bumps the minor number: 1.1, 1.2, 1.3, ... Update both places in the same commit.

## Android APK
- `export_presets.cfg` has an "Android" preset (no Gradle, arm64 + armv7, landscape, package com.salgadoido.robotfighting); `version/name` and `version/code` must be bumped with each release (code +1 every build).
- Godot exports unsigned (`package/signed=false`); sign afterwards with the game's own keystore (robotfighting.keystore, alias `robotfighting`) — it is NOT in this public repo. Ask the user to attach it; an APK signed with a different key won't install over the old one.
- Headless export: `godot --headless --path . --export-release "Android" build/RobotFighting-unsigned.apk` (needs the 4.7 export templates and an Android SDK path in editor settings), then `java -jar uber-apk-signer.jar -a <apk> --ks robotfighting.keystore --ksAlias robotfighting`.
- Distribution: signed APKs go on the orphan `downloads` branch (RobotFighting-<version>.apk + README link); friends download from https://github.com/cavaleirobrancopensante/robotfightinggame/raw/downloads/RobotFighting-<version>.apk. Replace the old APK rather than piling up versions (keeps the repo small).

## Web build (iPhone / any browser)
- `export_presets.cfg` preset "Web": single-threaded (`variant/thread_support=false`) so it runs in iOS Safari without special headers; PWA on, so it can be added to the home screen.
- Export: `godot --headless --path . --export-release "Web" build/web/index.html`, then copy `build/web/*` plus an empty `.nojekyll` to the orphan `gh-pages` branch (replace its contents each release).
- Served by GitHub Pages at https://cavaleirobrancopensante.github.io/RobotFightingGame/ (Pages must be enabled once in repo Settings > Pages > branch gh-pages, root).

## Agreed garage redesign (Oct 2026) - build in this order
Design references: "Garage Menu Blueprint" artifact (layout, option E) and "Garage Art Styles" canvas (style = **Mix B · Clean Diagnostic**).
- **1.2 (done)** Save after every garage change (buy/fit/sell/repair/etc.), on Menu, and on Android/app pause. Left side rail: Bay, Storage, Get Parts, Season, Crew, Menu at the bottom (Save lives only in Menu). Top strip: date chip (left), ad space (centre, keep free), money (right). Bottom: Repair all, Send, body map, Fight (unchanged spot). Gus speaks in a speech bubble in the scene instead of the message line. Mix B look: dark rounded panels, Chakra Petch + Public Sans, VT323 glowing numbers (money/date/HP/prices green or amber), yellow accent; Fight = yellow stencil button in a hazard-stripe frame. Part HP bars: joined blocks, **1 block = 10 HP always** (length shows toughness), plus a second info line per part (armor, dmg, power, quirk).
  - Sections: Bay (Robot | Chips | Style & paint; Setups ▾, Randomize). Storage (own section, Show ▾ filter, Select to sell several). Get Parts (Scrapyard first, unlocked from the start | Dealer, fight 2 | Made to order, fight 7). Season (Calendar | Standings | Cups | Bets | Pilots - cups live here). Crew (Backups | Pilot incl. controllers).
- **1.3** Bay robot drawn FRONT-facing, arms open, on Gus's gantry; tap a part = yellow/black hazard outline + callout lines for that part only. Rename front/back arm/leg to **Left/Right everywhere** (matches the L/R punch/kick halves). Write 1-2 flavour callout lines per catalogue part + damaged variants ("elbow loose", "bent strut").
- **1.4** Detail pane (left) with green/red comparisons; one button per row; Buy & fit; pre-fight window gets bet-on-yourself and "Repair all & fight".
- **1.5** Season calendar = real month page, bigger cells, text only on Wed (cup) / Sat (fight) / Sun (restock, rent), a light Fight-Night-poster touch on Saturdays and the next-fight card. Bets screen background: pub "The Rusty Bolt" (placeholder name) - our pilot (player's look) at the bar drinking beer on a loop and pushing coins when betting; bartender; TV showing fights.
- **1.6** Scrapyard Test Drive: practice vs Gus's silly Junkers (The Fridge blocks, Toaster Tim slow punches, Lawnmower Larry wanders, Mop Bucket damage dummy); input readout, move list, reset; no damage carries over, no rewards; dealer parts get "Test drive" (try before you buy).
- Bay objects (calendar, doors, window) are decoration only, not shortcuts.
