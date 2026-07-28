# Warlock — Design Doc

Status: **implemented (three-gauge mana)**  
Last updated: 2026-07-28  
Role: mid-range glass cannon. Mana is **Available / Charging / Used**. Spells are **channels** — lock Available into Charging, fire or block to park it in Used. Turn start **regens Available into free capacity, then clears Used**. Prep pipeline: fire, then open the next channel.

Contrast: [Warrior](warrior.md) regenerates stamina every turn into one bar. Warlock partitions mana; Charging and Used block how much can refill each turn.

---

## Why older designs failed

The Draw → shared bank → cast loop and turn-tax Meditate collapsed in play (always max-draw, click tax, or skip-turn refill). Per-spell channels fixed the clicks; **three-gauge + regen-before-release** replaces Meditate with a sustainable prep loop.

---

## Fantasy & job

Open a spell to lock mana into that channel. Leave Bolt humming (up to two ticks, **2×** damage) or hold Shield (one block per turn). When you fire Bolt — or Shield **blocks / expires** — that channel’s Charging moves to **Used** (timeout). Next turn: Available fills empty capacity first, then Used clears. After spending a channel, open the next one from remaining Available.


| Pillar | Intent |
| ------ | ------ |
| Three gauges | Available + Charging + Used under one max |
| Open = lock | Available → Charging on that spell |
| Fire / block / expire | Charging → Used; channel ends |
| Turn start | Regen Available into free capacity (Used still blocks), **then** channel hooks |
| Turn end | Release up to **10** Used per turn |
| Prep pipeline | Fire → open next channel same turn if you can |
| No Meditate | Sustain from regen pipeline (no turn-tax refill) |
| No Draw / no Overload | Per-spell channels only |


### Baseline advantages


| Advantage | Why it matters |
| --------- | -------------- |
| High reach | Mid-range glass cannon |
| Prep or snap | Open ahead, or open + fire same turn |
| Scalable bolt | Second tick doubles damage |
| Sustained ward | One block per turn while Shield is up |
| Sustainable | Used times out; Available refills free capacity over turns |


### Baseline disadvantages


| Disadvantage | Why it matters |
| ------------ | -------------- |
| Used hangover | Spent mana blocks regen; only **10** Used clears per turn end |
| Charging locked | Open channels do not refill; they compete for Available |
| Fragile / short legs | Low HP, low move |
| Empty Available | Cannot open new channels until regen frees capacity |


---

## Architecture

```
UnitStats
  ├── resource_id = MANA, max_resource = 50
  └── abilities[]
        ├── SimpleMoveAbilityData
        ├── WarlockChargedBoltAbilityData
        ├── WarlockChargedBlastAbilityData
        └── WarlockManaShieldAbilityData
```


| Layer | Owns |
| ----- | ---- |
| `Unit` | Available (`current_resource`), `resource_charging`, `resource_used`; lock / commit / regen / release |
| Charged Bolt / Blast | Per-spell `charged_mana` / `is_charging`; open + sip + fire |
| Mana Shield | `charged_mana`, `is_charging`, `blocks_available`; open; block or own-turn expire → Used |
| `CombatSystem` | Hit/damage math |


### Three-gauge (important)

```
available  = current_resource
charging   = resource_charging   # mirror of open channels
used       = resource_used
free       = max − available − charging − used
```

**Display:** `available + charging / (max − used)`

**Own turn start order:**

1. `regen_resource_to_capacity()` — Available += free (Used still blocks)  
2. Ability `on_turn_started` — Shield expire (Charging → Used) if open; Bolt sip  

**Own turn end:** `release_used_resource()` — up to **10** Used → 0 (rest stays)  

Flow:

1. **Open / sip:** `lock_resource(X)` → spell `charged_mana += X`  
2. **Bolt fire / Shield block or own-turn expire:** `commit_resource_to_used(spell.charged)` → clear channel  
3. **Turn start:** regen → channel hooks  
4. **Turn end:** release up to 10 Used  

---

## Baseline stats


| Stat | Value | Notes |
| ---- | ----- | ----- |
| Speed | 5 | Mid |
| Move range | 3 | Low |
| Accuracy | 100 | |
| Damage | 8 | Legacy unit damage (channels use their own base) |
| Max HP | 75 | Fragile |
| Resource | Mana **50** | Three-gauge |
| Attack range | 4 / 2 | Charged Bolt / Charged Blast |


---

## Mana economy

### Moves


| Event | Effect |
| ----- | ------ |
| Open Charged Bolt | Available −10 → Charging |
| Open Charged Blast | Available −15 → Charging |
| Open Mana Shield | Available −15 → Charging |
| Bolt / Blast turn sip | Same lock if Available allows (second tick) |
| Fire Bolt / Blast | ACTION; spell Charging → Used; channel ends |
| Shield block / expire | Spell Charging → Used; channel ends |
| Turn start | Fill Available into free capacity (Used still blocks); then channel hooks (Shield expire → Used, Bolt sip) |
| Turn end | Release up to **10** Used (remainder stays locked; hole fills on later regens) |


### Soft caps & feel

- Bolt cap **2 ticks** (20 mana max on bolt channel).  
- Blast cap **2 ticks** (30 mana max on blast channel).  
- Shield: open until **one block** or **own next turn expire**; either way Charging → Used.  
- After fire/block/expire, Used stays locked; **10** clears per turn end.  
- After fire, open the next channel from remaining Available.

---

## Abilities

### Walk — `simple_move`

Shared move. Octile path costs. MOVE slot.

### Charged Bolt — `warlock_charged_bolt`

Open (free): range ring → click **self** → lock **10**.  
Fire (ACTION): click enemy → commit charge to Used; damage `base_bolt_damage × ticks` (1 or 2).  
Turn sip: second tick if under cap (+10).  
Range **4** Euclidean. Base damage **10**.

### Charged Blast — `warlock_charged_blast`

Same channel flow as Bolt (own charge bank).  
Open lock **15**; sip +15 to second tick (cap **30**).  
Fire: damage `18 × ticks` (1 or 2).  
Range **2** Chebyshev (short-range blast). Higher cost, higher payoff than Bolt.

### Mana Shield — `warlock_mana_shield`

Open (free, `activates_on_select`): lock **15**; `blocks_available = 1`.  
**Block:** nullify hit → commit Charging → Used → end channel.  
**Expire:** on own turn start (after regen), if still open → commit Charging → Used.  
No multi-turn upkeep sip — reopen each cycle.

---

## Combat positioning

Typical loop: move → open Bolt and/or Shield → wait for second bolt tick if needed → fire → **open next channel** → Used times out while prep grows.

---

## Player & AI notes

- UI: `A + C / (max − U)`; Bolt / Blast charge on buttons; Shield status.  
- AI: fire 2-tick channels; reopen after spend; keep prep pipeline going.

---

## Implementation map


| Concern | Location |
| ------- | -------- |
| Spawn / kit | `default_battle_setup.gd` |
| Partitions | `unit.gd` |
| Bolt / Blast / Shield | `warlock_*_ability_data.gd` |
| HUD / battle UI | `unit_hud.gd`, `battle_ui.gd` |
| Conventions | `.cursor/rules/abilities.mdc` |


---

## Balance knobs


| Knob | Proposed |
| ---- | -------- |
| `max_resource` | 50 |
| Bolt `charge_draw_amount` | 10 |
| Blast `charge_draw_amount` | 15 |
| Shield `charge_draw_amount` | 15 |
| `max_charge_ticks` | 2 |
| Bolt `base_bolt_damage` | 10 |
| Blast `base_bolt_damage` | 18 |


---

## Out of scope / future

- Meditate emergency reset  
- Cancel-channel without spending to Used  
- AI polish / AoE variants  

---

## Acceptance checklist

- [x] Three gauges; display `A + C / (max − U)`  
- [x] Open/sip locks; fire/block commits to Used and ends channel  
- [x] Turn start: regen free capacity → release Used → sips  
- [x] No Meditate in kit  
- [x] Bolt 2-tick 2×; Shield 1 block/turn until block ends channel  
- [x] No Fist Fight in kit  
- [ ] Tuned encounter readability  
- [ ] AI (optional)  
