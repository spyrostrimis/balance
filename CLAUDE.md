# Balance — real-time strategy with heroes (Dune II / C&C / Warcraft III lineage)

Working title: **Balance**. Original setting. Tributes to favourite games and stories are
welcome as *mechanics and archetypes* (a transforming harvester, a giant hazard
creature, hero units with auras) — never as copied names, factions, designs,
sprites, models, sounds or text from existing IP.

Game design, lore and mission specs live in `design/GDD.md`. Read it when a task
touches factions, units, heroes, the resource or missions. This file is technical.

## Goal of v1
Mission 1, fully playable: a small map, 4 units vs 4 units (each side = 1 hero + 3 troops),
fighting for control of the Orichalcum rock in the middle. Spec: `design/GDD.md` → Mission 1.

## Tech stack (fixed — do not change without asking)
- Engine: Godot 4.x, standard build (NOT .NET). PIN: **4.7.2 stable** (official).
  Target: Windows desktop.
- Renderer: Forward+.
- Language: GDScript only. Static typing everywhere (typed vars, typed function
  signatures and return types). Untyped declarations are treated as errors.
- Godot 4 APIs ONLY. Common traps: `await` not `yield`, `@export`/`@onready`,
  4.x signal/Callable syntax, `AStarGrid2D` for pathfinding, `GridMap` for 3D terrain.
  If unsure whether an API exists in the pinned version, say so and check the docs.
- Tests: gdUnit4 addon in `addons/gdUnit4/`.

## Presentation: 3D view on 2D logic
- The simulation is a 2D grid. The view renders it in 3D. They never mix (see Architecture).
- Terrain: `GridMap` with tile meshes, aligned 1:1 with the sim grid.
- Cell size: one constant (`CELL_SIZE`, default 2.0 world units) in one place.
  All grid ↔ world conversion goes through a single helper
  (`grid_to_world(Vector2i) -> Vector3`, `world_to_grid(Vector3) -> Vector2i`).
- Camera: fixed-angle RTS camera (tilted, no rotation in v1), pan with screen
  edges + WASD/arrows + middle-mouse drag (grab the map), zoom with the mouse wheel
  between a min and max, clamped to map bounds.
- Readability: terrain meshes stay inside their own cell. Units hidden behind
  terrain draw a team-coloured silhouette (`view/shaders/occluded_silhouette.gdshader`),
  and selection rings draw on top of everything.
- Picking: mouse clicks are raycast into the 3D scene and converted to grid cells.
  Box selection projects unit positions to screen space and tests them against the box.
- Display: design (base) resolution 1920×1080; the window opens at 1600×900
  (window size override), resizable. Stretch mode `canvas_items`, aspect `expand`
  (UI scales; 3D renders at native resolution, so it's sharp at 1080p, 1440p and 4K).
  F11 and Alt+Enter toggle full screen; Esc leaves full screen
  (`view/app.gd`, autoload `App`). F3 toggles a debug overlay (`App.debug_overlay`)
  for things that are invisible in the game, e.g. aura radii — never show those
  without it.
- Art: stylised low-poly, bright saturated colours, ONE art family (no mixing packs
  with different proportions/styles). Placeholders (primitive meshes, team-coloured)
  until a milestone works. Every external asset is CC0 or own work, listed with its
  source in `assets/CREDITS.md`.

## Architecture — the one rule that matters most
Simulation and presentation are separate.

- `sim/` — pure game logic: grid, units, heroes, abilities, combat, pathfinding,
  objectives, AI. Classes extend `RefCounted` (not `Node`), have no rendering, input
  or scene-tree dependencies, and run on a fixed tick (15 ticks per second),
  independent of frame rate.
- `view/` — scenes and nodes that read sim state and render it in 3D, plus camera,
  input and UI. Input never changes game state directly: it creates commands
  (`MoveCommand`, `AttackCommand`, `AbilityCommand`, …) that the sim executes on its next tick.
  The view interpolates between ticks so movement looks smooth.
- `data/` — unit, hero and ability stats as Resources (`.tres`). No magic numbers in code.

Why: everything in `sim/` can be tested headlessly by running ticks in a test,
without anyone watching the screen — and the view can change (art, camera)
without touching game logic.

## Folder structure
```
design/       GDD.md and other design docs
sim/          pure logic (RefCounted classes)
view/         scenes, 3D rendering, camera, input, UI
data/         stats resources (.tres)
assets/       models, textures, audio, CREDITS.md
tests/        gdUnit4 tests, mirroring sim/ structure
addons/       gdUnit4
build/        export output (git-ignored)
```

## Commands
`godot` = `C:\Godot\Godot_v4.7.2-stable_win64_console.exe` (the *console* exe, so
stdout/stderr reach the terminal). In Git Bash: `/c/Godot/Godot_v4.7.2-stable_win64_console.exe`.

- Smoke test (boots the project, prints errors, quits):
  `godot --headless --path . --quit-after 120`
- Tests (gdUnit4, headless):
  `godot --headless --path . -s -d res://addons/gdUnit4/bin/GdUnitCmdTool.gd -a res://tests --ignoreHeadlessMode -c`
  Exit code 0 = all passed. Reports go to `reports/` (git-ignored).
  If the addon's global classes are missing (fresh clone), run
  `godot --headless --path . --import` once first.
- Self-test (real window, renders, screenshots, quits):
  `godot --path . -- --selftest --frames=120`
  Saves `selftest_<n>.png` screenshots and `selftest.log` to
  `user://selftest/` and prints the absolute path. Optional `--shots=N` (default 3).
  Before each shot `App.selftest_shot` fires; the mission scene snaps the camera to
  5 poses in turn (Blue on the way, the fight twice, whole map, aftermath), so use `--frames=500 --shots=5`. In self-test the sim runs exactly one
  tick per frame (deterministic). The mission scene selects all Blue units, checks
  picking/box selection, and orders an attack on the Red Leader. Heroes use their
  active ability whenever it's ready (Blue through the targeting UI). Shot 2 shows
  the Red Leader inspected (read-only hero panel) or the recovery dropship if one is
  flying, shot 3 has the F3 debug overlay on. The Red Leader starts at 60 HP so its
  recovery runs early, and returns after 12 s instead of 60. The Blue Leader goes down
  around frame 670: use `--frames=1000 --shots=10` to also see the low-HP warning and
  the "Mission failed" screen (the sim stops there).
  It logs each team's units up/downed/in an aura, HP and abilities used per shot;
  scenes add log lines with `App.selftest_note()`.
  Effects tweens run on real time, so a just-killed unit can still show in a shot.
  Use it after every view change to check scale, orientation and that meshes sit
  on the ground — then look at the PNGs.
- Windows build: `godot --headless --path . --export-release "Windows Desktop" build/balance.exe`
  (requires the "Windows Desktop" export preset and export templates, set up once in the editor).

## Working rules
1. Work on ONE milestone at a time. Do not start the next one until I confirm.
2. Every sim feature gets tests. Run the smoke test and the tests after every change;
   a task is not done while either fails.
3. Commit small, with clear messages, after each working step. Commit straight to
   `main` and push — no branches or PRs unless I ask.
4. Never edit files inside `.godot/` or `*.import` files. `.godot/` and `build/` are git-ignored.
5. When a milestone is done, tell me exactly what to playtest and what I should see.
6. When something can only be judged by playing or looking (feel, scale, orientation,
   readability, fun), say so — don't claim it works because it compiles. Use the
   self-test mode to take screenshots and check scale/orientation. A Godot MCP bridge
   (e.g. `@coding-solo/godot-mcp`) is optional and unverified — never depend on it.
7. Design questions (stats, rules, lore) are mine to decide: propose, don't assume.
   Record decisions in `design/GDD.md`.
8. When I should play, launch the game for me in the background with the console exe
   (`godot --path .`) so crash/error output reaches you, and read that output when it exits.
9. Never inject mouse/keyboard input into my desktop.

## Milestones (each must be playable before the next)
1. **Map & camera** — a 32×32-cell mission-1 map in GridMap (passable ground,
   impassable rocks/cliffs, the central Orichalcum rock); RTS camera with pan, zoom
   and bounds; basic lighting and shadows.
   Done when: I can pan and zoom across the whole map smoothly.
2. **Select & move** — placeholder units; click and box selection with selection
   rings; right-click moves the selection.
   Done when: I can select one or many units and send them anywhere open.
3. **Pathfinding** — AStarGrid2D around impassable cells; a group ordered to one spot
   spreads to nearby free cells instead of stacking.
   Done when: units route around obstacles and don't overlap at the destination.
4. **Combat** — two sides, HP, attack range, damage, death; attack command and
   auto-attack of enemies in range; health bars.
   Done when: fights resolve correctly (covered by sim tests too).
5. **Heroes & abilities** — one hero per side with one active and one passive ability
   (see GDD); ability bar with cooldowns; hero portrait.
   Done when: I can use my hero's active ability and see the passive's effect.
6. **Downed heroes** — heroes never die: at 0 HP they are deactivated (downed).
   Player hero downed = mission fails. Low-HP warning (alert, pulsing portrait, sound).
   Enemy hero downed: loses aura/abilities; a recovery unit comes to carry it home
   (rules in GDD).
   Done when: both outcomes work and the warning fires before my hero goes down.
7. **Mission 1** — capture objective at the Orichalcum rock, win/lose conditions,
   mission start/end screens, and an enemy AI that contests the rock, focus-fires,
   uses its hero's abilities and pulls its hero back at low HP.
   Done when: Mission 1 is playable from start to victory or defeat.

Later (order to be decided): harvester and refinery, buildings and production,
fog of war, hazard creatures, Green faction, campaign structure.
