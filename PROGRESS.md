# PET IDLE progress

## Current status and last verified commit
- Playable MVP on `main`; last verified prior commit `c855dbe` (multi-resource/Android UI). The character filter and batch-merge checkpoint below passed tests and is committed with this file; use `git log -1 --oneline` for its hash.

## Completed milestones (with tests)
- Foundation/core gameplay: Godot project, centralized 36-identity roster, three free rooms, six currencies, assignment/production, offline cap, versioned save/load, 27-tier merge, four gacha banners, book shop/equipment, independent collections, and functional six-screen portrait UI. `tests/test_game.gd`: 233 checks passed; headless main scene startup passed.
- Presentation and hardening: original procedural pet/employee portraits and app icon, book inventory and subtle UI feedback, two-system skill slots, save backup recovery and validation, 15-second autosave, Android portrait preset, user instructions. Full regression: 344 gameplay checks and 12 UI checks passed; main scene and editor import passed. Rendered 432×768 screenshots of Rooms, Characters and Gacha inspected; no clipping found in the visible viewport.
- Vietnamese player UI: all navigation, screens, buttons, gacha/shop/collection/help text, character details, skill descriptions and state errors now use the centralized `scripts/ui_text.gd` catalog. Proper character names and gameplay data stayed unchanged. Font glyph check covers catalog, resource names and all character names. Rendered 360×640 screenshots of six screens and detail/merge dialogs were inspected; text was readable and stayed within the layout. Regression: 344 gameplay checks; 25 UI checks at each of 360×640 and 432×768.
- Multi-resource and Android UI fix: pet foreign collection skill now produces its own resource alongside native output; native/foreign books affect only matching resource entries. Offline accrual credits both; save version stays 1. Rooms show each output. Character screen has fixed Thú cưng/Nhân viên tabs with separate counts, filtered cards and empty states. Resource icon plus Vietnamese name appears in inventory, selection, gacha, collection, details and merge. Both native scroll containers use a 12px touch deadzone with passing child controls and release-mode buttons. Expanded canvas uses tall phone height. Verified 364 gameplay checks and 54 UI checks at three portrait sizes; main scene starts headlessly.
- Character inventory and room pickers now filter pets/employees by resource system and exact rank, sorted highest rank first. Character cards show total owned copies of an identity and exact-tier copies needed for the next merge. Category-scoped confirmed bulk merge applies existing 2/2/3 rules repeatedly, returns equipped books, and retains a compatible room pair when merging its pet. The save schema and gameplay balance are unchanged. Verified 387 gameplay checks and 75 UI checks at each of three portrait sizes; editor import and main scene smoke passed.

## In progress
- Android on-device gesture and visual validation remains pending an exportable APK. Existing user changes to `project.godot`, `export_presets.cfg` and `PET IDLE.apk.idsig` remain outside this checkpoint.

## Remaining milestones
- Install Godot 4.7.2 Android export templates, Java SDK and Android SDK build/platform tools, then build and test an APK on several portrait devices. Final book catalog, purchase currency, foreign book magnitude interaction, starter state, and future resource sinks require design approval.

## Known bugs / blockers
- Android export attempted; no APK generated. This environment lacks Godot 4.7.2 Android debug/release templates, a configured Java SDK, and Android SDK `platform-tools`/`build-tools`. Godot's export command misleadingly returned process code 0 while logging export failure; artifact existence was checked separately.
- Godot prints a host certificate-store warning in sandboxed runs. It does not affect local gameplay tests.
- This checkpoint passed headless geometry tests at 360×640, 360×800 and 432×960. Godot headless does not perform native touch scrolling for synthetic touch events; tests verified drag propagation over a card button, no accidental action, control filters and deadzones. Real Android swipe/tap behavior and rendered layout still need device verification.
- Filter menus, new character cards and batch-merge confirmation passed headless geometry checks at 360x640, 360x800 and 432x960. Native Android option menus, swipes and rendered layout still require a device check.

## PROVISIONAL assumptions / unresolved design questions
- Starting state: one F- gold pet in three free rooms and no starting currency. This allows gold generation without creating free gacha pulls.
- Character names/matched pairs require original authoring; use three aligned identities per system.
- All employee identities share the confirmed 10-second F- reduction until differentiated balance is approved.
- Book catalog: one pet and one employee book per system, each full four-copy stack gives +100% to output/reduction. Purchase currency is its system resource. Both are PROVISIONAL pending approved catalog/currency.
- Book prices use exact integer ceil after each 10% increase. Resource balances retain fractional units; UI rounds to one decimal. PROVISIONAL rounding policy.
- A character may equip one unlocked foreign collection skill plus up to three books of that foreign system, allowing a 4+4 slot split at SSS. Pet foreign collection output is 50% of rank-scaled base output in its own resource, as confirmed by the current request. PROVISIONAL book interaction: foreign pet books add their same-system percentage to that 50% base (e.g. three copies: 50% + 60%). Native books affect native output only. PROVISIONAL matching interaction: the pair's +10% output bonus affects native output only. Employee foreign skill retains its prior native cooldown-reduction behavior; no foreign employee production was added.
- Employee reduction is subtracted from base cycle, then matching-pair 0.9 time multiplier; cycle is guarded at 1 second. PROVISIONAL order/floor.
- Assignment or equipment changes reset the affected room's partial cycle, preventing retroactive application of new bonuses. PROVISIONAL timing policy.
- Essence, components and fashion have no speculative sinks; their pets produce them and same-system books spend them.

## Test/build commands and last results
- `godot --headless --path . --editor --quit` with sandbox-writable `APPDATA`: import/parse passed (2026-10-15).
- `godot --headless --path . --script res://tests/test_game.gd`: 344 checks, 0 failures (2026-10-15).
- `godot --headless --path . --script res://tests/test_ui.gd`: 12 checks, 0 failures (2026-10-15).
- `godot --headless --path . --quit-after 5`: exit 0, no script errors (2026-10-15).
- `godot --headless --path . --export-debug Android build/pet-idle.apk`: export failed due missing templates/SDKs; `build/pet-idle.apk` absent (2026-10-15).
- Localization checkpoint (2026-10-15): `godot --headless --path . --editor --quit` passed; `--script res://tests/test_game.gd` passed 344/344; `--resolution 360x640 --script res://tests/test_ui.gd` and `--resolution 432x768 --script res://tests/test_ui.gd` each passed 25/25; `--quit-after 5` passed. All used sandbox-writable `APPDATA`.
- Multi-resource/UI checkpoint (2026-10-15): `--script res://tests/test_game.gd` passed 364/364; `--resolution 360x640`, `360x800`, and `432x960 --script res://tests/test_ui.gd` each passed 54/54; `--quit-after 5` passed. Editor import/parse passed; its Android SDK warning is noted above. All Godot runs used sandbox-writable `APPDATA`. Gameplay/UI suites share a save fixture, so run them sequentially.
- Character-filter/batch-merge checkpoint (2026-10-15): `--script res://tests/test_game.gd` passed 387/387; `--resolution 360x640`, `360x800`, and `432x960 --script res://tests/test_ui.gd` each passed 75/75. `--editor --quit`, `--quit-after 5` and `git diff --check` passed. All Godot runs used sandbox-writable `APPDATA`; gameplay and UI suites ran sequentially because they share a save fixture. Android build/device testing remains blocked by the export prerequisites above.

## Exact next action for the next session
- Install Android export prerequisites, build a debug APK, then test swipe over cards/text/portraits/buttons, button taps, popup scrolling and layout on narrow and tall portrait devices. Confirm the marked provisional foreign-book magnitude before final balance tuning.
