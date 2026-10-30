# Project setup

## Prerequisites

- Godot 4.7.2 from DNF at `/usr/bin/godot` (Forward Plus, Jolt Physics).
- Blender at `/usr/bin/blender` for direct `.blend` import.
- `available-assets/retro3d-assets/` is a developer-managed submodule. If it is empty, report the missing source rather than replacing it. Some source models lack texture bindings; game-local wrappers restore them without editing the submodule.
- Other packs in `available-assets/`, including `music/` and `sfx/`, stay local and Git-ignored; back them up separately and restore them after cloning. The root `.ignore` keeps them searchable by OpenCode. See `docs/assets.md` for the asset discovery catalog.
- GodotPrompter skills and `godot4-full-control` MCP for agent work; direct engine calls are fine for headless checks.

This is a GDScript-first project. No .NET or gameplay addon setup is required.

## Commands

Run from the project root:

```sh
/usr/bin/godot --version
/usr/bin/godot --editor --path .
/usr/bin/godot --path .
```

Headless import after asset changes, with no editor open on the project:

```sh
/usr/bin/godot --headless --editor --path . --import
```

The collection import can take time; reuse the existing cache for focused code and scene checks. Direct `.blend` import uses Blender; keep its executable configured in Godot's editor settings if automatic detection fails.

## Build

The Linux preset exports an explicit resource list to a resource pack:

```sh
/usr/bin/godot --headless --audio-driver Dummy --path . --export-pack Linux builds/reclamation-day.pck
```

`builds/reclamation-day.pck` requires Godot and is not a standalone executable. Matching standalone export templates are not installed; a full executable export needs them. Add new resources to the preset's export list as they are introduced, or the pack will miss them.

## Environment gotchas

- `opencode.json` sets `GODOT_PATH` to `/usr/bin/godot`; it must be an executable path, not a shell command. Restart OpenCode after changing it.
- The DNF installs replace the earlier Flatpak workaround. The old `~/software/godot/` install was removed; do not reference it.
- The Firejail profile grants write access to `~/.config/godot`, `~/.local/share/godot`, and `~/.cache/godot`. The developer edits `~/.config/firejail/strict-dev.profile`; agents must not modify it.
- Graphical runs can log a sandbox PulseAudio cookie restriction; headless checks use `--audio-driver Dummy`. Audio is not fixed.
