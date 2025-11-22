# README

## Run the project
Assets to have loaded (should be found on another repo like SVN or even a USB stick)
* ./assets/kenney_prototype-kit : Downloadable here : https://kenney.nl/assets/prototype-kit
* ./godot-extension-webrtc : A prerequisite to use WebRTC on the computer
* ./addons/tube : A needed addon to help find lobbies
* ./addons/debug_draw_3d : How to work without it, seriously ?

## Coding practices
* Things get moved up when needed. Avoid Global event busses at first
* An experiment exists in the git history to showcase how to get to multiplayer
* File structure is "location based" and not "type based"
* Decouple UI : the game should "work" without the UI and vice-versa
