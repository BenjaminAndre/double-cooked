# double-cooked

A keyboard-only multiplayer game about surviving the night in a Belgian fritkot, made with Godot 4.7 and GDScript. **[docs/GDD.md](docs/GDD.md) is the reference for gameplay**: read the relevant section before changing a rule, and update it when a decision changes.

## Workflow

- Work directly on `main`. Commit each change set, but ask before pushing.
- **Bump `config/version` in `project.godot` in every commit**, as semantic versioning. Only the patch number goes up (0.1.x) until the user announces v0.2.
- Each push builds, tests and deploys the Web export (`.github/workflows/build.yml`), to https://benjaminandre.github.io/double-cooked/.

## Commands

`godot` is on the PATH (it wraps the console exe). Run it from PowerShell: Git Bash doesn't resolve `godot.cmd`.

```
godot --headless --path . --import                   # after adding scripts or assets (registers class_names)
godot --headless --path . -s addons/gut/gut_cmdln.gd # all tests (GUT, config in .gutconfig.json)
godot --headless --path . --quit-after 300           # run the game briefly and check the log for errors
godot --path . --resolution 64x64 -s res://tools/screenshot.gd -- out.png 3 crowd
```

The last command renders a 1280×720 screenshot to check a layout (setups are listed in the script). **Never pop a window on the user's monitor.** The script shrinks its window, moves it off-screen at runtime and renders into a SubViewport. Headless can't render, a minimized window renders blank, and `--position` at startup gets pulled back on screen.

`bash tools/fetch_deps.sh` downloads the git-ignored `assets/` and `addons/` folders at pinned versions. On this machine, set `CURL_EXTRA=--ssl-revoke-best-effort`. The "invalid UID" warnings for Kenney models are expected: those UIDs are generated per machine.

## Architecture (GDD §9.1)

- `simulation/` holds the whole game state and its rules, as plain `RefCounted` classes. It is **deterministic**:
  - integer ticks (`Simulation.TICK_RATE`), never a float `delta`;
  - one seeded `rng`;
  - players act only through `Simulation.Command` values, and in slot order;
  - no `Input`, clock or scene tree.
  Keep it that way: every new rule goes here, with tests.
- `gameplay/` holds the scenes, which only display the state:
  - `Night` owns the simulation, turns keys into commands (`LocalInput`) and calls `Player.show_state()`;
  - `LevelReader` turns the `Anchor` graph into a `SimLevel`;
  - stations are `Interactible` nodes identified by `kind`, and their effects live in `Simulation`.
- `network/` handles online play:
  - `NightLink` holds the RPCs. The host relays each tick's commands to the clients, who re-simulate, plus a fingerprint every second.
  - `Lobby` is the keyboard-only Tube UI. It creates the `TubeClient` only on demand, because the client takes over the tree's multiplayer API.
- `tests/` contains unit tests and Scenario tests: a level, spawns, a seed and a timeline of `{tick, slot, command}` (`tests/scenario.gd`).
  - A bug found while playing should become a scenario: `Scenario.from_replay()` reads the replays that Night saves in `user://replays`.
  - Online tests run a host and a client in one process, connected by `LoopbackPeer` (in memory).
  - **Tests must never open sockets or ports.** This machine has no firewall rights, and CI doesn't need network access either.

## Conventions

- Indent with 4 spaces, give functions typed signatures, and add a `##` doc comment on each class and on non-obvious members.
- From the readme:
  - move things up only when needed, with no global event bus to start with;
  - organise files by location, not by type;
  - the game must work without the UI, and the UI without the game.
- Bind input actions to **physical** keys, because the user has an AZERTY keyboard. Describe keys by their QWERTY position.
- In-game text is meant to be French (GDD §9). Some older labels are still in English.
- Don't edit `.godot/`. Commit the `*.uid` files that Godot generates next to new scripts.
