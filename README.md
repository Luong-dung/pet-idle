# PET IDLE

An offline portrait idle game for Godot 4.7. Open `project.godot` in Godot and run the main scene. The first pet produces gold in one of three free rooms. Use the navigation buttons to assign characters, draw from four banners, merge ranks, buy and equip books, and view collections. Saves are local to `user://pet_idle_save.json` and production accrues for up to 24 hours while away.

## Verify

From the project directory, run:

```powershell
godot --headless --path . --editor --quit
godot --headless --path . --script res://tests/test_game.gd
godot --headless --path . --script res://tests/test_ui.gd
godot --headless --path . --quit-after 5
```

In a restricted Windows sandbox, set `APPDATA` to a writable temporary directory for these commands. The test script writes only to Godot's local `user://` test save.

## Android

The project is configured for portrait orientation and includes an Android export preset. In Godot's Editor Settings, install Android export templates for the exact Godot version and configure the Android SDK and Java SDK. Then run:

```powershell
godot --headless --path . --export-debug Android build/pet-idle.apk
```

For a release build, configure your own signing keystore in Godot and use `--export-release`. Keystores and APK files are ignored by Git. See `PROGRESS.md` for the currently verified export status and provisional balance choices.
