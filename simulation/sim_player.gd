class_name SimPlayer
extends RefCounted
## One player's state inside the Simulation. Plain data: the rules live in Simulation.

enum Hand { LEFT, RIGHT }

const MAX_HEALTH := 3

var slot: int
## Last node reached. While walking, the player is between node and path[0].
var node: int
## Nodes still to walk through. path[0] is the one being walked to.
var path: Array[int] = []
## Ticks walked on the current edge, out of edge_ticks. edge_ticks is 0 when standing.
var progress := 0
var edge_ticks := 0
var health := MAX_HEALTH
var focus := Hand.LEFT


func _init(p_slot: int, p_node: int) -> void:
    slot = p_slot
    node = p_node


func is_moving() -> bool:
    return edge_ticks > 0


## The node this player blocks: where they stand, or where they are walking to.
func occupied_node() -> int:
    return path[0] if is_moving() else node
