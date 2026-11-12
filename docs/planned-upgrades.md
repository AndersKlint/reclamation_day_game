# Upgrade catalog

The full upgrade catalog contains 21 implemented upgrades. Names are display titles; effect descriptions use ordinary stat names.

## Selection and stacking

- Each card rolls rarity first: Common (C) 59%, Uncommon (U) 30%, Epic (E) 9%, Legendary (L) 2%.
- Each offer contains three distinct upgrade names. There are no rerolls or batched choices; queued level-ups are resolved sequentially.
- Values listed as C/U/E or C/U/E/L correspond to those rarities in order. Three-value upgrades have no Legendary version.
- Ordinary stat upgrades are repeatable and stack multiplicatively, including percentage reductions. Fixed-rarity special upgrades can be selected only once per run.
- Upgraded stats retain their growth scaling. Movement speed and acceleration scale together. Phase distance changes do not change phase duration.
- The base phase cooldown is 8 seconds, eight times the previous 1 second. Phaseless applies its normal multiplicative reductions to this base.
- Increasing drain speed does not increase the total reward available from a finite target.
- The short king is mutually exclusive with Godzilla and The Ape King, in either pickup order; the two giants can be combined.

## Editing upgrades

- Open a per-upgrade `.tres` resource under `game/upgrades/` in the Godot Inspector to edit its title, flavor text, and rarity variants.
- Expand a variant's effects array and add or edit `UpgradeStatEffect` resources. Select the stat (drain speed, drain radius, movement speed, phase cooldown, resistance, or phase distance) and enter its percentage.
- For special shockwaves, edit `UpgradeVariant.shockwave` as a `ShockwaveEffect` alongside stat effects. Its settings are trigger (`PERIODIC` or `PHASE_COMPLETED`), presentation (`SHOCKWAVE` by default, `SOUL_BURST` for Outcry), `interval_seconds`, `delay_seconds`, `radius_multiplier`, `stun_seconds`, `topple_buildings`, `life_cost`, `cooldown_seconds`, `drain_seconds`, and `stacking_key`. The latter four configure consumed-life cost, successful-activation cooldown, drain-equivalent burst duration, and shared pulse stacking respectively. `delay_seconds` postpones the entire burst, including gameplay, visuals, and sound, in active gameplay time; it defaults to zero. Outcry leaves `stacking_key` empty and is not repeatable.
- Enable the optional variant `phase_return` field for Phase time's return ability.
- Set `projectile_reflection` for Uno's reflect chance percentage, `phase_through_objects` for Phasetastic's object traversal and safe landing, and `voidwalker_duration` for Voidwalker's automatic post-phase immunity seconds.
- Special variant fields are `size_multiplier`, `healing_disabled`, `pacifist`, `proximity_drain_bonus_percent`, `lock_visible_size`, `growth_bonus_retention`, and `phase_size_multiplier`. Set definition `incompatible_ids` to exclude conflicting upgrade IDs.
- Positive percentages increase speed, radius, or distance; signed values above −100% allow penalties. For phase cooldown and resistance, nonnegative percentages below 100 reduce cooldown or damage taken. For example, movement speed `15` means +15% (×1.15), movement speed `-50` means ×0.5, and phase cooldown `20` means a 20% reduction (×0.8). Movement acceleration follows movement speed.
- Open `game/upgrades/upgrade_catalog.tres` to edit the definitions included in the offer pool and their rarity weights. Default Common/Uncommon/Epic/Legendary weights are `59/30/9/2`; weights are relative, not required to total 100.
- Effect descriptions are generated from the variant's stat effects, shockwave configuration, phase-return setting, and special variant settings; do not author separate effect descriptions. Flavor text remains separately editable.

## Overview

| Display title | Status | Rarity | Effect summary |
| --- | --- | --- | --- |
| Thirst | Implemented | C/U/E | Drain speed +10/15/20% |
| Longing | Implemented | C/U/E | Drain radius +15/20/30% |
| Haste | Implemented | C/U/E | Movement speed and acceleration +15/20/30% |
| Phaseless | Implemented | C/U/E/L | Phase cooldown −10/20/30/60% |
| Resistance | Implemented | C/U/E/L | Damage taken −10/15/25/40% |
| Phar | Implemented | C/U/E/L | Phase distance +20/40/60/100% |
| Gonzales | Implemented | L | Movement speed and acceleration ×3 |
| Voidwalker | Implemented | E | After each completed phase, 3 seconds of automatic damage immunity at no cost |
| Phasefull | Implemented | E | Completed-phase shockwave freezes hostiles within current drain radius for 3 seconds; 10 consumed life, 30 active-play-second cooldown |
| Phasetastic | Implemented | E | Phase through objects and land at the nearest safe position |
| Phase time | Implemented | E | One safe instant return to phase start during that phase's cooldown; preserves cooldown |
| Phasplosion | Implemented | L | 0.5 seconds after phase completion, landing shockwave topples buildings within current drain radius and stuns hostiles for 3 seconds; gameplay, visuals, and sound delayed together |
| Outcry | Implemented | E | Once per run; every 30 active play seconds, burst-drain hostiles within current drain radius for 8 seconds of normal drain |
| The Unforgiven | Implemented | L | No healing; drain speed ×5 |
| Godzilla | Implemented | L | Entire linear size curve ×2; movement speed and acceleration ×0.5 |
| The Ape King | Implemented | L | Entire linear size curve ×1.5 |
| Just a little bit closer | Implemented | L | Proximity-based drain speed, up to +300%; drain radius halved |
| Pacifist | Implemented | U | Cannot drain humans or enemies, including tanks; drain speed ×2 |
| The short king | Implemented | E | Starting visible size retained; reduced growth-derived radius, movement speed and acceleration ×0.8 |
| Earthquake | Implemented | E | Topple buildings within current drain radius every 120 active gameplay seconds after pickup |
| Uno | Implemented | E | Reflect projectiles at 50% chance; reflection kills the shooter |

## Implemented upgrades

### Thirst

*“No matter how much you consume, you only want more.”*

- **C/U/E:** Drain speed +10/15/20%.
- Repeatable ordinary stat upgrade; finite target rewards remain unchanged.

### Longing

*“Everything, as far as your eyes can reach, is yours.”*

- **C/U/E:** Drain radius +15/20/30%.
- Repeatable ordinary stat upgrade.

### Haste

*“You must consume. Faster.”*

- Renamed from **Hurryness**.
- **C/U/E:** Movement speed +15/20/30%, with acceleration scaled by the same multiplier.
- Repeatable ordinary stat upgrade.

### Phaseless

*“Phase more.”*

- **C/U/E/L:** Phase cooldown −10/20/30/60%.
- Repeatable ordinary stat upgrade.

### Resistance

*“They can try, but they cannot succeed.”*

- **C/U/E/L:** Damage taken −10/15/25/40%.
- Repeatable ordinary stat upgrade.

### Phar

*“Phase further.”*

- **C/U/E/L:** Phase distance +20/40/60/100%.
- Repeatable ordinary stat upgrade; phase duration stays unchanged.

### Gonzales

*“You are speedy. Very speedy.”*

- **Legendary, once per run:** Movement speed ×3, with acceleration scaled by the same multiplier.

### Earthquake

*“Even earth itself fears you.”*

- **Epic, once per run:** The first shockwave triggers after 120 active gameplay seconds following pickup, then every 120 active gameplay seconds. The timer pauses in menus.
- Each trigger snapshots the current drain radius and affects buildings only within that radius, bypassing size gating. Toppled buildings reward their remaining life exactly once through the normal collapse path and animation.
- **Presentation:** Shares an expanding-wave visual effect and the same muffled, low-pass bass explosion sound with Phasplosion.

### Phasplosion

*“No one saw it coming.”*

- **Legendary, once per run:** Release a shockwave 0.5 active gameplay seconds after each completed phase, never on cancellation. Gameplay effects, visuals, and sound all wait for this delay. Menus and disabled gameplay pause the delay; death or retry discards pending bursts.
- The burst stays at the saved ground-projected landing position even if you move or use Phase time's return during the delay. Current drain radius and affected targets are sampled when the burst fires, before costs or rewards.
- Within that radius, topple buildings regardless of size gating, rewarding their remaining life exactly once through the normal collapse path and animation, as with Earthquake.
- Stun all hostile humans, farmers, and tanks within that radius for 3 seconds. Repeated stuns refresh the duration rather than stacking; already-fired projectiles remain.
- Deals no direct damage and has no extra cost or cooldown.
- **Presentation:** Shares Earthquake's expanding-wave visual effect and the same muffled, low-pass bass explosion sound.

### Phasefull

*“The souls. They are leaking...”*

- **Epic, once per run:** After a completed phase only, release an omnidirectional soul shockwave within the current drain radius that freezes hostiles for 3 seconds. Buildings are unaffected.
- Starts ready. A successful activation costs 10 consumed life and starts a 30-active-play-second cooldown; menus pause the timer. Cancelled phases do not activate it. If consumed life is below 10, skip the wave without paying or starting its cooldown.

### Phase time

*“If only I could turn it back.”*

- **Epic, once per run:** During phase cooldown, press Space again for one instant return to that phase's start position. The destination must be safe; a blocked return keeps the charge for another attempt.
- A successful return consumes the charge but preserves the existing phase cooldown. An unused charge expires when that cooldown ends. Returns do not trigger completed-phase shockwaves.

### Outcry

*“The souls become too much to bear, escaping your body in all directions.”*

- **Epic, once per run:** The first pulse occurs 30 active play seconds after pickup, then every 30 active play seconds. Menus pause the timer; Outcry does not stack.
- Each pulse snapshots the current drain radius and effective drain rate, applying an instant burst equal to 8 seconds of normal drain to hostiles within range, including tanks. Normal size eligibility, target drain efficiency, rewards, and healing apply.
- **Presentation:** A unique ethereal soul burst escaping in all directions, accompanied by an ethereal scream/screech, distinct from other shockwaves' expanding-wave visuals and muffled bass explosion sound.

### Voidwalker

*“Nothing will stop you, no matter what they try.”*

- **Epic, once per run:** After each completed phase, gain 3 seconds of automatic damage immunity at no cost: no hold input, consumed-life drain, or extra cooldown. Cancelled phases do not grant it.
- Another completed phase refreshes the duration to 3 seconds rather than stacking it. Phase cooldown continues concurrently, and normal draining and healing continue during the void. A Phase time return does not refresh it.
- Pauses and upgrade choices freeze the active duration and retain its presentation. Death, retry, and rebirth clear it.
- **Presentation:** The world darkens with thicker black ground fog plus depth fog that extends above the low fog layer, keeping the player and HUD readable at every growth size. All audio, including music, is low-passed. The effect restores the baseline environment, fog, and audio when it ends.

### Phasetastic

*“Nothing can stand in your way.”*

- **Epic, once per run:** Phase travel ignores world geometry. Landing resolves backwards along the phase path to the nearest clear position; if none is clear, the Balancer returns to the phase start.
- Normal collision and cooldown behavior resume when travel ends.

### Uno

*“The most powerful card.”*

- **Epic, once per run:** Each incoming police bullet or tank shell has a fixed 50% chance to reflect back toward its shooter. A reflected projectile kills the shooter through the normal collapse and reward path, except with Pacifist as described below.

### The Unforgiven

- **Legendary, once per run:** All healing is blocked; drain speed ×5 applies independently to every eligible target, including normal and Outcry burst drain. Finite target rewards do not increase.
- **Inspector:** `unforgiven`, drain speed `400`, `healing_disabled = true`. Flavor text is empty.

### Godzilla

*“That ape is just an ant compared to you.”*

- **Legendary, once per run:** Multiply the entire linear size curve by 2, immediately and for future growth. Movement speed and acceleration are multiplied by 0.5 after growth scaling.
- With The Ape King, linear size is ×3 and virtual volume ×27 versus the unmodified curve at the same consumed life. Neither grants life or growth tiers. Incompatible with The short king.
- **Inspector:** `godzilla`, `size_multiplier = 2`, movement speed `-50`, `incompatible_ids = [short_king]`.

### The Ape King

*“Kong is no longer your king.”*

- **Legendary, once per run:** Multiply the entire linear size curve by 1.5, immediately and for future growth. Combines multiplicatively with Godzilla; incompatible with The short king.
- **Inspector:** `ape_king`, `size_multiplier = 1.5`, `incompatible_ids = [short_king]`.

### Just a little bit closer

*“The closer they are, the more dangerous it gets.”*

- **Legendary, once per run:** Halve drain radius. Per target, drain speed rises linearly from ×1 at the edge to ×4 at contact, using approximate horizontal distance to the target surface. This applies to normal drain and each target in an Outcry snapshot.
- **Inspector:** `proximity_drain`, drain radius `-50`, `proximity_drain_bonus_percent = 300`.

### Pacifist

*“Let nature have its way.”*

- **Uncommon, once per run:** Drain speed ×2; normal drain and Outcry ignore all humans and enemies, including tanks. Plants and scenery remain eligible; nonlethal stuns remain allowed.
- Uno still kills reflected shooters, but grants no life, healing, growth, or kill credit. Rewards committed before pickup are not erased.
- **Inspector:** `pacifist`, drain speed `100`, `pacifist = true`.

### The short king

*“Vengeful, like a zombie on a chicken.”*

- **Epic, once per run:** Body, combat collision, camera, and body-local effects stay at initial visible size. Virtual size retains full drain power and target eligibility; the opening fence threshold remains virtual size 2.
- For initial size `S0` and virtual size `S`, radius uses `S0 + 0.2 × (S − S0)`; movement speed and acceleration use normal virtual-size growth `sqrt(S / S0)` and are multiplied by 0.8. Other ordinary stat multipliers apply fully.
- Phase distance uses `0.2 × S` as its size input, with Phar applied afterward; phase duration is unchanged. Incompatible with Godzilla and The Ape King in either order.
- **Inspector:** `short_king`, movement speed `-20`, `lock_visible_size = true`, `growth_bonus_retention = 0.2`, `phase_size_multiplier = 0.2`, `incompatible_ids = [godzilla, ape_king]`.
