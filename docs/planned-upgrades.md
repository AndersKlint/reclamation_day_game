# Upgrade catalog

The full upgrade catalog contains 21 upgrades: nine implemented and twelve planned. Names are display titles; effect descriptions use ordinary stat names.

## Selection and stacking

- Each card rolls rarity first: Common (C) 59%, Uncommon (U) 30%, Epic (E) 9%, Legendary (L) 2%.
- Each offer contains three distinct upgrade names. There are no rerolls or batched choices; queued level-ups are resolved sequentially.
- Values listed as C/U/E or C/U/E/L correspond to those rarities in order. Three-value upgrades have no Legendary version.
- Ordinary stat upgrades are repeatable and stack multiplicatively, including percentage reductions. Fixed-rarity special upgrades can be selected only once per run.
- Upgraded stats retain their growth scaling. Movement speed and acceleration scale together. Phase distance changes do not change phase duration.
- Increasing drain speed does not increase the total reward available from a finite target.
- Planned effects below preserve design intent; unresolved parameters are not balance commitments.

## Editing upgrades

- Open a per-upgrade `.tres` resource under `game/upgrades/` in the Godot Inspector to edit its title, flavor text, and rarity variants.
- Expand a variant's effects array and add or edit `UpgradeStatEffect` resources. Select the stat (drain speed, drain radius, movement speed, phase cooldown, resistance, or phase distance) and enter its percentage.
- For special shockwaves, edit `UpgradeVariant.shockwave` as a `ShockwaveEffect` alongside stat effects. Its settings are trigger (`PERIODIC` or `PHASE_COMPLETED`), `interval_seconds`, `radius_multiplier`, `stun_seconds`, and `topple_buildings`.
- Positive percentages increase speed, radius, or distance; for phase cooldown and resistance they reduce cooldown or damage taken. For example, movement speed `15` means +15% (×1.15), movement speed `200` means +200% (×3), and phase cooldown `20` means a 20% reduction (×0.8). Movement acceleration follows movement speed.
- Open `game/upgrades/upgrade_catalog.tres` to edit the definitions included in the offer pool and their rarity weights. Default Common/Uncommon/Epic/Legendary weights are `59/30/9/2`; weights are relative, not required to total 100.
- Effect descriptions are generated from the variant's stat effects and shockwave configuration; do not author separate effect descriptions. Flavor text remains separately editable.

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
| Voidwalker | Planned | E | Hold Space after a phase to enter the void; immunity at a continuous consumed-life cost |
| Phasefull | Planned | E | After-phase fear shockwave; 10 consumed life, 30-second cooldown |
| Phasetastic | Planned | E | Phase through objects |
| Phase time | Planned | E | Press Space during phase cooldown to return to the position the phase started from |
| Phasplosion | Implemented | L | Completed-phase landing shockwave topples buildings within current drain radius and stuns hostiles for 3 seconds |
| Outcry | Planned | C/U/E/L | Nearby damage every 30 seconds, equal to 3/5/8/12 seconds of drain damage |
| The Unforgiven | Planned | L | No healing; damage dealt ×5 |
| Godzilla | Planned | L | Current size ×2 on acquisition, twice usual consumed-life size growth, movement speed halved |
| The Ape King | Planned | L | Size +50%; consumed-life growth scales accordingly |
| Just a little bit closer | Planned | L | Proximity-based drain speed, up to +300%; drain radius halved |
| Pacifist | Planned | U | Ignore living creatures; drain speed ×2 |
| The short king | Planned | E | Starting visible size retained; virtual growth with reduced growth-derived radius and speed bonuses |
| Earthquake | Implemented | E | Topple buildings within current drain radius every 120 active gameplay seconds after pickup |
| Uno | Planned | C/U/E/L | Reflect projectiles at 20/40/60/100% chance; reflection kills the shooter |

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

- **Legendary, once per run:** Release a shockwave at the landing position after each completed phase, never on cancellation. Each trigger snapshots the current drain radius.
- Within that radius, topple buildings regardless of size gating, rewarding their remaining life exactly once through the normal collapse path and animation, as with Earthquake.
- Stun all hostile humans, farmers, and tanks within that radius for 3 seconds. Repeated stuns refresh the duration rather than stacking; already-fired projectiles remain.
- Deals no direct damage and has no extra cost or cooldown.
- **Presentation:** Shares Earthquake's expanding-wave visual effect and the same muffled, low-pass bass explosion sound.

## Planned upgrades

### Voidwalker

*“Nothing will stop you, no matter what they try.”*

- **Epic, once per run:** Hold Space after a phase to enter the void. While in the void, gain damage immunity and continuously lose consumed life.
- **Unresolved:** Consumed-life loss rate and behavior at zero consumed life.

### Phasefull

*“The souls. They are leaking...”*

- **Epic, once per run:** After a phase, release an omnidirectional soul shockwave that freezes enemies in fear. Costs 10 consumed life and has a 30-second cooldown.
- **Unresolved:** Fear duration, shockwave range, and behavior when the cost is unaffordable.

### Phasetastic

*“Nothing can stand in your way.”*

- **Epic, once per run:** Phase through objects.
- **Unresolved:** Safe exit and blocked-landing behavior.

### Phase time

*“If only I could turn it back.”*

- **Epic, once per run:** During phase cooldown, press Space again to return to the position the phase started from.
- **Unresolved:** Return safety, cooldown behavior after returning, and how many return uses are allowed per phase.

### Outcry

*“The souls become too much to bear, escaping your body in all directions.”*

- **C/U/E/L, repeatable:** Deal damage nearby every 30 seconds, equal to 3/5/8/12 seconds of drain damage.
- **Unresolved:** Damage radius and when drain damage is sampled.

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

### Uno

*“The most powerful card.”*

- **C/U/E/L, repeatable:** 20/40/60/100% chance to reflect a projectile back at its shooter, killing the shooter.
- **Unresolved:** Eligible projectile types and shooter handling.
