class_name SimStation
extends RefCounted
## One station's state. Only the fryers hold any so far.

var kind: StringName
## The basket in the oil, or resting on the fryer. null when the fryer is free.
var basket: SimItem
## Whether the basket is in the oil (as opposed to resting on CUISSON 1).
var frying := false
## Ticks the basket has spent in the oil.
var cook := 0
## On fire: unusable until put out, and dangerous to stand next to.
var burning := false
## Ticks since the fire started or last spread.
var burn_ticks := 0
## FRIGO only: what is left of each drink (Menu.DRINKS -> count), and ticks towards the next
## one coming back (GDD §7.2). Every drink is stocked, so every drink is limited.
var stock := {}
## A CAISSE: whether its BB gun is under the counter (GDD §8).
var gun := false
## Wrecked by the car (GDD §6.4): it does nothing for the rest of the night.
var destroyed := false
var restock := 0


func _init(p_kind: StringName) -> void:
    kind = p_kind


func fingerprint() -> Array:
    return [kind, basket.fingerprint() if basket else null, frying, cook, burning, burn_ticks, stock,
            restock, gun, destroyed]


## FRIGO: how many of this drink are left.
func left(drink: StringName) -> int:
    return stock.get(drink, 0)
