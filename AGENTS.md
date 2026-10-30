# Reclamation Day — Agent Guide

## Project

- This is a **Godot 4.x 3D solo demo**. Use Godot 4 APIs and syntax; check `project.godot` and the installed engine for the current version. Godot 3 examples are incompatible.
- Focus on a playable rural, third-person, automatic-draining prototype. Keep scope tight; prioritise implementation over process.
- Ask few, batched, high-level questions only for consequential scope or taste decisions.

## Docs

- `README.md`: running the game and controls.
- `docs/vision.md`: concise current high-level demo direction, with later ideas clearly separated.
- `docs/setup.md`: practical setup and build gotchas.
- `GLOSSARY.md`: game terminology only, when useful; keep implementation details out.
- `context.md`: at most a tiny active handoff.
- Update docs only when durable direction or run/setup instructions change—not after every task. Skip plans, progress/verification logs, and minor tuning (e.g. fog values).

## Skills and tools

- Load the matching **GodotPrompter** domain skill before implementing a Godot system; add skills as the work crosses domains.
- Use **`godot4-full-control` MCP** for project inspection, scene/resource operations, editor control, and runtime debugging. Use direct file edits when clearer or more precise; prefer targeted patches over whole-file rewrites.
- After code changes, run `godot-code-review` and address major findings, then run a relevant Godot parse/import/build check.
- Docs-only changes need no engine run.
- Gameplay and visual playtesting belong to the developer; agents do technical checks only unless asked.
- Do not write or run unit tests unless explicitly requested.
- The developer handles Git. Do not run Git operations unless explicitly requested.

## Implementation

- Prefer typed GDScript, small cohesive scenes, composition, and explicit dependencies. Introduce autoloads or abstractions only for a concrete need.
- Keep related scenes, scripts, and resources together by feature. Create directories as needed rather than scaffolding speculative systems.
- Use `snake_case` for files, folders, functions, and variables; `PascalCase` for node and class names.
- Use Input Map actions for gameplay controls and Godot 4's 3D node types for world systems.
- Write self-documenting code. Comments must be single-line explanations of non-obvious reasons; omit explanatory docstrings and summaries.
- Preserve engine-generated resource references. Keep `.godot/` out of version control; retain required `.uid` and `.import` sidecars.
- No overengineering or backwards compatibility unless requested.

## Media assets

- Search **`available-assets/` first** for models, textures, and other media, including `random-packs/`; search **`available-music/`** for music. These local libraries are Git-ignored but searchable through `.ignore`. Start with `available-assets/retro3d-assets/README.md` for the upstream collection.
- `available-assets/retro3d-assets/` is a Git submodule. Treat it as upstream source material; keep game-specific scenes, materials, and adaptations outside it.
- Reuse suitable assets through Godot resources and wrapper scenes. Keep source paths and texture dependencies intact; avoid copying the entire collection into another directory.
- Use the `assets-pipeline` skill when import settings or asset conversion are involved. Verify assets in-engine for scale, orientation, materials, and collision needs.
