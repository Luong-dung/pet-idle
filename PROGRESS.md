# PET IDLE progress

## Current status and last verified commit
- Playable core implementation on `main`; checkpoint commit pending. Prior verified commit `82c3cc7`.

## Completed milestones (with tests)
- Foundation/core gameplay: Godot project, centralized 36-identity roster, three free rooms, six currencies, assignment/production, offline cap, versioned save/load, 27-tier merge, four gacha banners, book shop/equipment, independent collections, and functional six-screen portrait UI. `tests/test_game.gd`: 233 checks passed; headless main scene startup passed.

## In progress
- Visual polish, save validation hardening, Android export setup, and integration checks.

## Remaining milestones
- Original character portraits/visual feedback, Android portrait/export configuration, manual layout inspection, stronger malformed-save checks, final regression and documentation.

## Known bugs / blockers
- Android SDK/export-template availability has not been checked. Godot prints a host certificate-store warning in sandboxed headless runs; game tests still pass.

## PROVISIONAL assumptions / unresolved design questions
- Starting state: one F- gold pet in three free rooms and no starting currency. This allows gold generation without creating free gacha pulls.
- Character names/matched pairs require original authoring; use three aligned identities per system.
- All employee identities share the confirmed 10-second F- reduction until differentiated balance is approved.
- Book catalog: one pet and one employee book per system, each full four-copy stack gives +100% to output/reduction. Purchase currency is its system resource. Both are PROVISIONAL pending approved catalog/currency.
- Book prices use exact integer ceil after each 10% increase. Resource balances retain fractional units; UI rounds to one decimal. PROVISIONAL rounding policy.
- Foreign collection skill is the only foreign-system equipment; it adds +50% of native output or innate reduction, additively with native book effects. PROVISIONAL interaction.
- Employee reduction is subtracted from base cycle, then matching-pair 0.9 time multiplier; cycle is guarded at 1 second. PROVISIONAL order/floor.
- Essence, components and fashion have no speculative sinks; their pets produce them and same-system books spend them.

## Test/build commands and last results
- `godot --headless --path . --script res://tests/test_game.gd` with sandbox-writable `APPDATA`: 233 checks, 0 failures (2026-10-14).
- `godot --headless --path . --quit-after 5` with sandbox-writable `APPDATA`: exit 0, no script errors (2026-10-14).

## Exact next action for the next session
- Add original procedural character portraits and a clearer room/character presentation, validate in Godot, then prepare Android export config and check SDK/templates.
