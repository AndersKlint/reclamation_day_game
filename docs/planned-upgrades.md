# Upgrade catalog

The full upgrade catalog contains 21 upgrades: fifteen implemented and six planned. Names are display titles; effect descriptions use ordinary stat names.

## Selection and stacking

- Each card rolls rarity first: Common (C) 59%, Uncommon (U) 30%, Epic (E) 9%, Legendary (L) 2%.
- Each offer contains three distinct upgrade names. There are no rerolls or batched choices; queued level-ups are resolved sequentially.
- Values listed as C/U/E or C/U/E/L correspond to those rarities in order. Three-value upgrades have no Legendary version.
- Ordinary stat upgrades are repeatable and stack multiplicatively, including percentage reductions. Fixed-rarity special upgrades can be selected only once per run.
- Upgraded stats retain their growth scaling. Movement speed and acceleration scale together. Phase distance changes do not change phase duration.
- The base phase cooldown is 8 seconds, eight times the previous 1 second. Phaseless applies its normal multiplicative reductions to this base.
- Increasing drain speed does not increase the total reward available from a finite target.
- Planned effects below preserve design intent; unresolved parameters are not balance commitments.

## Editing upgrades

- Open a per-upgrade `.tres` resource under `game/upgrades/` in the Godot Inspector to edit its title, flavor text, and rarity variants.
- Expand a variant's effects array and add or edit `UpgradeStatEffect` resources. Select the stat (drain speed, drain radius, movement speed, phase cooldown, resistance, or phase distance) and enter its percentage.
- For special shockwaves, edit `UpgradeVariant.shockwave` as a `ShockwaveEffect` alongside stat effects. Its settings are trigger (`PERIODIC` or `PHASE_COMPLETED`), presentation (`SHOCKWAVE` by default, `SOUL_BURST` for Outcry), `interval_seconds`, `delay_seconds`, `radius_multiplier`, `stun_seconds`, `topple_buildings`, `life_cost`, `cooldown_seconds`, `drain_seconds`, and `stacking_key`. The latter four configure consumed-life cost, successful-activation cooldown, drain-equivalent burst duration, and shared pulse stacking respectively. `delay_seconds` postpones the entire burst, including gameplay, visuals, and sound, in active gameplay time; it defaults to zero. Outcry leaves `stacking_key` empty and is not repeatable.
- Enable the optional variant `phase_return` field for Phase time's return ability.
- Set `projectile_reflection` for Uno's reflect chance percentage, `phase_through_objects` for Phasetastic's object traversal and safe landing, and `voidwalker_duration` for Voidwalker's automatic post-phase immunity seconds.
- Positive percentages increase speed, radius, or distance; for phase cooldown and resistance they reduce cooldown or damage taken. For example, movement speed `15` means +15% (×1.15), movement speed `200` means +200% (×3), and phase cooldown `20` means a 20% reduction (×0.8). Movement acceleration follows movement speed.
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
| The Unforgiven | Planned | L | No healing; damage dealt ×5 |
| Godzilla | Planned | L | Current size ×2 on acquisition, twice usual consumed-life size growth, movement speed halved |
| The Ape King | Planned | L | Size +50%; consumed-life growth scales accordingly |
| Just a little bit closer | Planned | L | Proximity-based drain speed, up to +300%; drain radius halved |
| Pacifist | Planned | U | Ignore living creatures; drain speed ×2 |
| The short king | Planned | E | Starting visible size retained; virtual growth with reduced growth-derived radius and speed bonuses |
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

- **Epic, once per run:** Each incoming police bullet or tank shell has a fixed 50% chance to reflect back toward its shooter. A reflected projectile kills the shooter through the normal collapse and reward path.

## Planned upgrades

### The Unforgiven

- **Legendary, once per run:** You can no longer heal, but deal five times as much damage: damage dealt ×5, not damage taken.
- **Flavor:** Unspecified.

### Godzilla

*“That ape is just an ant compared to you.”*

- **Legendary, once per run:** Double current size on acquisition, gain consumed-life size growth at twice the usual rate, and halve movement speed. Acceleration scales with movement speed.
- **Unresolved:** Exact size-growth formula and interactions with other size/growth effects.

### The Ape King

*“Kong is no longer your king.”*

- **Legendary, once per run:** Increase size by 50%; consumed-life growth also scales accordingly.
- **Unresolved:** Precise interpretation of the growth scaling.

### Just a little bit closer

*“The closer they are, the more dangerous it gets.”*

- **Legendary, once per run:** Proximity increases drain speed by up to +300%; halve drain radius.
- **Unresolved:** Proximity falloff.

### Pacifist

*“Let nature have its way.”*

- **Uncommon, once per run:** Ignore living creatures; drain speed ×2.
- **Unresolved:** Which target categories count as living creatures.

### The short king

*“Vengeful, like a zombie on a chicken.”*

- **Epic, once per run:** Lock visible size to starting size. Virtual growth retains drain power and range progression, but growth-derived radius and speed bonuses are reduced by 80%.
- This reduction applies to growth-derived bonuses, not necessarily to total radius or movement speed. Acceleration follows movement speed scaling.
- **Unresolved:** Exact virtual-growth formula and how retained range progression combines with the reduced radius bonus.
