# Codex Instructions — PET IDLE

You are the autonomous implementation agent for **PET IDLE**, a Godot 4.x / GDScript offline Android portrait idle game.

## Source of truth

1. Read `GAME_DESIGN.md` in full before planning or changing gameplay.
2. Treat **confirmed rules** in that file as binding. Do not silently add game mechanics or reinterpret ambiguous rules.
3. `PROGRESS.md` tracks work, assumptions, tests, blockers and next actions. **Create it if missing** and update it at every checkpoint.
4. This file governs workflow; `GAME_DESIGN.md` governs gameplay. If they conflict on game mechanics, the design wins.

## Mission

Implement a complete playable MVP with clean architecture, persistent saves, deterministic/testable gameplay logic, a touch-friendly attractive interface, and a Godot project that can be exported for Android. Work autonomously through modules without repeatedly asking the user to approve routine engineering decisions. Prioritize correctness and continuity over large unverified code dumps.

## Before each session

1. Inspect repository tree, `git status`, `git log -5 --oneline`, `GAME_DESIGN.md`, and `PROGRESS.md` if present.
2. Identify implemented functionality and run the existing tests/smoke checks before modifying it.
3. Preserve user changes. Do not reset, overwrite, or discard uncommitted work without explicit authorization.
4. Choose the smallest coherent next milestone and record the plan in `PROGRESS.md`.
5. If a prior run stopped unexpectedly, inspect the working tree and unfinished changes before resuming.

## Architecture and quality

- Godot 4.x, GDScript, no backend or online dependencies.
- Separate pure gameplay/data rules from UI scenes: resource/character definitions, rank/merge, gacha, rooms/production, inventory/equipment, collection, save/load.
- Use stable unique IDs for character instances, book copies, rooms and inventory records.
- Keep all balance values in centralized data/config instead of scattering magic numbers through scenes.
- Use consistent units (seconds, resource quantities), validated input, and explicit rounding.
- Handle 24-hour offline accrual without per-tick simulation, double-crediting, negative time, or save corruption.
- Ensure inventory merges cannot lose equipped books or corrupt room references.
- Build for portrait touch input; avoid UI that only works with mouse hover.
- Use placeholders or original programmatic art where necessary; never rely on unavailable copyrighted/paid assets.
- Do not implement speculative systems (room upgrades, essence upgrades, cosmetics, etc.) as finalized rules.

## Open questions and assumptions

`GAME_DESIGN.md` explicitly marks unresolved decisions. For each:

- Do not describe a guess as an approved rule.
- If a decision blocks the playable MVP (e.g. starting pet/currency), choose the **smallest reversible provisional default**, implement it in centralized configuration, and clearly label it `PROVISIONAL` in `PROGRESS.md`.
- If it does not block core play, leave a well-defined extension point and log the pending question.
- Never change confirmed odds, costs, slot limits, rank logic or system restrictions to make implementation easier.

## Continuous checkpoint discipline

**Do not wait until the entire game is finished to save progress.**

After each coherent, tested milestone:

1. Run relevant tests, Godot headless parse/import/smoke checks where available, and inspect errors.
2. Update `PROGRESS.md` with completed work, files touched, commands/tests/results, known issues, provisional assumptions, and the precise next step.
3. Commit the milestone and progress file together using a descriptive commit message.
4. If a Git remote exists and push credentials/permissions are available, push the commit. If push fails, record the reason; **a local commit is not a remote backup**.
5. Continue with the next milestone while capacity permits.

If interrupted by token/context limits or usage quota, the repository plus `PROGRESS.md` must be sufficient for a new session to resume. A quota interruption can occur without warning, so make checkpoints frequently. Do not claim a commit, push, build, or test succeeded unless its tool result confirms success.

## Suggested implementation milestones

1. Project scaffold, data models, core navigation, `PROGRESS.md`, smoke test.
2. Six resources, 36 unique character identities, room assignment, production and offline/save logic.
3. Rank tiers, duplicate merge/evolution, stat scaling and safe inventory reference handling.
4. Four gacha banners, odds, 1/10/100 packages, balance deductions and tests.
5. Book inventory/shop, skill slots, stacking, independent pet/employee collections, foreign skill constraints.
6. UI polish, error states, animations, Android portrait/export configuration, full regression tests.

Milestones may be subdivided as needed. Do not leave critical features untested merely to reach a milestone count.

## Test expectations

At minimum test:

- Exact room costs and free-room count.
- Pet-only production, employee matching restrictions, duplicate assignment prevention, and matching-pair bonuses.
- Production timing, offline cap, partial cycles, save/load idempotency.
- 27 tiers, `2/2/3` merges, `1.1` per tier, skill slot progression.
- Book ownership, repeated-copy effectiveness, max two systems/four per system, no duplicate collection buff.
- Gacha probability table integrity, cost, 10→11 and 100→111, excluded A/SSS ranks.
- New-game bootstrap, invalid operations, malformed saves, and no negative balances.

Use reproducible unit tests for deterministic logic; statistical sampling may supplement but must not replace direct checks of the configured probability tables.

## `PROGRESS.md` required structure

Maintain sections:

- Current status and last verified commit
- Completed milestones (with tests)
- In progress
- Remaining milestones
- Known bugs / blockers
- **PROVISIONAL assumptions / unresolved design questions**
- Test/build commands and last results
- Exact next action for the next session

Keep entries concise but operationally precise. Mark only genuinely implemented/tested items complete.

## Git and environment safety

- Work in the existing repository and branch; do not create a new unrelated project.
- Never use destructive Git commands (`reset --hard`, force push, broad `clean`) unless explicitly authorized.
- Never commit secrets, credentials, generated cache folders, huge build artifacts or machine-local SDK paths.
- Use `.gitignore` suitable for Godot 4 (`.godot/`, build/export artifacts, etc.).
- If Android SDK/export templates are missing, prepare export configuration where possible, document missing prerequisites and still deliver a desktop/headless-testable Godot project. Do not falsely claim an APK was built.
- At session end, summarize actual implemented features, tests, commit hash, push status, and blockers.

## Definition of done

A user can open the Godot project, play the resource/room/gacha/evolution/books/collection loop, quit and resume with correct offline progress, and interact with a coherent portrait UI. Automated tests cover key rules; documented limitations remain explicit; the latest code is committed and, where available, pushed to the configured remote.
