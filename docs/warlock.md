# Warlock — Design Doc

Status: **design only (not implemented)**  
Last updated: 2026-07-25  
Role: mid-range glass cannon whose **mana** is a deep, non-regenerating well — power comes from **drawing** into the Draw skill’s bank before you fire.

Contrast: [Warrior](warrior.md) regenerates stamina every turn and shares it between attack and soak. Warlock never refills mana passively; empty is a lasting problem for that battle.

---

## Fantasy & job

The Warlock fights from mid range with a finite mana pool. Before a real strike, they **Draw** mana out of the well and **bank it on the Draw skill** (that ability’s instance state). Casts do **not** receive Draws directly — they spend from the Draw bank when fired. How much sits in the bank is the commitment — overdraw and later turns go dry; underdraw and the hit is soft. When the well runs dry, dignity follows: they can still **Fist Fight** — pathetic melee flailing, not a spell.


| Pillar            | Intent                                                                                     |
| ----------------- | ------------------------------------------------------------------------------------------ |
| Finite well       | Deep mana, **no** turn-start / passive regen                                               |
| Draw → bank       | Well → **Draw skill state** only; never drawn straight into a cast                         |
| Casts cost bank   | **Most spells dump the whole Draw bank** into the cast (not a partial sip)                 |
| Overload          | Past a per-ability threshold, each spell changes in its **own** way — effect unlocks when bank hits that threshold |
| Dry is punishment | Empty well / empty bank → only **Fist Fight**; the joke is on you                          |


### Baseline advantages


| Advantage          | Why it matters                                                 |
| ------------------ | -------------------------------------------------------------- |
| High reach         | Mid-range glass cannon — can threaten before melee closes      |
| Scalable burst     | Committed mana turns one action into a fight-swinging hit      |
| Panic shield       | Mana Shield eats one hit — or Overload soak for up to **3 unit turns** / until own turn |
| Always has a basic | Dry → **Fist Fight** — still acts, in the saddest way possible |
| Deep pool          | ~100 mana supports several meaningful charges if rationed      |


### Baseline disadvantages


| Disadvantage               | Why it matters                                                           |
| -------------------------- | ------------------------------------------------------------------------ |
| No mana regen              | Every Draw is permanent for the battle — no Warrior-style recovery       |
| Fragile                    | Low HP — mistakes and focus fire end the unit                            |
| Short legs                 | Low–Mid move — needs positioning help; kiting hurts                      |
| Commitment is irreversible | Drawn mana leaves the well permanently — you cannot un-commit mid-battle |
| Empty = irrelevant         | Dry Warlock is a melee slapstick act, not a backline threat              |


---

## Architecture

Warlock is **not** a code subclass. Identity comes from spawn data + ability kit (same pattern as Warrior):

```
UnitStats
  ├── core combat stats (HP, damage, speed, move_range, …)
  ├── resource_id = MANA, max_resource = 100
  └── abilities[]
        ├── SimpleMoveAbilityData              (Walk)
        ├── WarlockFistFightAbilityData        (Fist Fight — dry / free melee flop)
        ├── WarlockDrawManaAbilityData         (Draw — banks drawn mana on itself)
        ├── WarlockManaShieldAbilityData       (Mana Shield — block hits; may Overload)
        └── WarlockChargedBoltAbilityData      (Charged Bolt — spends Draw bank; may Overload)
```


| Layer                     | Owns                                                                |
| ------------------------- | ------------------------------------------------------------------- |
| `Unit`                    | Generic resource API (`get` / `spend` / `gain` / `refill`)          |
| `UnitStats` / spawn setup | Class defaults (MANA, max 100, ability list)                        |
| **Draw ability**          | Pulls from the well into **its own** `drawn_mana` bank              |
| Cast abilities            | Require `mana_cost`; **default: spend entire Draw bank**; Overload  |
| Mana Shield               | Raise via ACTION; block via `on_incoming_damage` while active       |
| Fist Fight ability        | Free melee desperation attack; independent of Draw bank             |
| `CombatSystem`            | Hit/damage math (unchanged by class; Fist Fight passes a miss rule) |


**Do not** put Warlock-only draw/bank logic on `Unit` or in battle systems. Keep kits swappable by swapping ability resources.

### Ability-state bank (important)

`Unit.setup` **duplicates** each `AbilityData` per unit instance. **Prototype:** the single Draw ability holds the bank:

```
WarlockDrawManaAbilityData (per-unit instance)
  ├── drawn_mana: int          # banked by Draw; spent by cast abilities
  └── max_drawn_mana: int      # hard cap on the bank (default **20**)

WarlockChargedBoltAbilityData (per-unit instance)
  ├── mana_cost: int           # minimum drawn mana required to cast
  └── overload_threshold: int  # drawn amount used/available above this → Overload
```

Flow:

1. Draw: if `drawn_mana + draw_amount <= max_drawn_mana` and well has enough → `spend_resource(draw_amount, MANA)` → `draw.drawn_mana += draw_amount`
2. Cast (**default**): require `draw.drawn_mana >= mana_cost` → `spent = drawn_mana` → resolve normal or Overload → **`drawn_mana = 0`** (whole bank)

**Default spend rule:** most Warlock cast skills **consume the entire Draw bank** when fired. `mana_cost` is only the **minimum** to activate. Effect scaling / Overload use the full `spent` amount. Opt-out only for rare future skills that explicitly sip a fixed cost and leave the rest.

**Never** Draw directly into Charged Bolt (or any other cast). Casts resolve the bank through a **Draw-bank provider**, not by hard-coding one ability `id` forever.

**Bank cap:** `max_drawn_mana = 20` (prototype). Draw disables when the next tick would exceed the cap (or when well is empty).

### Future: different Draw skills

Expect multiple Draw variants later (e.g. slow big Draw, risky Draw, alternate channel).

**Resolved:** every Draw verb deposits into the **default Draw** ability’s bank — not its own.

| Piece | Rule |
| ----- | ---- |
| **Default Draw** (`warlock_draw_mana` or marked default) | Owns `drawn_mana` + `max_drawn_mana`; this is the only bank |
| **Alternate Draws** | Different `draw_amount` / risks / side effects, but `+=` into the **default** bank |
| **Casts** | Always read/spend the **default** bank |

Impl: alternate Draws look up the default Draw-bank provider on the unit and call `add_drawn` there. Do **not** give each Draw variant its own `drawn_mana`. Casts keep resolving through that same default provider.

**Prototype rule:** one Draw ability, bank on that skill, **`max_drawn_mana = 20`**. **Impl rule:** resolve bank via “default Draw-bank provider,” not scattered per-Draw state.

---

## Baseline stats

Proposed spawn defaults (tune freely — pool depth is a balancing knob):


| Stat                | Value    | Band / notes                                                                                                      |
| ------------------- | -------- | ----------------------------------------------------------------------------------------------------------------- |
| Speed               | 5        | Mid initiative                                                                                                    |
| Move range          | 3        | Low — glass backliner, not a skirmisher                                                                           |
| Accuracy            | 100      | Deterministic hits before cover/falloff                                                                           |
| Damage              | 8        | **Fist Fight** punch damage; Charged Bolt scales from Draw bank                                                   |
| Max HP              | 75       | Low — Sniper-like fragility                                                                                       |
| Resource            | Mana 100 | Starts full; **no** passive recharge                                                                              |
| Attack range        | 4        | Mid-range identity (High enough to threaten; shorter than pure sniper 5 if we want a clearer mid band — tune 4–5) |
| Move/action budgets | 1 / 1    | Same as other units                                                                                               |


Compared to Warrior: no shared shield resource, no regen, ranged instead of melee, fragile instead of bruiser. Compared to Scout/Sniper shooters: similar reach band, but damage is gated by Draw commitment rather than a flat shot every turn.

---

## Mana economy

Mana is a single pool (`BattleEnums.UnitResource.MANA`).

### Spends


| Event                           | Cost                                                   | Source                                  |
| ------------------------------- | ------------------------------------------------------ | --------------------------------------- |
| Draw                            | **`draw_amount`** (default **5**) from well            | Well → **Draw skill** `drawn_mana`      |
| Charged Bolt (and most casts)   | **Entire** Draw bank (must be ≥ `mana_cost`)           | Dump bank into the spell — **not** the well |
| Mana Shield                     | **Entire** Draw bank (must be ≥ `mana_cost`)           | Same dump rule; raises shield state     |
| Fist Fight                      | **0**                                                  | Always (the humiliation option)         |


### Gains


| Event        | Amount                | Source       |
| ------------ | --------------------- | ------------ |
| Battle start | Full (`max_resource`) | `Unit.setup` |
| Turn start   | **None**              | By design    |


No stamina-style recharge passive. Any future refill is an explicit ability or item, not a turn tick.

### Soft caps & feel

- Full mana **100** ≈ many Draws over the battle, but the **bank caps at 20** (4× Draw of 5).
- Typical charged hit: Draw up toward the cap (e.g. 15–20) → fire; Overload is reachable under the cap.
- **Bank cap `max_drawn_mana = 20`** — commitment is still a choice, but one cast cannot eat the whole well.
- Unused `drawn_mana` **persists across turns** on the Draw skill until a cast spends it.
- Empty well → Draw disabled; bank full → Draw disabled; casts only if Draw bank ≥ `mana_cost`; otherwise **Fist Fight** (if someone is adjacent).
- Overhead HUD: mana bar under HP (HUD already has a MANA tint path).

**Design tension:** every Draw permanently shrinks the well. Banking high commitment wins a fight early (and may Overload) and risks a useless late game; hoarding keeps options open but never spikes. Warrior asks “attack or soak this turn?”; Warlock asks “how much of this battle do I spend *now*?”

---

## Abilities

### Walk — `simple_move`

Shared move ability. Pathfinding + Chebyshev neighbors. Costs the **move** slot.

### Draw — `warlock_draw_mana`


| Field                | Value                                                                     |
| -------------------- | ------------------------------------------------------------------------- |
| Category / cost slot | `ACTION` / **`NONE`** (free — does not spend move or action)              |
| Target               | Self / no cast target — banks onto **this** ability only                  |
| Gate                 | `current_mana >= draw_amount` and `drawn_mana + draw_amount <= max_drawn_mana` |
| Commit               | `spend_resource(draw_amount, MANA)` then `self.drawn_mana += draw_amount` |

Default `draw_amount = 5`, `max_drawn_mana = 20`. Fine-grained banking steps. Owns `drawn_mana` runtime state. **Bank persists across turns** until a cast spends it (does not clear on turn end / turn start).

`can_activate`: enough well mana **and** room under the bank cap. **Does not** require `can_act_more` — Draw is free setup on your turn.

**Same-turn flow:** Draw (repeatable while well and cap allow) → then spend the ACTION on a cast — or, if you’ve ruined yourself, Fist Fight. The bank lives on Draw; casts only read/spend it.

### Overload (all Warlock cast abilities)

When a cast resolves, compare the **drawn amount being spent** (from the Draw bank) to that cast’s **`overload_threshold`** (per-ability number, designer-facing).


| State        | Condition                                        | Intent                                                               |
| ------------ | ------------------------------------------------ | -------------------------------------------------------------------- |
| Normal       | `mana_cost <= spent_drawn <= overload_threshold` | Baseline spell behavior (what the player-facing text describes)      |
| **Overload** | `spent_drawn > overload_threshold`               | **Different behavior per skill** — not a single shared Overload rule |


Overload is **not** the same as the bank cap. The bank hard-stops at `max_drawn_mana` (20); within that range, spending past a spell’s `overload_threshold` still flips that spell into Overload mode.

**Per-skill variance:** Charged Bolt’s Overload is not the same as a future curse/AoE/etc. Each cast ability defines its own Overload outcome (extra damage, splash, self-risk, altered targeting, …).

**Discovery / unlock (player-facing):**

- **Before unlock:** tooltips and descriptions show only the **normal** cast — no Overload name, no threshold number, no Overload effect text.
- **Unlock condition:** when the Draw bank **reaches that ability’s** `overload_threshold` (`drawn_mana >= overload_threshold`) for the first time, that ability’s Overload effect **unlocks** in its tooltip/description. (Cast Overload still uses `spent_drawn > overload_threshold` — unlocking at equality lets the player read the effect just as they hit the line, before going over.)
- Unlock is **per ability** (Charged Bolt unlock does not reveal a future curse’s Overload).
- **Persistence:** once unlocked for an ability, it stays revealed (lean: for the rest of the run / save — tune later). Reaching the threshold is enough; the player does **not** have to cast Overload first.
- UI may always show **well mana** and **Draw bank**. It should not advertise the numeric threshold before unlock; after unlock, showing that you are in Overload range is fine.

Authoritative Overload effects still live in design/impl notes; player text only appears after unlock.

### Charged Bolt — `warlock_charged_bolt`


| Field                | Value                                                                                                   |
| -------------------- | ------------------------------------------------------------------------------------------------------- |
| Category / cost slot | `ACTION` / `ACTION`                                                                                     |
| `attack_range`       | **4** (tune 4–5)                                                                                        |
| Drawn-mana cost      | Requires `drawn_mana >= mana_cost`; **spends the whole bank** (`drawn_mana → 0`)            |
| `mana_cost`          | Proposed **5** (one Draw minimum to fire)                                                   |
| `overload_threshold` | Proposed **15** (must be **&lt; max_drawn_mana** so Overload is reachable under the 20 cap) |
| Distance falloff     | Same pattern as other shots (`distance_penalty_per_tile`)                                   |
| Commit               | `spent = drawn_mana` → normal or Overload → `drawn_mana = 0`                                |


**Does not** store its own commit bank. Looks up `warlock_draw_mana` on the unit.

**Damage scaling (starting formula — balance later):**

```
damage = floor(spent_drawn * damage_per_mana)
```

Suggested default `damage_per_mana = 1.0` → 5 drawn ≈ 5 dmg, 20 ≈ 20, 40 ≈ 40. Overload may replace or modify this formula rather than only scaling the number.

Unit `damage` stat is **not** the primary lever for Charged Bolt; the Draw bank is.

### Mana Shield — `warlock_mana_shield`

Self buff. Spends the Draw bank to raise an occult barrier. Contrast Warrior stamina soak (partial, 1:1 with stamina): this shield **fully nullifies** the blocked hit — **no leftover damage to HP**.

| Field                | Value                                                                                         |
| -------------------- | --------------------------------------------------------------------------------------------- |
| Category / cost slot | `ACTION` / `ACTION`                                                                           |
| Target               | Self                                                                                          |
| Drawn-mana cost      | Requires `drawn_mana >= mana_cost`; **spends the whole bank** (`drawn_mana → 0`)              |
| `mana_cost`          | Proposed **5**                                                                                |
| `overload_threshold` | Proposed **15** (keep **&lt; max_drawn_mana**)                                                |
| Commit               | `spent = drawn_mana` → raise shield (normal or Overload) → `drawn_mana = 0`                   |

**Runtime state (on this ability instance):**

```
active: bool
charges: int              # normal: 1; Overload: unused (duration mode instead)
remaining_unit_turns: int # Overload: countdown (default **3**)
```

#### Normal (spent ≤ threshold)

- Raise shield with **`charges = 1`**.
- On a hit that would apply damage (`on_incoming_damage`): set `final_damage = 0`, then `charges -= 1` → shield down when charges hit 0.
- **Blocks one attack no matter the damage.** Excess does **not** carry over to HP (there is no excess — the whole hit is negated).
- Misses never touch this path (same as Warrior shield).

#### Overload (spent > threshold) — discovery-gated like other Overloads

- Raise shield with **`remaining_unit_turns = 3`** (no single-charge limit).
- Blocks **every** incoming damaging hit the same way (full negate, no HP carryover) while active.
- **Expires on whichever comes first:**
  1. **3 unit turns** — each time **any other** unit’s turn starts, decrement `remaining_unit_turns`; at 0, clear the shield.
  2. **Warlock’s own turn start** — clear the shield immediately when the raiser’s turn begins (so it never carries into their next action).
- If already shielded and you cast again: refresh / replace with the new mode (prototype: replace).

**Impl note:** `Unit.modify_incoming_damage` currently dispatches **PASSIVE** abilities. Mana Shield needs those hooks while raised — either allow this ACTION ability’s hooks when `active`, or pair with a thin PASSIVE that reads this ability’s state. Prefer one resource that owns raise + block state. Duration needs both a global “other unit turn start” tick and the Warlock’s `on_turn_started` clear.

**Player-facing (before Overload unlock):** describe only the one-hit full block. Overload “lasts up to 3 unit turns, or until your next turn” unlocks when Draw bank hits this ability’s threshold.

### Fist Fight — `warlock_fist_fight`


| Field                | Value                                                                                                   |
| -------------------- | ------------------------------------------------------------------------------------------------------- |
| Category / cost slot | `ACTION` / `ACTION`                                                                                     |
| `attack_range`       | **1** (adjacent only, Chebyshev — diagonals count)                                                      |
| Mana / Draw bank     | **None** — never touches well or Draw bank                                                              |
| Hit chance           | **50% to miss** (flat) — intentional exception to the usual 100% base accuracy                          |
| Damage               | Unit `damage` (default **8**) — a sad little punch                                                      |
| Full cover           | Same as Warrior melee lean: cannot punch someone in directional full cover (optional; funny either way) |


The dry-out “basic.” Not a spell. The Warlock has run out of occult dignity and is throwing hands. Should feel clearly worse than even a light committed cast: melee-only, coin-flip miss, low damage. Not subject to Overload.

**Tone:** play it for comedy in presentation (name, log line, maybe a pathetic punch tween) — the mechanical joke is the range + miss rate.

---

## Combat positioning

- Range uses **Chebyshev** (project grid rule).
- Wants mid-distance sight lines and cover; dies quickly if Warriors/Scouts close.
- Half/full cover reduce hit chance as usual; no Warrior-style “cannot melee full cover” rule unless we add one later.
- Draw does not move or deal damage — pure free economy; action stays available for the bolt.

Typical loop:

1. Move into mid-range cover
2. Draw one or more times (−5 well → +5 on **Draw bank**) — free
3. Charged Bolt **or** Mana Shield (ACTION; dumps Draw bank; Overload if over that spell’s threshold)
4. Repeat while mana lasts; when empty, close to melee and **Fist Fight** (or hide and cry)

Defensive line: Draw to shield threshold → Mana Shield (one big hit eaten, or Overload soak for up to **3 unit turns** / until your next turn) → later turns spend the well on bolts.

Aggressive line: Fill the Draw bank past Overload threshold → Charged Bolt Overload same turn — then pray the fight ends before you’re punching people at 50/50.

---

## Player & AI notes

- **Player:** Ability-first UI lists Walk, Draw, Charged Bolt, Mana Shield, Fist Fight. Casts disable when Draw’s `drawn_mana < mana_cost`. Draw disables when well &lt; `draw_amount` **or** bank would exceed `max_drawn_mana` (20). Fist Fight needs an adjacent enemy and will often whiff. Show **well mana**, **Draw bank**, and a clear **shield up** cue when Mana Shield is active. Overload tooltip text stays hidden until that ability’s threshold is reached, then unlocks.
- **AI:** May use Overload knowingly (full rules). Prefer real casts while the bank/well allow; Shield when about to take a hit / low HP; Fist Fight only when dry and adjacent. Player-facing Overload text stays gated by unlock.

---

## Implementation map (when building)


| Concern             | Location (planned)                                               |
| ------------------- | ---------------------------------------------------------------- |
| Spawn / stats / kit | `scripts/data/default_battle_setup.gd` → `_make_warlock_stats()` |
| Draw                | `scripts/abilities/warlock_draw_mana_ability_data.gd`            |
| Charged Bolt        | `scripts/abilities/warlock_charged_bolt_ability_data.gd`         |
| Mana Shield         | `scripts/abilities/warlock_mana_shield_ability_data.gd`          |
| Fist Fight          | `scripts/abilities/warlock_fist_fight_ability_data.gd`           |
| Resource API        | `scripts/units/unit.gd` (already generic)                        |
| Resource enum       | `scripts/data/enums.gd` → `UnitResource.MANA` (already exists)   |
| Overhead bars       | `scripts/units/unit_hud.gd` (MANA color already branched)        |
| Ability conventions | `.cursor/rules/abilities.mdc`                                    |
| Balance bands       | [balance.md](balance.md)                                         |


---

## Balance knobs (tune without new systems)


| Knob                 | Proposed | Effect when raised                            |
| -------------------- | -------- | --------------------------------------------- |
| `max_resource`       | 100      | Longer battle relevance                       |
| `max_drawn_mana`     | 20       | Higher bank / bigger possible Overload dumps  |
| `draw_amount`        | 5        | Coarser steps if raised; finer if lowered     |
| `mana_cost`          | 5        | Higher minimum commit to cast                 |
| `overload_threshold` | 15       | Overload harder / easier (keep **&lt; cap**)  |
| `damage_per_mana`    | 1.0      | Stronger payoff per committed point           |
| Fist Fight `damage`  | 8        | How hard the humiliation slap hits            |
| Fist Fight miss      | 50%      | Raise = funnier / more useless when dry       |
| Shield Overload turns| 3        | Longer multi-hit soak window (unit turns)     |
| `max_hp`             | 75       | Forgiveness after mis-position                |
| `move_range`         | 3        | Escape / kiting                               |
| `attack_range`       | 4        | Mid-range reach                               |


Prototype target: Warlock should feel **scary when committing**, and **clearly spent** when the bar is empty — not a flat shooter with a cosmetic mana bar.

---

## Open questions (resolve while implementing)

1. **Leftover bank at battle end / death:** Ignore leftover `drawn_mana` when the unit dies or the battle ends. Mid-battle, the bank **persists across turns** until a cast spends it.
2. **Overload effect for Charged Bolt:** Still TBD (designer-only until unlock). Must differ from Mana Shield’s Overload.
3. **Draws per turn:** Unlimited free Draws until action is spent / turn ends / bank is full? (**Lean: yes** — stop at `max_drawn_mana`.)
4. **Spend rule:** **Resolved — most skills spend the whole bank.** Partial-sip casts are the exception and must say so explicitly.
5. **Multi-spell turns:** Dumping the bank means you cannot fire two banked casts without Drawing again.
6. **Multiple Draws:** **Resolved — all Draw skills store into the default Draw’s bank.**
7. **Shield + multi-hit same action:** If one enemy ability hits twice, does each apply separately against charges? (**Lean: yes** — each damaging application is one “attack.”)
8. **Shield Overload tick:** Decrement the 3-count on **other** units’ turn starts; always clear on the Warlock’s own turn start. (**Resolved** as whichever-first.)

---

## Out of scope / future

Not required for the prototype kit:

- Alternate Draw skills (different amounts, risks, or verbs) — still deposit into the **default** Draw bank; see Architecture
- Passive mana regen of any kind
- Self-damage siphon / ally drain to refill the well
- AoE, DoT, or summon spells
- Stance toggles or cooldowns
- Equipment that changes draw size
- Dedicated Warlock AI policies
- Ability tooltips that show Overload **before** that ability’s threshold is reached

Possible later abilities that still fit: other Draw variants, emergency self-hurt refill, curse that marks for bonus bank damage, or a once-per-battle full well — all as extra `AbilityData`, not a Unit subclass.

---

## Acceptance checklist

- [ ] Spawns with MANA resource (100) and warlock ability set
- [ ] No turn-start mana recharge
- [ ] Draw spends well mana (+5 default) into **Draw skill** `drawn_mana` (not into cast abilities)
- [ ] Draw bank persists across turns until a cast spends it
- [ ] Most cast abilities require `drawn_mana >= mana_cost` then spend the **whole** Draw bank
- [ ] Overload when spent drawn mana > that cast’s `overload_threshold` (per-ability resolve path)
- [ ] Draw bank capped at `max_drawn_mana` (**20**)
- [ ] Overload effects differ by skill; tooltip locked until `drawn_mana >=` that ability’s `overload_threshold`, then unlocks
- [ ] Mana Shield: dumps Draw bank; blocks one hit fully (no HP carryover)
- [ ] Mana Shield Overload: up to **3 unit turns** or Warlock’s own turn start (whichever first); full-blocks each hit while up
- [ ] Fist Fight: free ACTION, range 1, ~50% miss, works when dry
- [ ] Overhead HUD shows HP + well mana; Draw bank readable; Overload text gated by unlock
- [ ] Tuned encounter where empty-mana → fist-fight failure is readable (and funny)
- [ ] AI respects mana scarcity (optional)