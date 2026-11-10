# Asset discovery catalog

Use this pack-level map with the filename-first workflow in `AGENTS.md`. Descriptions below come from directory names, filenames, and existing text metadata; they do not certify appearance or sound. Root paths are project-relative; table entries are relative to their stated root. Preserve spaces in paths.

## Search aids

- Search existing game references under `game/` for reusable scenes, materials, and audio resources.
- Use targeted filename globs under the roots below, then search relevant `index.json` files by name/path. Follow up with related terms: `shed`, `shack`, `house`; `grass`, `gravel`, `step`; `drain`, `water`, `suction`.
- Model indexes can provide names, paths, categories, dimensions, and variant families. Search matching entries rather than loading entire indexes. Resolve indexed paths relative to the directory holding the index and verify the source still exists.
- Prefer existing game wrappers and directly usable exports when equivalent versions exist. Keep alternate formats and numbered audio takes together as one candidate family during discovery.
- Read a shortlisted pack's README or license for source-specific instructions. Generate no new catalog entries from guessed visual or audio qualities.
- The Kit Browser addon can render thumbnails while indexing. Read existing indexes for discovery; reserve index rebuilding for an explicit indexing task.

## General packs

Root: `available-assets/random-packs/`. Its root `index.json` and several pack-local indexes are available search aids; search the filesystem too when an asset type or pack is absent from an index.

| Directory under root | Filename-based search focus |
| --- | --- |
| `characters/` | `Characters_Extras_01`, `Characters_psx_1.2`; character models |
| `Cordatix_PSXBystanders_FreeSampler_v1.0/` | Bystanders, office worker, young man, station bench/lamp; Blender and FBX exports |
| `PSX Graveyard Demo/` | Graveyard assets |
| `PSX_Forest_Level_byStarkCrafts/` | Forest level assets |
| `PSX_Daysky_HDRI/` | Day sky HDRI |
| `PSX_Nightsky_HDRI/` | Night sky HDRI |
| `Street Furniture/` | Street furniture and props |
| `maxdamage_farmer_v1.0/` | Max Damage farmer model (`.blend`) and texture; credit Max Damage and do not redistribute; used by the farmer combat demo. |

## Retro 3D collection

Root: `available-assets/retro3d-assets/`. Read its `README.md` for upstream pack descriptions and source links. Many category directories have an `index.json`; use these for specific model lookup. Keep this developer-managed submodule as source material.

| Directories under root | Search focus |
| --- | --- |
| `Buildings/`, `Doors/`, `Windows/`, `Roof/` | Houses, sheds, shacks, building parts and openings |
| `Nature/`, `Rocks/`, `Ground/`, `Water/`, `Raven_and_fish/` | Vegetation, terrain materials, rocks, water, animals |
| `Furniture/`, `Boxes_Barrels_Crates/`, `Tools/`, `Industrial/`, `Electrical/` | Furnishings, containers, tools, machinery and electrical props |
| `Road/`, `Vehicles/`, `Signs/` | Road pieces, transport, signage |
| `Characters/`, `Units/`, `Weapons/` | Characters, units and equipment |
| `Large_kits/` | `3D Retro Medieval Fantasy Kit`, `Models pack psx`; broad mixed kits |
| `Bricks/`, `Concrete/`, `Floor/`, `Metal/`, `Panels/`, `Tiles/`, `Walls/`, `Wood/`, `png/` | Surface and texture search starting points; confirm actual file types |
| `Art/`, `Books/`, `Food/`, `Gems/`, `Misc/`, `Papers/`, `Products/`, `Tech/`, `Video_games/` | Other props and category-specific assets |

## Sound effects

Root: `available-assets/sfx/`. Search filenames within the relevant pack before reading audio or opening cover images. Pack placement is a starting point: some folders here also contain music.

| Directory under root | Filename/directory-based search focus |
| --- | --- |
| `footsteps_krotosaudio/` | Carpet, concrete, grass, gravel, hardwood, metal, wood planks; footwear and numbered takes |
| `clothesandmovementfoley_krotosaudio/` | Clothing and movement foley |
| `surfaces_krotosaudio/` | Surface sounds |
| `elementswaterfireicesnowwind_krotosaudio/` | Water, fire, ice, snow, wind |
| `ambiences_krotosaudio/` | Location and travel ambience; city, office, train, vehicle, air travel |
| `animalsandmonsters_krotosaudio/`, `orcsandbeastsfxpack/` | Animals, monsters and creatures |
| `mechanical_krotosaudio/` | Mechanical sounds |
| `inventorysfxbundle/` | Inventory interactions |
| `gamemusicstingersanduisfxpackpack2/` | `UI_SFX/`, `Stingers_Jingles/`, `Music/` |
| `magic_krotosaudio/`, `magicspellssfxbundle/` | Magic and spells |
| `whooshes_krotosaudio/` | Whooshes and movement accents |
| `fleshandcombatfoley_krotosaudio/`, `hand-to-handcombat_krotosaudio/`, `meleecombat_krotosaudio/` | Impact, flesh, hand-to-hand and melee foley |
| `gunfoley_krotosaudio/`, `real-worldweapons_krotosaudio/`, `sci-fiweapons_krotosaudio/` | Weapon handling and weapon sounds |
| `cinematictrailersounds_krotosaudio/` | Cinematic/trailer sounds |
| `medievalfantasysfxpack/` | Medieval/fantasy sounds |
| `prosoundcollection/` | Broad collection under `Gamemaster Audio - Pro Sound Collection v1.3 - 16bit 48k/` |
| `battlerpgmusicpack/` | `Music/`, `Music Stingers/` |

Example candidate family: `footsteps_krotosaudio/Grass/Grass_Boots_FullStep_*.wav`. Select the footwear/surface family before inspecting individual takes.

## Music

Root: `available-assets/music/`.

| Directory under root | Contents by filename |
| --- | --- |
| `PSX Ambient Pack/` | `license.txt`; `Tracks/` contains `Blur`, `Distant`, `Drift`, `Echo`, `Faded`, `Glow`, `Hollow`, `Lost`, `Still`, `Veil` as WAV files |

For additional music and transition cues, search `sfx/battlerpgmusicpack/` and `sfx/gamemusicstingersanduisfxpackpack2/` under `available-assets/`. Track titles alone do not establish mood, tempo, duration, or loop suitability; inspect metadata and request auditioning when selection depends on those qualities.

## Maintenance

Update this map when packs are added, removed, or relocated, or when a useful non-obvious search term is confirmed. Keep file inventories in the filesystem and existing indexes; keep game-specific adaptations with their feature under `game/`. Missing local packs should be reported rather than replaced by empty stand-ins.
