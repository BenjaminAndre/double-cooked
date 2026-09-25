class_name Interactible
extends Node3D
## A station the player can interact with from an Anchor. What it does is a Simulation
## rule, keyed by kind (see Simulation._interact).

## Empty means the station does nothing yet.
var kind : StringName = &""
