# PET IDLE progress

## Current status and last verified commit
- Playable MVP on `main`; prior verified checkpoint `765b4c4` was pushed. For the current checkpoint hash, run `git log -1 --oneline` after commit.

## Completed milestones (with tests)
- Foundation/core gameplay: Godot project, centralized 36-identity roster, three free rooms, six currencies, assignment/production, offline cap, versioned save/load, 27-tier merge, four gacha banners, book shop/equipment, independent collections, and functional six-screen portrait UI. `tests/test_game.gd`: 233 checks passed; headless main scene startup passed.
- Presentation and hardening: original procedural pet/employee portraits and app icon, book inventory and subtle UI feedback, two-system skill slots, save backup recovery and validation, 15-second autosave, Android portrait preset, user instructions. Full regression: 344 gameplay checks and 12 UI checks passed; main scene and editor import passed. Rendered 432×768 screenshots of Rooms, Characters and Gacha inspected; no clipping found in the visible viewport.

## In progress
- Final checkpoint commit/push and design clarification handoff.

## Remaining milestones
- Install Godot 4.7.2 Android export templates, Java SDK and Android SDK build/platform tools, then build and test an APK on device. Final book catalog, purchase currency, foreign skill/book targeting, starter state, and future resource sinks require design approval.

## Known bugs / blockers
- Android export attempted; no APK generated. This environment lacks Godot 4.7.2 Android debug/release templates, a configured Java SDK, and Android SDK `platform-tools`/`build-tools`. Godot's export command misleadingly returned process code 0 while logging export failure; artifact existence was checked separately.
- Godot prints a host certificate-store warning in sandboxed runs. It does not affect local gameplay tests.

## PROVISIONAL assumptions / unresolved design questions
- Starting state: one F- gold pet in three free rooms and no starting currency. This allows gold generation without creating free gacha pulls.
- Character names/matched pairs require original authoring; use three aligned identities per system.
- All employee identities share the confirmed 10-second F- reduction until differentiated balance is approved.
- Book catalog: one pet and one employee book per system, each full four-copy stack gives +100% to output/reduction. Purchase currency is its system resource. Both are PROVISIONAL pending approved catalog/currency.
- Book prices use exact integer ceil after each 10% increase. Resource balances retain fractional units; UI rounds to one decimal. PROVISIONAL rounding policy.
- A character may equip one unlocked foreign collection skill plus up to three books of that foreign system, allowing a 4+4 slot split at SSS. Foreign books occupy slots but do not affect native resource production; books only affect their own system. The collection skill adds +50% of native output or innate reduction, additively with native books. PROVISIONAL targeting/interaction pending design approval.
- Employee reduction is subtracted from base cycle, then matching-pair 0.9 time multiplier; cycle is guarded at 1 second. PROVISIONAL order/floor.
- Assignment or equipment changes reset the affected room's partial cycle, preventing retroactive application of new bonuses. PROVISIONAL timing policy.
- Essence, components and fashion have no speculative sinks; their pets produce them and same-system books spend them.

## Test/build commands and last results
- `godot --headless --path . --editor --quit` with sandbox-writable `APPDATA`: import/parse passed (2026-10-15).
- `godot --headless --path . --script res://tests/test_game.gd`: 344 checks, 0 failures (2026-10-15).
- `godot --headless --path . --script res://tests/test_ui.gd`: 12 checks, 0 failures (2026-10-15).
- `godot --headless --path . --quit-after 5`: exit 0, no script errors (2026-10-15).
- `godot --headless --path . --export-debug Android build/pet-idle.apk`: export failed due missing templates/SDKs; `build/pet-idle.apk` absent (2026-10-15).

## Exact next action for the next session
- After installing the Android prerequisites above, run the documented debug export and test it on a portrait Android device. Get decisions on the marked provisional balance/targeting rules before final tuning.
