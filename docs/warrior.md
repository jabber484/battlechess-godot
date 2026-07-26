# Warrior — Design Doc

Status: **implemented (prototype)**  
Last updated: 2026-07-26  
Role: frontline melee bruiser whose **stamina** is both attack fuel and a damage sponge.

---

## Fantasy & job

The Warrior closes distance, hits hard up close, and survives by spending a shared stamina pool that both fuels attacks and soaks damage. HP is only a bit above average — once stamina is empty, the Warrior is exposed — so the player must stay conscious of **pressure vs. endurance**.

| Pillar         | Intent                                                    |
| -------------- | --------------------------------------------------------- |
| Melee identity | Only fights adjacent (Chebyshev range 1, diagonals count) |
| Shared battery | Stamina powers attacks _and_ soaks damage                 |

### Baseline advantages

| Advantage                | Why it matters                                                                                   |
| ------------------------ | ------------------------------------------------------------------------------------------------ |
| Strong melee damage      | Highest default damage in the prototype roster — wins trades once adjacent                       |
| Better-than-average move | Mid move band — can close gaps that pure short-legs melee cannot                                 |
| Mid speed                | Acts in the middle of the round — neither stranded last nor forced to commit first               |
| Better-than-average HP   | Slight bulk buffer after mistakes, without replacing stamina as the real sustain                 |
| Stamina shield           | Incoming damage can be soaked 1:1 while stamina lasts — frontline without being a pure HP sponge |
| Reliable adjacent hits   | At range 1, no distance falloff; fights are about position and cover, not random miss            |

### Baseline disadvantages

| Disadvantage                          | Why it matters                                                                                                                      |
| ------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------- |
| **Cannot melee full cover** _(early)_ | Directional full cover is a hard block — must flank, wait, or leave the target to allies. First big melee limitation players learn. |
| Melee-only reach                      | Attack range Low — useless until adjacent; kiting and chokepoints hurt                                                              |
| No ranged option                      | Cannot punish full-cover campers or backline without repositioning                                                                  |

---

## Architecture

Warrior is **not** a code subclass. Identity comes from spawn data:

```
UnitStats
  ├── core combat stats (HP, damage, speed, move_range, …)
  ├── resource_id = STAMINA, max_resource = 50
  └── abilities[]
        ├── SimpleMoveAbilityData          (Walk)
        ├── WarriorBasicAttackAbilityData  (Melee)
        ├── WarriorRecklessAttackAbilityData (Reckless — free action, costs stamina; enemy hits first)
        ├── WarriorStaminaShieldAbilityData (passive)
        └── WarriorStaminaRechargeAbilityData (passive)
```

| Layer                     | Owns                                                                                |
| ------------------------- | ----------------------------------------------------------------------------------- |
| `Unit`                    | Generic resource API (`get` / `spend` / `gain` / `refill`) + passive dispatch hooks |
| `UnitStats` / spawn setup | Class defaults (resource type, max, ability list)                                   |
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
| Move range          | 4          | Better than average — closes gaps into melee       |
| Accuracy            | 100        | Deterministic hits before cover/falloff            |
| Damage              | 30         | Highest default damage in the prototype roster     |
| Max HP              | 110        | Better than average — not enough to ignore stamina |
| Resource            | Stamina 50 | Starts full                                        |
| Move/action budgets | 1 / 1      | Same as other units                                |

Compared to generic shooters (Scout etc.): mid speed, stronger mobility than most, better-than-average HP, higher damage, melee-only attack, plus the stamina kit. Stamina — not raw HP — is the real sustain.

---

## Stamina economy

Stamina is a single pool (`BattleEnums.UnitResource.STAMINA`).

### Spends

| Event                | Cost                     | Source                                       |
| -------------------- | ------------------------ | -------------------------------------------- |
| Melee attack         | **10**                   | `WarriorBasicAttackAbilityData.stamina_cost` |
| Reckless attack      | **10** stamina, **0** action slot | `WarriorRecklessAttackAbilityData` — free action; pay stamina + retaliation |
| Incoming damage soak | **1 per 1 HP prevented** | `WarriorStaminaShieldAbilityData`            |

### Gains

| Event           | Amount                  | Source                                              |
| --------------- | ----------------------- | --------------------------------------------------- |
| Own turn starts | **+10** (capped at max) | `WarriorStaminaRechargeAbilityData.recharge_amount` |
| Battle start    | Full (`max_resource`)   | `Unit.setup`                                        |

### Soft caps & feel

- Full stamina ≈ **5 melee attacks** with no soak, or **50 HP** fully absorbed with no attacks.
- Recharge (+10/turn) ≈ **one free attack per turn** if the Warrior never soaks — or partial recovery after soaking.
- Empty stamina → **cannot** Melee or Reckless; shield does nothing until recharge (or future restore tools).
- Overhead HUD shows an amber resource bar under HP when the unit has a resource.

**Design tension:** attacking empties the shield; soaking empties the attack budget. Standing still and tanking is viable until stamina runs dry; then the Warrior must disengage or die.

---

## Abilities

### Walk — `simple_move`

Shared move ability. Uses pathfinding with octile step costs (diagonal ≈ √2). Costs the **move** slot.

### Melee — `warrior_basic_attack`

| Field                | Value                                                            |
| -------------------- | ---------------------------------------------------------------- |
| Category / cost slot | `ACTION` / `ACTION`                                              |
| `attack_range`       | **1** (adjacent including diagonal)                              |
| `range_metric`       | **CHEBYSHEV** (melee — diagonals count as 1)                     |
| Stamina gate         | `current_stamina >= stamina_cost` (default 10)                   |
| Full cover           | **Cannot** target enemies with directional full cover vs warrior |
| Distance falloff     | Inherited; at range 1, **(N−1)×rate = 0** so no distance penalty |
| Commit               | Spend stamina, then normal attack present/resolve                |

`can_activate` requires: action available, stamina, and at least one living enemy in range that is not in full cover. Half cover is still a valid melee target (hit chance reduced as usual).

### Reckless Attack — `warrior_reckless_attack`

Bonus melee on your turn: **does not use the ACTION slot** (`cost_slot = NONE`), but **costs stamina** like Melee. You also pay by letting the enemy **strike first**.

| Field                | Value                                                            |
| -------------------- | ---------------------------------------------------------------- |
| Category / cost slot | `ACTION` / **`NONE`** (free — does not spend move or action)     |
| `attack_range`       | **1** (same as Melee — adjacent including diagonal)              |
| `range_metric`       | **CHEBYSHEV**                                                    |
| Stamina gate         | `current_stamina >= stamina_cost` (default **10**, same as Melee)|
| Full cover           | Same as Melee — **cannot** target directional full cover         |
| Distance falloff     | None at range 1                                                  |
| Commit               | Spend stamina → **retaliation first** → Warrior attack if able   |

`can_activate`: enough stamina, adjacent valid target (not full cover), and Reckless not already used this turn. **Does not** require `can_act_more`.

**Resolve order:**

1. Spend stamina (same commit timing lean as Melee — before the exchange).
2. **Retaliation:** the target attacks the Warrior first (their normal attack / basic strike if valid against the Warrior). Real attack — hit chance, cover, and Warrior **Stamina Shield** soak all apply as usual.
3. If the Warrior is **dead** (or otherwise unable to continue), stop — no Warrior swing (stamina already spent).
4. If the Warrior is still alive and the target is still a valid adjacent melee target, the Warrior performs a normal melee hit (same damage rules as Melee).

**Feel:** same-turn Walk/Melee + Reckless for a greedy double tap, or Reckless after moving when you still want to keep ACTION for something else later — but you eat a hit and burn stamina. Bad into full-health bruisers; good as a finishing bonus when you can afford the retaliate.

**Open impl notes:**

- If the target cannot legally attack the Warrior (e.g. their only attack is out of range), **lean:** skip retaliation and still allow the Warrior swing (rare). Alternate: require a valid retaliator and disable the ability otherwise.
- Retaliation should not consume the enemy’s turn / action budget — it’s an interrupt strike, not their turn.
- **Once per own turn:** hard rule. Track a used flag on the ability instance; clear on the Warrior’s turn start. Cannot Reckless twice in one turn even with leftover stamina.
- **Turn auto-end:** Do not end the turn while **any** non-passive ability still `can_activate` (Move, Melee, Reckless, …). Auto-end only when nothing remains usable.

### Stamina Shield — `warrior_stamina_shield` (passive)

On incoming damage (`Unit.modify_incoming_damage` → `on_incoming_damage`):

1. Read `context.final_damage`
2. `soak = min(final_damage, current_stamina)`
3. Spend that stamina
4. Reduce `final_damage` by `soak`

Misses never reach this path. Cover still only affects hit chance, not damage or soak. Order: shield runs before HP is applied; if soak reduces damage to 0, no HP loss and no damage float for HP (applied damage is 0).

### Stamina Recharge — `warrior_stamina_recharge` (passive)

On the unit’s turn start (`Unit.notify_turn_started` → `on_turn_started`): gain `recharge_amount` stamina (default 10), clamped to max.

---

## Combat positioning

- Range and adjacency use **Chebyshev** (`range_metric = CHEBYSHEV`): diagonals are distance 1.
- Warrior wants to stand next to targets; shooting units want space and cover.
- Enemies in **full cover** from the Warrior’s approach are untargetable in melee — flank or wait them out.
- Half/full cover still reduces _hit chance_ on valid shots against the Warrior; once a hit lands, stamina/HP absorb it — cover does not reduce damage.

Typical loop:

1. Move into melee (or wait for enemies to approach)
2. Melee for 30 damage (−10 stamina)
3. Eat return fire (−stamina via shield)
4. Next turn: +10 stamina, repeat or fall back if empty

---

## Player & AI notes

- **Player:** Ability-first UI lists non-passives (Walk, Melee, Reckless). Melee / Reckless disable when out of range or out of stamina; Reckless also disables after one use until the Warrior’s next turn start. Reckless does not require an available ACTION.
- **AI:** Resolves by category + `can_activate` / `is_valid_target`; first matching ability wins. Warrior AI currently uses the same generic heuristics as other units — no dedicated “preserve stamina” or “when to Reckless” policy yet.

---

## Implementation map

| Concern             | Location                                                         |
| ------------------- | ---------------------------------------------------------------- |
| Spawn / stats / kit | `scripts/data/default_battle_setup.gd` → `_make_warrior_stats()` |
| Melee               | `scripts/abilities/warrior_basic_attack_ability_data.gd`         |
| Reckless            | `scripts/abilities/warrior_reckless_attack_ability_data.gd`      |
| Shield              | `scripts/abilities/warrior_stamina_shield_ability_data.gd`       |
| Recharge            | `scripts/abilities/warrior_stamina_recharge_ability_data.gd`     |
| Resource API        | `scripts/units/unit.gd`                                          |
| Resource enum       | `scripts/data/enums.gd` → `UnitResource`                         |
| Overhead bars       | `scripts/units/unit_hud.gd` + `UnitHUD.tscn`                     |
| Ability conventions | `.cursor/rules/abilities.mdc`                                    |
| Balance defaults    | `.cursor/rules/game-balance.mdc`                                 |

---

## Balance knobs (tune without new systems)

| Knob              | Current | Effect when raised                       |
| ----------------- | ------- | ---------------------------------------- |
| `max_resource`    | 50      | Longer sustain / more consecutive swings |
| `stamina_cost`    | 10      | Fewer attacks per pool                   |
| `recharge_amount` | 10      | Stronger passive recovery                |
| `damage`          | 30      | Kill speed vs. glassier foes             |
| `max_hp`          | 110     | Thin buffer after stamina is empty       |
| `move_range`      | 4       | Ease of closing / escaping               |

Prototype target: Warrior should feel durable **while stamina lasts**, then suddenly fragile — not permanently unkillable.

---

## Out of scope / future

Not required for the current prototype kit:

- Cooldowns, stance toggles, or active “raise shield” abilities
- Partial soak ratios (e.g. 50% stamina / 50% HP)
- Armor, block rolls, or damage-type resistance
- Dedicated Warrior AI that banks stamina
- Equipment / progression that modifies the kit
- Alternate resources on the same unit (one `resource_id` for now)

Possible later abilities that still fit the fantasy: shove, taunt/mark, spend stamina for a burst hit, or a once-per-battle full refill — all as additional `AbilityData` entries, not Unit subclasses.

---

## Acceptance checklist

- [x] Spawns with STAMINA resource and warrior ability set
- [x] Melee costs stamina and requires adjacent enemy
- [x] Shield soaks HP damage 1:1 with stamina
- [x] Recharges stamina at turn start
- [x] Overhead HUD shows HP + stamina
- [x] Reckless Attack: free action (`NONE`), costs stamina (10); enemy retaliates first; Warrior hits if still able
- [x] Reckless once per own turn (flag cleared on turn start)
- [ ] Tuned encounter where empty-stamina failure is readable
- [ ] AI respects stamina scarcity (optional)
