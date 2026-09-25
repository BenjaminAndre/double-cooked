class_name SimItem
extends RefCounted
## Something held in a hand or cooking in a fryer. Plain data; Fryer holds the rules.

## See Fryer for the fries kinds.
var kind: StringName
## Ticks rested since the first fry, for FRIES_RESTING.
var rest := 0
## Whether the fries had rested long enough when they went into CUISSON 2.
var rested := false
var sauce := false


func _init(p_kind: StringName) -> void:
    kind = p_kind


func fingerprint() -> Array:
    return [kind, rest, rested, sauce]
