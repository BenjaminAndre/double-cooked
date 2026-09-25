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


func _init(p_kind: StringName) -> void:
    kind = p_kind


func fingerprint() -> Array:
    return [kind, basket.fingerprint() if basket else null, frying, cook]
