class_name SimItem
extends RefCounted
## Something held in a hand or cooking in a fryer. Plain data; Fryer holds the rules.

## See Fryer for the fries kinds.
var kind: StringName
## How many portions this is: a whole CUISSON 1 batch, or 1.
var portions := 1
var sauce := false


func _init(p_kind: StringName) -> void:
    kind = p_kind


func fingerprint() -> Array:
    return [kind, portions, sauce]
