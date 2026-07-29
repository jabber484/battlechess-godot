# Warlock — Design Doc

Status: **implemented (three-gauge mana)**  
Last updated: 2026-07-29  
Role: mid-range glass cannon. Mana is **Available / Charging / Used**. Spells are **channels** — lock Available into Charging, fire or block to park it in Used. Turn start **regens Available into free capacity**. Prep pipeline: fire, then open the next channel.

Contrast: [Warrior](warrior.md) regenerates stamina every turn into one bar. Warlock partitions mana; Charging and Used block how much can refill each turn.

---

## Why older designs failed

The Draw → shared bank → cast loop and turn-tax Meditate collapsed in play (always max-draw, click tax, or skip-turn refill). Per-spell channels fixed the clicks; **three-gauge + regen-before-release** replaces Meditate with a sustainable prep loop. Large (÷10) mana magnitudes made cost = release and hid scarcity — kit now uses small integers with a free Bolt snap only.

---

## Fantasy & job

Open a spell to lock mana into that channel. **Snap Bolt** opens for free (0 lock) and can fire same turn. Leave Bolt humming for a paid second tick (**2×** damage) or hold Shield (one block per turn). When you fire a paid channel — or Shield **blocks / expires** — that channel’s Charging moves to **Used** (timeout). Next turn: Available fills empty capacity first; Used clears gradually on turn end. After spending a channel, open the next one from remaining Available.


| Pillar | Intent |
| ------ | ------ |
| Three gauges | Available + Charging + Used under one max |
| Open = lock | Available → Charging on that spell (Bolt first tick may lock 0) |
| Fire / block / expire | Charging → Used; channel ends |
| Turn start | Regen Available into free capacity (Used still blocks), **then** channel hooks |
| Turn end | Release up to **1** Used per turn |
| Prep pipeline | Fire → open next channel same turn if you can |
| Free snap only | Bolt tick 1 costs 0; charged sip / Blast / Shield cost mana |
| No Meditate | Sustain from regen pipeline (no turn-tax refill) |
| No Draw / no Overload | Per-spell channels only |


### Baseline advantages


| Advantage | Why it matters |
| --------- | -------------- |
| High reach | Mid-range glass cannon |
| Prep or snap | Free snap AA, or wait for paid double |
| Scalable bolt | Second tick doubles damage |
| Sustained ward | One block per turn while Shield is up |
| Sustainable snap | Used times out; free snap needs no bank |


### Baseline disadvantages


| Disadvantage | Why it matters |
| ------------ | -------------- |
| Used hangover | Paid spends block regen; only **1** Used clears per turn end |
| Charging locked | Open channels do not refill; they compete for Available |
| Fragile / short legs | Low HP, low move |
| Empty Available | Cannot sip / open paid channels until regen frees capacity |


---

## Architecture

```
UnitStats
  ├── resource_id = MANA, max_resource = 5
  └── abilities[]
        ├── SimpleMoveAbilityData
        ├── WarlockChargedBoltAbilityData   # extends WarlockChargedAttackAbilityData
        ├── WarlockChargedBlastAbilityData  # extends WarlockChargedAttackAbilityData
        └── WarlockManaShieldAbilityData
```


| Layer | Owns |
| ----- | ---- |
| `Unit` | Available (`current_resource`), `resource_charging`, `resource_used`; lock / commit / regen / release |
| `WarlockChargedAttackAbilityData` | Shared open / sip / fire; `charged_mana` / `_charge_ticks` / `is_charging` |
| Charged Bolt / Blast | Sibling kits (range, locks, `base_damage`) on that base |
| Mana Shield | `charged_mana`, `is_charging`, `blocks_available`; open; block or own-turn expire → Used |
| `CombatSystem` | Hit/damage math |


### Three-gauge (important)

```
available  = current_resource
charging   = resource_charging   # mirror of open channels (0 while free Bolt snap is open)
used       = resource_used
free       = max − available − charging − used
```

**Display:** `available + charging / (max − used)`

**Own turn start order:**

1. `regen_resource_to_capacity()` — Available += free (Used still blocks)  
2. Ability `on_turn_started` — Shield expire (Charging → Used) if open; Bolt/Blast sip  

**Own turn end:** `release_used_resource()` — up to **1** Used → 0 (rest stays)  

Flow:

1. **Open / sip:** `lock_resource(X)` when X > 0 → spell `charged_mana += X`; always bump tick count  
2. **Bolt fire / Shield block or own-turn expire:** `commit_resource_to_used(spell.charged)` when charged > 0 → clear channel  
3. **Turn start:** regen → channel hooks  
4. **Turn end:** release up to 1 Used  

---

## Baseline stats


| Stat | Value | Notes |
| ---- | ----- | ----- |
| Speed | 5 | Mid |
| Move range | 3 | Low |
| Accuracy | 100 | |
| Damage | 8 | Legacy unit damage (channels use their own base) |
| Max HP | 75 | Fragile |
| Resource | Mana **5** | Three-gauge |
| Attack range | 4 / 2 | Charged Bolt / Charged Blast |


---

## Mana economy

### Moves


| Event | Effect |
| ----- | ------ |
| Open Charged Bolt | Lock **0** (free snap tick); channel open |
| Open Charged Blast | Available −**2** → Charging |
| Open Mana Shield | Available −**2** → Charging |
| Bolt turn sip | Lock **1** if Available allows (second tick) |
| Blast turn sip | Lock **1** if Available allows (second tick) |
| Fire Bolt / Blast | ACTION; spell Charging → Used; channel ends |
| Shield block / expire | Spell Charging → Used; channel ends |
| Turn start | Fill Available into free capacity (Used still blocks); then channel hooks (Shield expire → Used, Bolt/Blast sip) |
| Turn end | Release up to **1** Used (remainder stays locked; hole fills on later regens) |


### Soft caps & feel

- Bolt cap **2 ticks** (max **1** mana on bolt channel: 0 + 1). Snap fire commits **0** Used (infinite AA). Charged fire commits **1** Used vs release **1** (sustainable double if you always prep).  
- Blast cap **2 ticks** (max **3** mana on blast channel: 2 + 1).  
- Shield: open until **one block** or **own next turn expire**; either way Charging → Used.  
- After paid fire/block/expire, Used stays locked; **1** clears per turn end.  
- After fire, open the next channel from remaining Available.

---

## Abilities

### Walk — `simple_move`

Shared move. Octile path costs. MOVE slot.

### Charged Bolt — `warlock_charged_bolt`

Open (free slot): range ring → click **self** → lock **0** (tick 1).  
Fire (ACTION): click enemy → commit charge to Used; damage `base_damage × ticks` (1 or 2).  
Turn sip: second tick if under cap (+**1**).  
Range **4** Euclidean. Base damage **10**.  
Exports: `first_tick_lock = 0`, `next_tick_lock = 1`.

### Charged Blast — `warlock_charged_blast`

Same channel flow as Bolt (own charge bank).  
Open lock **2**; sip +**1** to second tick (cap **3** mana).  
Fire: damage `base_damage × ticks` (18 × 1 or 2).  
Range **2** Chebyshev (short-range blast). Exports: `first_tick_lock = 2`, `next_tick_lock = 1`.

### Mana Shield — `warlock_mana_shield`

Open (free, `activates_on_select`): lock **2**; `blocks_available = 1`.  
**Block:** nullify hit → commit Charging → Used → end channel.  
**Expire:** on own turn start (after regen), if still open → commit Charging → Used.  
No multi-turn upkeep sip — reopen each cycle.

---

## Combat positioning

Typical loop: move → open Bolt (snap or hold for sip) and/or Shield → fire → **open next channel** → Used times out while prep grows.

---

## Player & AI notes

- UI: `A + C / (max − U)`; Bolt / Blast charge on buttons; Shield status. Free snap shows `0/2` mana while channel is open.  
- AI: fire 2-tick channels when bank allows; snap otherwise; reopen after spend.

---

## Implementation map


| Concern | Location |
| ------- | -------- |
| Spawn / kit | `default_battle_setup.gd` |
| Partitions | `unit.gd` |
| Charged-attack base | `warlock_charged_attack_ability_data.gd` |
| Bolt / Blast / Shield | `warlock_*_ability_data.gd` |
| HUD / battle UI | `unit_hud.gd`, `battle_ui.gd` |
| Conventions | `.cursor/rules/abilities.mdc` |


---

## Balance knobs


| Knob | Proposed |
| ---- | -------- |
| `max_resource` | 5 |
| `MANA_USED_RELEASE_PER_TURN` | 1 |
| Bolt `first_tick_lock` | 0 |
| Bolt `next_tick_lock` | 1 |
| Blast `first_tick_lock` / `next_tick_lock` | 2 / 1 |
| Shield `charge_draw_amount` | 2 |
| `max_charge_ticks` | 2 |
| Bolt `base_damage` | 10 |
| Blast `base_damage` | 18 |


---

## Out of scope / future

- Meditate emergency reset  
- Cancel-channel without spending to Used  
- AI polish / AoE variants  

---

## Acceptance checklist

- [x] Three gauges; display `A + C / (max − U)`  
- [x] Open/sip locks; fire/block commits to Used and ends channel  
- [x] Turn start: regen free capacity → channel hooks; turn end: release Used  
- [x] No Meditate in kit  
- [x] Bolt free snap + paid 2-tick 2×; Shield 1 block/turn until block ends channel  
- [x] No Fist Fight in kit  
- [ ] Tuned encounter readability  
- [ ] AI (optional)  
