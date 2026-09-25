# README

## Run the project
Assets to have loaded (should be found on another repo like SVN or even a USB stick)
* ./assets/kenney_prototype-kit : Downloadable here : https://kenney.nl/assets/prototype-kit
* ./godot-extension-webrtc : A prerequisite to use WebRTC on the computer
* ./addons/tube : A needed addon to help find lobbies
* ./addons/debug_draw_3d : How to work without it, seriously ?

`bash tools/fetch_deps.sh` (Git Bash on Windows) downloads the Kenney kit, tube and debug_draw_3d at the versions CI uses. WebRTC for desktop is still manual.

## How to play (first slice)
Survive from 18:00 to 04:00 (7 minutes) without the room rioting or the whole crew going down.
1. At CUISSON 1, interact to drop a batch of fries in the oil, and again when the gauge is blue: the batch (5 portions) waits on the fryer. Each further press takes one portion.
2. Put a portion in a CUISSON 2 and lift it in the blue. VIANDES gives a fricadelle (fry it the same way) or a cervelas (cold as is, or warm once fried).
3. At SAUCES, pick mayo or andalouse (or skip it for "nature"). FRIGO gives a cola or a bière. Menus: open with interact, arrows to pick, interact to take, Escape to close.
4. Serve at the CAISSE: whatever you hold goes to the front customer. The right order, done right, makes them happy; anything else sends them off angry. A beer always pleases. The first three customers' tickets show their orders.
5. Forgotten fryers catch fire. Grab the EXTINCTEUR and interact at the fire. At 0 hearts you're K.O.: a teammate next to you gets you up, or you crawl to SOINS.

## Controls
Keys are given by their position on a QWERTY keyboard, so they sit at the same place on AZERTY.
* Solo: arrows to move, Space to interact, Escape to close a station menu, Tab to take damage (debug)
* F2 toggles two players on one keyboard:
  * P1: WASD, Space, Escape
  * P2: arrows, Right Shift, Backspace
* Online (one player per machine): H hosts and shows a code to share, J joins with a code, Enter starts the night (host), Escape leaves. On the Web build WebRTC is built in; desktop builds need the webrtc-native GDExtension.

## Tests
`godot --headless --path . -s addons/gut/gut_cmdln.gd` runs the GUT tests in `tests/`. CI runs them before every build.

## Build
Every push builds the Web export on GitHub Actions (`.github/workflows/build.yml`). Download it from the run's artifacts. Pushes to `main` also publish it to GitHub Pages: https://benjaminandre.github.io/double-cooked/

## Versioning
Semantic versioning, stored in `project.godot` (`config/version`).

## Coding practices
* Things get moved up when needed. Avoid Global event busses at first
* An experiment exists in the git history to showcase how to get to multiplayer
* File structure is "location based" and not "type based"
* Decouple UI : the game should "work" without the UI and vice-versa
