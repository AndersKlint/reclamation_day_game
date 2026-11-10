# Reclamation Day

A dark 3D solo demo about the Balancer, a melancholy spirit that appears at Earth's environmental tipping point. Drain the life around it, grow from a shadow into an overwhelming presence, survive human resistance, and return the accumulated life as new growth.

The current demo is one seamless region running north from southern fields and an orchard/farm approach, through a village, and into a city. The city adds towers, parks, police, tanks, parked cars, and traffic. It is freely accessible; local resistance, not a gate, makes it dangerous. Play is mouse-orbit third person with automatic draining. Full UI, menu, and audio polish is later.

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
- **Space:** phase forward a short distance in the farmer combat demo; brief invulnerability, then a cooldown.
- **Period / comma:** debug-add / remove 500 life.
- **Page Up / Page Down:** debug-add / remove 50,000 life.

Nearby eligible life drains automatically. Drain smaller life first to grow large enough for larger targets. At growth thresholds, choose an upgrade; the UI can apply one upgrade type to all currently queued rewards. Humans and tanks grant growth but do not count toward the finite objective. Drain 90% of the placed world life to trigger the renewal ending, which ends the run; losing all health also ends it. Debug life reduction does not revoke or re-award upgrade tiers already earned.

## Presentation

Fixed dawn/sunrise twilight: an orange sun and warm low horizon under a cold blue-gray upper sky. Mist sits low in the world, so long ground-level views fade while looking up reveals clearer sky. Lamps warm and fade with distance. This is the current visual direction, not final art.

## Docs

- [Vision](docs/vision.md) — current high-level demo decisions and later ideas.
- [Setup](docs/setup.md) — engine commands, build, and environment gotchas.
- [Glossary](GLOSSARY.md) — game terms.
- [Context](context.md) — tiny active handoff.
- [Agent guide](AGENTS.md) — implementation and asset rules.
- [Asset source and credits](available-assets/retro3d-assets/README.md) — upstream collection; commercially usable, no attribution required.

## Credits

- Farmer model: Max Damage (`maxdamage_farmer_v1.0`). Credit is required by its license; see `docs/assets.md`.
