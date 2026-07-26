# Unit Balance Bands

Status: **prototype targets**  
Last updated: 2026-07-26

Rate class baselines on **Low / Mid / High** for the four mobility–survivability axes below. Use this when authoring new kits; concrete numbers are band guides, not hard locks.

Damage, accuracy, and class resources (stamina, etc.) live in per-class docs — not here.

---

## Band definitions

| Stat             | Low                             | Mid                  | High                            |
| ---------------- | ------------------------------- | -------------------- | ------------------------------- |
| **HP**           | Fragile; dies fast if focused   | Average bulk         | Tanky; survives after mistakes  |
| **Speed**        | Acts late in the round          | Middle of initiative | Acts early; sets tempo          |
| **Move range**   | Short reach; needs help closing | Typical reposition   | Crosses gaps; hard to kite      |
| **Attack range** | Melee / touch (Chebyshev 1)     | Short–medium reach   | Long reach; shoots across cover |

### Prototype numeric guide

Attack range: melee uses Chebyshev; ranged uses Euclidean (√(dx²+dy²)). Move budget uses octile path cost (diagonal ≈ √2). Tune bands if the map size changes.

| Stat         | Low  | Mid      | High  |
| ------------ | ---- | -------- | ----- |
| HP           | ≤ 80 | 85 – 105 | ≥ 110 |
| Speed        | ≤ 3  | 4 – 6    | ≥ 7   |
| Move range   | ≤ 3  | 4        | ≥ 5   |
| Attack range | 1    | 2 – 4    | ≥ 5   |

---

## Current roster

| Unit    | HP   | Speed | Move range | Attack range |
| ------- | ---- | ----- | ---------- | ------------ |
| Warrior | Mid+ | Mid   | Mid        | Low          |
| Warlock | Low  | Mid   | Low        | Mid          |
| Raider  | Mid  | High  | Mid        | High         |
| Guard   | Mid  | Mid   | Low        | High         |
| Sniper  | Low  | Low   | Low        | High         |

**Mid+** = better than average within Mid (Warrior HP 110 sits on the Mid/High border on purpose — not a true High tank so stamina soak still matters).

### Raw values (reference)

| Unit    | HP  | Speed | Move | Attack |
| ------- | --- | ----- | ---- | ------ |
| Warrior | 110 | 5     | 4    | 1      |
| Warlock | 75  | 5     | 3    | 4      |
| Raider  | 85  | 7     | 4    | 5      |
| Guard   | 100 | 5     | 3    | 5      |
| Sniper  | 75  | 3     | 3    | 5      |

Attack range comes from the attack ability (`warrior_basic_attack` = 1, `warlock_charged_bolt` = 4, `simple_attack` = 5).

---

## Design reminders

- Prefer clear **tradeoffs**: a High on one axis usually pairs with a Low on another (Sniper: High attack range, Low everything else).
- Melee kits (attack range Low) should usually take Mid+ move so they can close; Warriors follow this.
- Do not push Warrior HP to High — sustain is meant to come from stamina block awareness.
- See [warrior.md](warrior.md) / [warlock.md](warlock.md) for class economies; see `.cursor/rules/game-balance.mdc` for hit-chance rules.
