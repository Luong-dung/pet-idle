# PET IDLE — Game Design Specification

**Status:** Working specification, 2026-10-14  
**Target:** Godot 4.x, GDScript, offline Android, portrait orientation.  
**Priority:** Correct rules, reliable offline saves, playable MVP, then attractive cute/pixel-inspired UI.  
**Authority:** This document is the source of truth for confirmed gameplay rules. Do not silently invent mechanics to fill gaps. See **Open decisions**.

## 1. Core loop

A lightweight, single-player, offline idle room-management game. Place one pet in a room to generate its resource periodically; optionally assign a compatible employee to reduce the production cycle. Earn resources, unlock more rooms, draw characters through gacha, merge duplicates to improve ranks, and equip skill books. There is no multiplayer, combat, server, world exploration, or complex construction system.

## 2. Resource systems

Exactly six independent systems:

| ID | Display name (Vietnamese) | Purpose |
|---|---|---|
| gold | Vàng | Normal gacha and room unlocks |
| crystal | Tinh thể | VIP gacha |
| essence | Tinh hoa | Intended for upgrades; exact spending mechanic not defined |
| knowledge | Tri thức | Skill books |
| components | Linh kiện | Intended for room upgrades; room-upgrade mechanic not defined |
| fashion | Thời trang | Cosmetic skins, later phase |

Each pet and employee belongs to exactly one native system, and character identities/names must be unique across systems. A pet normally generates its native system's resource. An equipped foreign pet collection skill also produces its selected foreign resource in the same room cycle; this is additional production, not resource conversion.

## 3. Character roster and rooms

- **18 pet identities**: three distinct pets per system.
- **18 employee identities**: three distinct employees per system.
- Every room can hold **at most one pet and one employee**. A pet can work alone. An employee without a pet produces nothing.
- A room's employee must belong to the **same resource system** as its pet.
- A character instance may be assigned to **only one room** at a time.
- Each system has **three predefined matching pet–employee identity pairs**. When the matching pair is assigned together, production output receives **+10%** and production cycle time receives **-10%** (multiplicative time modifier). Ordinary same-system pairs have no matching bonus.
- Initial rooms: **three free rooms**. Additional rooms have no hard maximum and cost gold. Room number 4 costs 2,000 gold; each subsequent room costs 20% more, rounded up: `cost(room_n) = ceil(2000 * 1.2^(n-4))` for `n >= 4`. Ensure safe handling for extreme room counts/overflow.
- Initial **sample** pet production profiles per resource system: `100 units / 100 seconds`, `50 units / 60 seconds`, `20 units / 30 seconds`. Use these as initial roster defaults, not an instruction to randomize stats.
- Employees begin with innate reduction of **10 seconds at F-**, scaling with rank. Their exact identity-specific differences have not been defined; do not invent materially different balance without recording the decision.
- Pet/employee/skill-book copies cannot be sold.

## 4. Idle production and offline progression

- Resources are credited on completed production cycles, with correct fractional cycle progress retained.
- While the app is open, production advances using elapsed time.
- On resume/load, grant at most **24 hours** of elapsed offline production, then stop accumulating beyond that cap. Avoid double-crediting on repeated resume or load.
- Persist resource balances, room unlocks, assignments, inventory, ranks, equipped books, collections, purchases, and timing/progress state.
- Save atomically where practical, version the save schema, validate loaded data, and recover safely from corrupt/missing saves.
- Prevent nonpositive cycle times. The exact minimum cycle duration has **not** been approved; use a clearly documented temporary safety floor (e.g. 1 second) only as an implementation guard, not a new gameplay rule.
- Prefer a mathematically equivalent batched offline calculation rather than simulating every individual tick/cycle.

## 5. Rank and evolution

Nine major ranks, each with three subtiers (`-`, neutral, `+`), for **27 ordered tiers**:

`F-, F, F+, E-, E, E+, D-, D, D+, C-, C, C+, B-, B, B+, A-, A, A+, S-, S, S+, SS-, SS, SS+, SSS-, SSS, SSS+`.

- Merge requires copies with the **same identity, category (pet/employee), resource system, and exact rank tier**.
- `- -> neutral`: consume **2** copies of the same tier, produce one next-tier copy.
- `neutral -> +`: consume **2** copies, produce one next-tier copy.
- `+ -> next major -`: consume **3** copies, produce one next-tier copy.
- There is no next tier beyond `SSS+`; do not allow merging it.
- **Each one-tier increase** multiplies the character's innate numerical strength by `1.1`, including transitions from `+` to the next major `-`. For a pet, scale **base output X**, not base cycle duration Y. For an employee, scale the magnitude of innate cooldown reduction (10 seconds at F-).
- Major-rank skill-slot counts: `F=0, E=1, D=2, C=3, B=4, A=5, S=6, SS=7, SSS=8`. Unlock one additional slot on each major promotion, including a `+ -> next major -` transition.
- **SSS is obtainable only through merging**, never from gacha.
- Merging consumes duplicate instances. Preserve equipment safely: do not delete equipped books or leave broken room assignments; detach/return equipment and resolve affected assignments before consuming instances.

## 6. Skill books and slots

- Pet books improve **production output**, not production speed.
- Employee books improve the employee's **cooldown-reduction effect**, not production output.
- Each book is an individual owned item; one physical copy cannot be equipped by multiple characters at once.
- Up to **two skill systems** per character: the character's native system and **at most one** unlocked foreign system.
- At most **four occupied slots per system**, and no more than the character's total unlocked slots. Thus an SSS character may use a `4+4` split.
- Repeated copies of an **identical skill book** in 1/2/3/4 slots provide respectively **10% / 30% / 60% / 100%** of that book's full designated effect, according to the intended stacking schedule. The schedule is **total effectiveness at that copy count**, not four independent multiplicative effects.
- Employee example: if base innate reduction is 10 seconds and an employee-book effect is configured to amplify that reduction, then with 0/1/2/3/4 matching books the total reduction is `10 / 11 / 13 / 16 / 20` seconds, respectively (before other effects).
- Pet-book magnitudes and precise book catalog are **not fully finalized**. Historical ideas included flat and percentage books; do not silently treat them as finalized mechanics. Make effect definitions data-driven and flag the ambiguity in `PROGRESS.md`.
- Skill-book store: the first book purchase **in each resource system** costs 1,000 units; subsequent purchases in that same system increase by 10%, using separate per-system purchase counters. Pricing should use an explicit deterministic rounding policy. The **payment currency per system** was suggested to be that system's resource but has not been explicitly confirmed; see Open decisions.
- No resale of books.

## 7. Collection unlocks and foreign skills

- Pet collection and employee collection are **independent**.
- The **first acquired pet** of a given resource system permanently unlocks that system in the **pet collection**. Additional pets of that system do not unlock it again. The same rule applies independently to employee collection.
- Once a foreign system is unlocked in the relevant collection, a character may equip its **basic collection skill** as the single allowed foreign system.
- Collection skill uses **one normal skill slot** and cannot be equipped repeatedly to stack the same 50% effect.
- **Pet foreign collection skill:** produces the selected foreign resource at **50% of the pet's rank-scaled base output X** in each room cycle. The native resource output remains separate.
- **Employee foreign collection skill:** 50% effectiveness applied to the employee's time-reduction ability; exact interaction with other employee-book effects should be made explicit before final balance tuning.
- A book belonging to system `H` affects **only system H**. Do not globally apply books of one system to another system or conflate the collection skill with a regular book.
- Pet books affect only output of their own resource system. The precise magnitude interaction of foreign books with the foreign collection skill is not fully specified; document the provisional implementation. Do not add foreign-system employee production mechanics.

## 8. Calculation rules

- Rank-scaled base pet output: `X_rank = X_Fminus * 1.1^(tier_index)`.
- Rank-scaled base employee innate time reduction: `R_rank = 10 * 1.1^(tier_index)` seconds.
- **Percentage output buffs within one resource system are additive**, then applied once, plus any explicitly defined flat additions. Example: +20% native pet book and +10% matched pair give native output `X_rank * 1.3`, **not** `X_rank * 1.2 * 1.1`. Foreign collection output is a separate resource entry.
- Employee reduction bonuses combine additively according to their definitions before subtracting from cycle time. Matching-pair time bonus is **-10% cycle time**; document operation order and test it consistently.
- Avoid rounding internal calculations prematurely; round for UI display and define a deterministic policy for crediting fractional resource units.
- A character's rank never changes its pet's base Y directly.

## 9. Gacha

Four separate banners:

| Banner | Currency | Price per paid pull | Eligible major ranks |
|---|---|---:|---|
| Normal pet | Gold | 1,000 | F, E, D, C, B |
| Normal employee | Gold | 1,000 | F, E, D, C, B |
| VIP pet | Crystal | 30,000 | S, SS |
| VIP employee | Crystal | 30,000 | S, SS |

- **Fixed prices forever**: no increasing gacha price based on prior pulls.
- Normal major-rank odds: **F 35%, E 28%, D 20%, C 12%, B 5%**.
- VIP major-rank odds: **S 90%, SS 10%**.
- Conditional subtier odds within each major rank: **`-` 60%, neutral 30%, `+` 10%**.
- VIP concrete odds: `S- 54%, S 27%, S+ 9%, SS- 6%, SS 3%, SS+ 1%`.
- Packages: **1 paid -> 1 total**, **10 paid -> 11 total**, **100 paid -> 111 total**. Charge for paid pulls only; bonus draws use identical probabilities.
- Normal costs: 1,000 / 10,000 / 100,000 gold. VIP costs: 30,000 / 300,000 / 3,000,000 crystal.
- No pity system, no SSS pulls. Rank **A** is not in either gacha and must be reached via evolution.
- Character identity selection within a drawn tier has not been specified; use a transparent provisional uniform distribution across eligible identities unless user decides otherwise.
- Keep RNG, rate tables, and bulk-draw logic testable independently of the UI.

## 10. UI and UX

- Android portrait, touch-first controls; cute, polished, pastel/pixel-inspired aesthetic. No external paid assets required.
- Screens should include: **Rooms**, **Inventory/Characters**, **Gacha**, **Skill-book Shop**, **Collection**, and appropriate character detail/evolution/equipment dialogs.
- Clearly show six resource balances, production amounts and countdowns, assigned pet/employee, rank, available slots, and book effects.
- Explain why invalid actions are blocked (wrong system, no slot, insufficient currency, missing copies, already assigned, etc.).
- Make layouts usable on typical Android portrait screens and test with Godot's stretch/scaling behavior.
- Cosmetics are a later-phase feature; do not block the MVP on art assets or unfinalized skin rules.

## 11. Out of scope / do not invent

- No online backend, accounts, multiplayer, PvP, combat, map exploration, ads, IAP, or monetization unless later requested.
- No selling pets, employees, or books.
- No pity, no gacha price escalation, no random cross-system character identity reuse.
- No room-upgrade or essence-upgrade mechanics without further specification.
- Do not invent extra currencies, energy bars, daily login rewards, or a prestige system.

## 12. Open decisions requiring explicit treatment

These are **not approved game rules**. Record assumptions in `PROGRESS.md`, keep them easy to change, and seek clarification when possible. Do not stall unrelated implementation.

1. **Starting state / softlock prevention:** three rooms are free, but initial pet(s), employee(s), and currency balances were not decided. Ensure a playable bootstrap without presenting a new rule as confirmed.
2. **Names, visual identities and matched pairs:** 18 pet names, 18 employee names, three matching pairs per system need authoring; they must remain unique across systems.
3. **Skill-book catalog:** exact pet/employee book effects and magnitudes, flat vs percent effects, and purchase currency per system are not finalized.
4. **Collection + foreign book interactions:** foreign pet resource targeting is confirmed; exact foreign book magnitude interaction, whether matching-pair output bonus affects foreign output, and employee 50% formula still need final balance approval.
5. **Cycle time safety floor, rounding, and order of time modifiers:** implementation safeguards must be documented and tested.
6. **Use of Essence/Components/Fashion:** their intended future sinks are known, but concrete upgrade/cosmetic mechanics are not yet designed.
7. **Initial roster balancing:** pet production examples are defined; employee identity-level stat differentiation is not.

## 13. Acceptance checks

- Three rooms available on new save; room 4 unlocks for 2,000 gold and subsequent prices rise 20%.
- A pet alone produces; employee from another system cannot be assigned; one instance cannot be in two rooms.
- Matching identity pair grants +10% output and -10% time.
- Save/reload does not duplicate earnings; 30 hours offline credits at most 24 hours.
- Correct 27-tier order, exact merge requirements and `1.1^tier_index` stat growth.
- Slot count matches major rank and max two systems/four slots per system is enforced.
- Collection unlocks independently for pets/employees, uses one slot, and 50% bonus does not stack by duplicate collection equips.
- All four banners, probabilities, 1/10/100 packages, and fixed prices are tested.
- No gacha ever produces A or SSS; A is obtainable through merging B+, SSS through merging SS+.
- No pets, employees or books can be sold.
