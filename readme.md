# README

## Run the project
Assets to have loaded (should be found on another repo like SVN or even a USB stick)
* ./assets/kenney_prototype-kit : Downloadable here : https://kenney.nl/assets/prototype-kit
* ./godot-extension-webrtc : A prerequisite to use WebRTC on the computer
* ./addons/tube : A needed addon to help find lobbies
* ./addons/debug_draw_3d : How to work without it, seriously ?

`bash tools/fetch_deps.sh` (Git Bash on Windows) downloads the Kenney kit, tube and debug_draw_3d at the versions CI uses. WebRTC for desktop is still manual.

## Build
Every push builds the Web export on GitHub Actions (`.github/workflows/build.yml`). Download it from the run's artifacts.

## Versioning
Semantic versioning, stored in `project.godot` (`config/version`).

## Coding practices
* Things get moved up when needed. Avoid Global event busses at first
* An experiment exists in the git history to showcase how to get to multiplayer
* File structure is "location based" and not "type based"
* Decouple UI : the game should "work" without the UI and vice-versa
