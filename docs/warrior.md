# Warrior ? Design Doc

Status: **implemented (prototype)**  
Last updated: 2026-07-26  
Role: frontline melee bruiser whose **stamina** is both attack fuel and a damage sponge.

---

## Fantasy & job

The Warrior closes distance, hits hard up close, and survives by spending a shared stamina pool that both fuels attacks and soaks damage. HP is only a bit above average ? once stamina is empty, the Warrior is exposed ? so the player must stay conscious of **pressure vs. endurance**.

| Pillar         | Intent                                                    |
| -------------- | --------------------------------------------------------- |
| Melee identity | Only fights adjacent (Chebyshev range 1, diagonals count) |
| Shared battery | Stamina powers attacks _and_ soaks damage                 |

### Baseline advantages

| Advantage                | Why it matters                                                                                   |
| ------------------------ | ------------------------------------------------------------------------------------------------ |
| Strong melee damage      | Highest default damage in the prototype roster ? wins trades once adjacent                       |
| Better-than-average move | Mid move band ? can close gaps that pure short-legs melee cannot                                 |
| Mid speed                | Acts in the middle of the round ? neither stranded last nor forced to commit first               |
| Better-than-average HP   | Slight bulk buffer after mistakes, without replacing stamina as the real sustain                 |
| Stamina shield           | Incoming damage can be soaked 1:1 while stamina lasts ? frontline without being a pure HP sponge |
| Reliable adjacent hits   | At range 1, no distance falloff; fights are about position and cover, not random miss            |

### Baseline disadvantages

| Disadvantage                          | Why it matters                                                                                                                      |
| ------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------- |
| **Cannot melee full cover** _(early)_ | Directional full cover is a hard block ? must flank, wait, or leave the target to allies. First big melee limitation players learn. |
| Melee-only reach                      | Attack range Low ? useless until adjacent; kiting and chokepoints hurt                                                              |
| No ranged option                      | Cannot punish full-cover campers or backline without repositioning                                                                  |

---

## Architecture

Warrior is **not** a code subclass. Identity comes from spawn data:

```
UnitStats
  ??? core combat stats (HP, damage, speed, move_range, ?)
  ??? resource_id = STAMINA, max_resource = 50
  ??? abilities[]
        ??? WarriorMoveAbilityData         (Move ? Walk + stamina overspend)
        ??? WarriorBasicAttackAbilityData  (Melee)
        ??? WarriorBrawlAbilityData (Brawl ? free action, costs stamina; enemy hits first)
        ??? WarriorStaminaShieldAbilityData (passive)
        ??? WarriorStaminaRechargeAbilityData (passive)
```

| Layer                     | Owns                                                                                |
| ------------------------- | ----------------------------------------------------------------------------------- |
| `Unit`                    | Generic resource API (`get` / `spend` / `gain` / `refill`) + passive dispatch hooks |
| `UnitStats` / spawn setup | Class defaults (resource type, max, ability list)                                   |
| Move ability              | Path reach + optional stamina overspend (`extra_range`, `stamina_per_tile`)         |
| Attack ability            | When/how much stamina an attack costs                                               |
| Passive abilities         | Shield soak rules; turn-start recharge                                              |
| `CombatSystem`            | Hit/damage math (unchanged by class)                                                |

**Do not** put class-specific recharge or soak logic on `Unit` or in battle systems. Keep kits swappable by swapping ability resources.

---

## Baseline stats

From `DefaultBattleSetup._make_warrior_stats()`:

| Stat                | Value      | Notes                                              |
| ------------------- | ---------- | -------------------------------------------------- |
| Speed               | 5          | Mid initiative (between Sniper 3 and Scout 8)      |
| Move range          | 4          | Better than average ? closes gaps into melee       |
| Accuracy            | 100        | Deterministic hits before cover/falloff            |
| Damage              | 30         | Highest default damage in the prototype roster     |
| Max HP              | 110        | Better than average ? not enough to ignore stamina |
| Resource            | Stamina 50 | Starts full                                        |
| Move/action budgets | 1 / 1      | Same as other units                                |

Compared to generic shooters (Scout etc.): mid speed, stronger mobility than most, better-than-average HP, higher damage, melee-only attack, plus the stamina kit. Stamina ? not raw HP ? is the real sustain.

---

## Stamina economy

Stamina is a single pool (`BattleEnums.UnitResource.STAMINA`).

### Spends

| Event                | Cost                     | Source                                       |
| -------------------- | ------------------------ | -------------------------------------------- |
| Melee attack         | **10**                   | `WarriorBasicAttackAbilityData.stamina_cost` |
| Brawl                | **10** stamina, **0** action slot | `WarriorBrawlAbilityData` ? free action; pay stamina + retaliation |
| Move overspend       | **5 per overflow tile** (max +2) | `WarriorMoveAbilityData.stamina_per_tile` |
| Incoming damage soak | **1 per 1 HP prevented** | `WarriorStaminaShieldAbilityData`            |

### Gains

| Event           | Amount                  | Source                                              |
| --------------- | ----------------------- | --------------------------------------------------- |
| Own turn starts | **+30** (capped at max) | `WarriorStaminaRechargeAbilityData.recharge_amount` |
| Battle start    | Full (`max_resource`)   | `Unit.setup`                                        |

### Soft caps & feel

- Full stamina ? **5 melee attacks** with no soak, or **50 HP** fully absorbed with no attacks.
- Recharge (+30/turn) ? **Melee cost (10) plus leftover for shield soak** ? attack and still defend in the same turn cycle.
- Empty stamina → **cannot** Melee, Brawl, or stamina Move overspend; shield does nothing until recharge (or future restore tools).
- Overhead HUD shows an amber resource bar under HP when the unit has a resource.

**Design tension:** heavy soak or Brawl still drains the pool faster than recharge; standing still and tanking is viable until stamina runs dry.

---

## Abilities

### Move ? `warrior_move`

Replaces shared Walk on the Warrior kit. Uses octile pathfinding (diagonal ? ?2). Costs the **move** slot.

| Field | Value |
| ----- | ----- |
| Category / cost slot | `MOVE` / `MOVE` |
| Free budget | `unit.movement_remaining` (from `move_range`, default **4**) |
| Extra reach | Up to **+2** octile path cost beyond free budget **per turn** (`extra_range`) |
| Stamina | `stamina_per_tile` (default **5**) per started unit of overflow path cost |
| Cap | Extension used this turn tracked on the ability; cleared on turn start |
| Activate when | Free move left, **or** enough stamina for at least one cardinal of remaining extension |

Within normal move: same as Walk (no stamina). Past that: pay stamina to continue, up to +2 total overflow for the turn. Empty stamina or used extension ? only free remaining move (if any).

### Melee ? `warrior_basic_attack`

| Field                | Value                                                            |
| -------------------- | ---------------------------------------------------------------- |
| Category / cost slot | `ACTION` / `ACTION`                                              |
| `attack_range`       | **1** (adjacent including diagonal)                              |
| `range_metric`       | **CHEBYSHEV** (melee ? diagonals count as 1)                     |
| Stamina gate         | `current_stamina >= stamina_cost` (default 10)                   |
| Full cover           | **Cannot** target enemies with directional full cover vs warrior |
| Distance falloff     | Inherited; at range 1, **(N?1)�rate = 0** so no distance penalty |
| Commit               | Spend stamina, then normal attack present/resolve                |

`can_activate` requires: action available, stamina, and at least one living enemy in range that is not in full cover. Half cover is still a valid melee target (hit chance reduced as usual).

### Brawl ? `warrior_brawl`

Bonus melee on your turn: **does not use the ACTION slot** (`cost_slot = NONE`), but **costs stamina** like Melee. You also pay by letting the enemy **strike first**.

| Field                | Value                                                            |
| -------------------- | ---------------------------------------------------------------- |
| Category / cost slot | `ACTION` / **`NONE`** (free ? does not spend move or action)     |
| `attack_range`       | **1** (same as Melee ? adjacent including diagonal)              |
| `range_metric`       | **CHEBYSHEV**                                                    |
| Stamina gate         | `current_stamina >= stamina_cost` (default **10**, same as Melee)|
| Full cover           | Same as Melee ? **cannot** target directional full cover         |
| Distance falloff     | None at range 1                                                  |
| Commit               | Spend stamina ? **retaliation first** ? Warrior attack if able   |

`can_activate`: enough stamina, adjacent valid target (not full cover), and Brawl not already used this turn. **Does not** require `can_act_more`.

**Resolve order:**

1. Spend stamina (same commit timing lean as Melee ? before the exchange).
2. **Retaliation:** the target attacks the Warrior first (their normal attack / basic strike if valid against the Warrior). Real attack ? hit chance, cover, and Warrior **Stamina Shield** soak all apply as usual.
3. If the Warrior is **dead** (or otherwise unable to continue), stop ? no Warrior swing (stamina already spent).
4. If the Warrior is still alive and the target is still a valid adjacent melee target, the Warrior performs a normal melee hit (same damage rules as Melee).

**Feel:** same-turn Walk/Melee + Brawl for a greedy double tap, or Brawl after moving when you still want to keep ACTION for something else later ? but you eat a hit and burn stamina. Bad into full-health bruisers; good as a finishing bonus when you can afford the retaliate.

**Open impl notes:**

- If the target cannot legally attack the Warrior (e.g. their only attack is out of range), **lean:** skip retaliation and still allow the Warrior swing (rare). Alternate: require a valid retaliator and disable the ability otherwise.
- Retaliation should not consume the enemy?s turn / action budget ? it?s an interrupt strike, not their turn.
- **Once per own turn:** hard rule. Track a used flag on the ability instance; clear on the Warrior?s turn start. Cannot Brawl twice in one turn even with leftover stamina.
- **Turn auto-end:** Do not end the turn while **any** non-passive ability still `can_activate` (Move, Melee, Brawl, ?). Auto-end only when nothing remains usable.

### Stamina Shield ? `warrior_stamina_shield` (passive)

On incoming damage (`Unit.modify_incoming_damage` ? `on_incoming_damage`):

1. Read `context.final_damage`
2. `soak = min(final_damage, current_stamina)`
3. Spend that stamina
4. Reduce `final_damage` by `soak`

Misses never reach this path. Cover still only affects hit chance, not damage or soak. Order: shield runs before HP is applied; if soak reduces damage to 0, no HP loss and no damage float for HP (applied damage is 0).

### Stamina Recharge ? `warrior_stamina_recharge` (passive)

On the unit?s turn start (`Unit.notify_turn_started` ? `on_turn_started`): gain `recharge_amount` stamina (default 30), clamped to max. Intent: cover a Melee spend and still leave stamina for shield soak.

---

## Combat positioning

- Range and adjacency use **Chebyshev** (`range_metric = CHEBYSHEV`): diagonals are distance 1.
- Warrior wants to stand next to targets; shooting units want space and cover.
- Enemies in **full cover** from the Warrior?s approach are untargetable in melee ? flank or wait them out.
- Half/full cover still reduces _hit chance_ on valid shots against the Warrior; once a hit lands, stamina/HP absorb it ? cover does not reduce damage.

Typical loop:

1. Move into melee (or wait for enemies to approach)
2. Melee for 30 damage (?10 stamina)
3. Eat return fire (?stamina via shield)
4. Next turn: +30 stamina, repeat or fall back if empty

---

## Player & AI notes

- **Player:** Ability-first UI lists non-passives (Move, Melee, Brawl). Move can spend stamina past normal range (up to +2). Melee / Brawl disable when out of range or out of stamina; Brawl also disables after one use until the Warrior?s next turn start. Brawl does not require an available ACTION.
- **AI:** Resolves by category + `can_activate` / `is_valid_target`; first matching ability wins. Warrior AI currently uses the same generic heuristics as other units ? no dedicated ?preserve stamina? or ?when to Brawl? policy yet.

---

## Implementation map

| Concern             | Location                                                         |
| ------------------- | ---------------------------------------------------------------- |
| Spawn / stats / kit | `scripts/data/default_battle_setup.gd` ? `_make_warrior_stats()` |
| Move                | `scripts/abilities/warrior_move_ability_data.gd`                 |
| Melee               | `scripts/abilities/warrior_basic_attack_ability_data.gd`         |
| Brawl               | `scripts/abilities/warrior_brawl_ability_data.gd`                |
| Shield              | `scripts/abilities/warrior_stamina_shield_ability_data.gd`       |
| Recharge            | `scripts/abilities/warrior_stamina_recharge_ability_data.gd`     |
| Resource API        | `scripts/units/unit.gd`                                          |
| Resource enum       | `scripts/data/enums.gd` ? `UnitResource`                         |
| Overhead bars       | `scripts/units/unit_hud.gd` + `UnitHUD.tscn`                     |
| Ability conventions | `.cursor/rules/abilities.mdc`                                    |
| Balance defaults    | `.cursor/rules/game-balance.mdc`                                 |

---

## Balance knobs (tune without new systems)

| Knob              | Current | Effect when raised                       |
| ----------------- | ------- | ---------------------------------------- |
| `max_resource`    | 50      | Longer sustain / more consecutive swings |
| `stamina_cost`    | 10      | Fewer attacks per pool                   |
| `recharge_amount` | 30      | Stronger passive recovery                |
| `damage`          | 30      | Kill speed vs. glassier foes             |
| `max_hp`          | 110     | Thin buffer after stamina is empty       |
| `move_range`      | 4       | Ease of closing / escaping               |
| `extra_range`     | 2       | Max stamina-paid overflow path cost/turn |
| `stamina_per_tile`| 5       | Stamina per overflow tile (ceil)         |

Prototype target: Warrior should feel durable **while stamina lasts**, then suddenly fragile ? not permanently unkillable.

---

## Out of scope / future

Not required for the current prototype kit:

- Cooldowns, stance toggles, or active ?raise shield? abilities
- Partial soak ratios (e.g. 50% stamina / 50% HP)
- Armor, block rolls, or damage-type resistance
- Dedicated Warrior AI that banks stamina
- Equipment / progression that modifies the kit
- Alternate resources on the same unit (one `resource_id` for now)

Possible later abilities that still fit the fantasy: shove, taunt/mark, spend stamina for a burst hit, or a once-per-battle full refill ? all as additional `AbilityData` entries, not Unit subclasses.

---

## Acceptance checklist

- [x] Spawns with STAMINA resource and warrior ability set
- [x] Move replaces Walk; stamina overspend up to +2 path cost at 5/tile
- [x] Melee costs stamina and requires adjacent enemy
- [x] Shield soaks HP damage 1:1 with stamina
- [x] Recharges stamina at turn start
- [x] Overhead HUD shows HP + stamina
- [x] Brawl: free action (`NONE`), costs stamina (10); enemy retaliates first; Warrior hits if still able
- [x] Brawl once per own turn (flag cleared on turn start)
- [ ] Tuned encounter where empty-stamina failure is readable
- [ ] AI respects stamina scarcity (optional)
