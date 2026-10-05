# Robot Fighting (Godot 4.7)

## Versioning
- The version lives in `GameData.VERSION` (game_data.gd) and `config/version` in project.godot; the main menu shows "Salgadoido's version <VERSION>".
- 1.0a was the first alpha. Every change after that bumps the minor number: 1.1, 1.2, 1.3, ... Update both places in the same commit.

## Android APK
- `export_presets.cfg` has an "Android" preset (no Gradle, arm64 + armv7, landscape, package com.salgadoido.robotfighting); `version/name` and `version/code` must be bumped with each release (code +1 every build).
- Godot exports unsigned (`package/signed=false`); sign afterwards with the game's own keystore (robotfighting.keystore, alias `robotfighting`) — it is NOT in this public repo. Ask the user to attach it; an APK signed with a different key won't install over the old one.
- Headless export: `godot --headless --path . --export-release "Android" build/RobotFighting-unsigned.apk` (needs the 4.7 export templates and an Android SDK path in editor settings), then `java -jar uber-apk-signer.jar -a <apk> --ks robotfighting.keystore --ksAlias robotfighting`.
- Distribution: signed APKs go on the orphan `downloads` branch (RobotFighting-<version>.apk + README link); friends download from https://github.com/cavaleirobrancopensante/robotfightinggame/raw/downloads/RobotFighting-<version>.apk. Replace the old APK rather than piling up versions (keeps the repo small).
