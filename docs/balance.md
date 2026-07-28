# Unit Balance Bands

Status: **prototype targets**  
Last updated: 2026-07-27

Rate unit baselines on **Low / Mid / High** for the four mobility–survivability axes below. Use this when authoring new kits; concrete numbers are band guides, not hard locks.

**Important:** Low / Mid / High are **relative within a team role**. Player High HP is not the same absolute value as enemy High HP — enemies are meant to die in fewer trades so encounters stay readable in a short prototype fight.

Damage, accuracy, and class resources (stamina, mana, etc.) live in per-class docs — not here.

---

## Qualitative axes (shared meaning)

| Stat             | Low                             | Mid                  | High                            |
| ---------------- | ------------------------------- | -------------------- | ------------------------------- |
| **HP**           | Fragile; dies fast if focused   | Average bulk         | Tanky for that team's scale     |
| **Speed**        | Acts late in the round          | Middle of initiative | Acts early; sets tempo          |
| **Move range**   | Short reach; needs help closing | Typical reposition   | Crosses gaps; hard to kite      |
| **Attack range** | Melee / touch (Chebyshev 1)     | Short–medium reach   | Long reach; shoots across cover |

Attack range: melee uses Chebyshev; ranged uses Euclidean (√(dx²+dy²)). Move budget uses octile path cost (diagonal ≈ √2).

Speed, move range, and attack range use the **same numeric bands** for both teams (board geometry is shared). **HP does not.**

---

## Numeric guides

### Shared (Speed / Move / Attack range)

| Stat         | Low  | Mid      | High  |
| ------------ | ---- | -------- | ----- |
| Speed        | ≤ 3  | 4 – 6    | ≥ 7   |
| Move range   | ≤ 3  | 4        | ≥ 5   |
| Attack range | 1    | 2 – 4    | ≥ 5   |

### Player HP

Player units are the long-lived side of the fight (class resources, mistakes, multi-turn sustain).

| Band | HP        | Feel                                      |
| ---- | --------- | ----------------------------------------- |
| Low  | ≤ 80      | Fragile; focus fire ends them fast        |
| Mid  | 85 – 105  | Average bulk                              |
| High | ≥ 110     | Tanky; survives after mistakes            |

### Enemy HP

Enemy units are encounter pieces. A “tanky” enemy still dies much faster than a Mid player — bands are scaled down so one or two solid hits resolve a foe.

| Band | HP       | Feel (vs player damage)                          |
| ---- | -------- | ------------------------------------------------ |
| Low  | ≤ 40     | Soft; one Warrior swing often kills or nearly    |
| Mid  | 41 – 55  | Typical grunt bulk                               |
| High | ≥ 56     | Sticky for an enemy; soaks an extra hit          |

Do **not** judge enemy HP with the player table (e.g. Guard 50 is **Mid** on the enemy scale, not Low).

---

## Current roster

Bands below use the correct scale for that unit's team.

### Player

| Unit    | HP   | Speed | Move range | Attack range |
| ------- | ---- | ----- | ---------- | ------------ |
| Warrior | Mid+ | Mid   | Mid        | Low          |
| Warlock | Low  | Mid   | Low        | Mid          |

**Mid+** = better than average within Mid (Warrior HP 110 sits on the Mid/High border on purpose — not a true High tank so stamina soak still matters).

### Enemy

| Unit   | HP  | Speed | Move range | Attack range |
| ------ | --- | ----- | ---------- | ------------ |
| Raider | Mid | High  | Mid        | High         |
| Guard  | Mid | Mid   | Low        | Low          |
| Sniper | Low | Low   | Low        | High         |

### Raw values (reference)

| Unit    | Team   | HP  | Speed | Move | Attack |
| ------- | ------ | --- | ----- | ---- | ------ |
| Warrior | Player | 110 | 5     | 4    | 1      |
| Warlock | Player | 75  | 5     | 3    | 4      |
| Raider  | Enemy  | 42  | 7     | 4    | 5      |
| Guard   | Enemy  | 50  | 5     | 3    | 1      |
| Sniper  | Enemy  | 38  | 3     | 3    | 5      |

Attack range comes from the attack ability (`warrior_basic_attack` / `simple_melee` = 1, `warlock_charged_bolt` = 4, `simple_attack` = 5).

---

## Design reminders

- Prefer clear **tradeoffs**: a High on one axis usually pairs with a Low on another (Sniper: High attack range, Low everything else).
- Melee kits (attack range Low) should usually take Mid+ move so they can close; Warriors follow this. Enemy melee (Guard) may stay Low move if the spawn is close enough to pressure.
- Do not push Warrior HP to High — sustain is meant to come from stamina block awareness.
- When authoring enemies, pick HP from the **enemy** table first, then assign the Low/Mid/High label.
- See [warrior.md](warrior.md) / [warlock.md](warlock.md) for class economies; see `.cursor/rules/game-balance.mdc` for hit-chance rules.
