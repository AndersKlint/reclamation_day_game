# Reclamation Day

A dark 3D solo demo about the Balancer, a melancholy spirit that appears at Earth's environmental tipping point. Drain the life around it, grow from a shadow into an overwhelming presence, survive human resistance, and return the accumulated life as new growth.

The current milestone is one seamless rural demo: southern fields and an orchard/farm approach leading north into a contemporary European village. The village is freely accessible from the start; local resistance, not a gate, makes it dangerous. Play is mouse-orbit third person with automatic draining. A run targets 15–20 minutes; that is a pacing goal, not a timer. Full UI, menu, and audio polish is later.

## Play

Open `project.godot` in Godot 4.7 and press **F5**, or from the project root:

```sh
/usr/bin/godot --path .
```

`game/run/run.tscn` retains the earlier compact prototype; open it and press **F6**.

## Controls

- **Mouse:** orbit the third-person camera.
- **WASD / arrows:** camera-relative movement; the Balancer turns toward movement. No jump or sprint.
- **Esc:** pause/resume and release/recapture the cursor. Menus use the mouse or keyboard focus; retry is available from pause and result screens.

Nearby eligible life drains automatically. Drain smaller life first to grow large enough for larger targets. Humans grant growth but do not count toward the finite objective. Drain the placed world life to near completion to trigger the renewal ending; losing all health ends the run.

## Presentation

Fixed dawn/sunrise twilight: an orange sun and warm low horizon under a cold blue-gray upper sky. Mist sits low in the world, so long ground-level views fade while looking up reveals clearer sky. Lamps warm and fade with distance. This is the current visual direction, not final art.

## Docs

- [Vision](docs/vision.md) — current high-level demo decisions and later ideas.
- [Setup](docs/setup.md) — engine commands, build, and environment gotchas.
- [Glossary](GLOSSARY.md) — game terms.
- [Context](context.md) — tiny active handoff.
- [Agent guide](AGENTS.md) — implementation and asset rules.
- [Asset source and credits](available-assets/retro3d-assets/README.md) — upstream collection; commercially usable, no attribution required.
