class_name SimItem
extends RefCounted
## Something held in a hand or cooking in a fryer. Plain data; Fryer and Menu hold the rules.

## See Fryer for the fries kinds.
var kind: StringName
## How many portions this is: a whole CUISSON 1 batch, or 1.
var portions := 1
## Menu.MAYO, Menu.ANDALOUSE or Menu.KETCHUP, &"" for none.
var sauce := &""
## A bread's contents (Recipes): its meat, its portion of fries (a baguette), and whether it has
## salad and tomato (a bun).
var filling: SimItem
var fries: SimItem
var veg := false


func _init(p_kind: StringName) -> void:
    kind = p_kind


func fingerprint() -> Array:
    return [kind, portions, sauce, filling.fingerprint() if filling else null,
            fries.fingerprint() if fries else null, veg]
