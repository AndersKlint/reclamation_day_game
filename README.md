# Reclamation Day

A dark 3D solo demo about the Balancer, a melancholy spirit that appears at Earth's environmental tipping point. Drain the life around it, grow from a shadow into an overwhelming presence, survive human resistance, and return the accumulated life as new growth.

The current demo begins inside an enclosed wheatfield. Gather wheat life; a farmer arrives after 30 seconds of active play. Escape by reaching HUD SIZE 2.00×, draining a perimeter fence, and walking through the gap; the farmer can remain alive. Alternatively, break his endurance and stay close until he is fully consumed; only this opens the northern gate. Either route continues the same run north through an orchard/farm approach, a village, and a city with towers, parks, police, tanks, parked cars, and traffic. Beyond the farm, local resistance rather than further gates supplies danger. Play is mouse-orbit third person with automatic draining. Full UI, menu, and audio polish is later.

## Play

Open `project.godot` in Godot 4.7 and press **F5**, or from the project root:

```sh
/usr/bin/godot --path .
```

`game/run/run.tscn` retains the earlier compact prototype; open it and press **F6**.

### Farmer combat demo

`game/demo/farmer_combat/farmer_combat_demo.tscn` is an isolated 60 × 60 m wheatfield encounter: one farmer, wheat across the arena, and a blocking crate. Open the scene in the editor and press **F6**, or run:

```sh
/usr/bin/godot --path . res://game/demo/farmer_combat/farmer_combat_demo.tscn
```

Wheat drains automatically. Break the farmer's endurance, then stay close until the farmer is consumed. Esc pauses and retries reset the encounter.

## Controls

- **Mouse:** orbit the third-person camera.
- **WASD / arrows:** camera-relative movement; the Balancer turns toward movement. No jump or sprint.
- **Esc:** pause/resume and release/recapture the cursor. Menus use the mouse or keyboard focus; retry is available from pause and result screens.
- **Space:** phase a short distance in the movement direction (or facing direction while still), with brief invulnerability followed by a cooldown. Available throughout the main demo and in the farmer combat demo.
- **Period / comma:** debug-add / remove 500 life.
- **Page Up / Page Down:** debug-add / remove 50,000 life.

Nearby eligible life drains automatically. Drain smaller life first to grow large enough for larger targets. Each level offers three random upgrade choices with rarity borders; queued level-up choices are resolved sequentially. The farmer, other humans, and tanks grant growth but do not count toward the finite objective; wheat and farm trees do count. Opening perimeter fences become drainable at HUD SIZE 2.00× even before the opening is completed. Human and tank escalation begins after either fence escape or full farmer consumption, without counting time spent in the opening. Neither route is a separate victory. Drain 90% of the placed world life to trigger the renewal ending, which ends the run; losing all health also ends it. Debug life reduction does not revoke or re-award upgrade tiers already earned.

Each eligible target receives the full drain rate independently, not a shared budget. In the main demo, drain rate is exactly `0.051 × model scale × drain speed upgrade multiplier` life/s per target. Opening wheat converts one-third of the requested drain into life transfer, preserving its life rewards and withering timing: at starting scale 0.5, each patch takes about 10 active seconds to visibly wither; growth during draining can shorten this. Its remaining 80% life transfers over one further active second. Farmer drain efficiency is 0.03, reducing effective endurance without changing life rewards. Movement speed and acceleration scale with `sqrt(model scale / initial scale)` and the movement upgrade multiplier, without upper caps. Without upgrades, main-demo speed is about 1.824 m/s at spawn, 2.339 m/s at farmer height (1.9 m), and 3.308 m/s at twice farmer height (3.8 m).

## Presentation

Fixed dawn/sunrise twilight: an orange sun and warm low horizon under a cold blue-gray upper sky. Mist sits low in the world, so long ground-level views fade while looking up reveals clearer sky. Lamps warm and fade with distance. This is the current visual direction, not final art.

## Docs

- [Vision](docs/vision.md) — current high-level demo decisions and later ideas.
- [Upgrade catalog](docs/planned-upgrades.md) — implemented upgrades and deferred effects.
- [Setup](docs/setup.md) — engine commands, build, and environment gotchas.
- [Glossary](GLOSSARY.md) — game terms.
- [Context](context.md) — tiny active handoff.
- [Agent guide](AGENTS.md) — implementation and asset rules.
- [Asset source and credits](available-assets/retro3d-assets/README.md) — upstream collection; commercially usable, no attribution required.

## Credits

- Farmer model: Max Damage (`maxdamage_farmer_v1.0`). Credit is required by its license; see `docs/assets.md`.
