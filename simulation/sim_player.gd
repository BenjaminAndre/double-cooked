class_name SimPlayer
extends RefCounted
## One player's state inside the Simulation. Plain data: the rules live in Simulation.

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
## What the player holds (one hand, GDD §5.4). null is an empty hand.
var item: SimItem
## Knocked out at 0 hearts: crawls, blocks their node, and can only eat, drink or use the
## FRIGO (GDD §5.1).
var down := false
## Body mass index (GDD §5.1): up with every bite, down as they walk. Set from SimRules.
var bmi := 21
## Nodes walked since the last BMI point burnt.
var walked := 0
## Ticks left stunned after being bumped: no moving, no acting (GDD §5.3).
var stun := 0
## Ticks spent standing next to a fire since the last heart it cost.
var exposure := 0
## Station whose menu this player has open, or SimLevel.NONE; menu_choice is the selected
## option (GDD §5.4).
var menu := SimLevel.NONE
var menu_choice := 0
## Aiming a beer: the place in line targeted, or -1; aim_ticks counts how long interact has
## been held (GDD §8).
var aim := -1
var aim_ticks := 0
## When aiming at a teammate instead of the line: their slot, else -1.
var aim_player := -1


func _init(p_slot: int, p_node: int) -> void:
    slot = p_slot
    node = p_node


func is_moving() -> bool:
    return edge_ticks > 0


## The node this player blocks: where they stand, or where they are walking to.
func occupied_node() -> int:
    return path[0] if is_moving() else node


func fingerprint() -> Array:
    return [node, path, progress, edge_ticks, health, item.fingerprint() if item else null, down,
            stun, exposure, menu, menu_choice, aim, aim_ticks, aim_player, bmi, walked]
