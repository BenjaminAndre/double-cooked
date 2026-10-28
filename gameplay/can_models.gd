class_name CanModels
extends RefCounted
## The artist's cans (docs/art/Readme_SettingsV3.txt): a Jupiler for a beer, thrown or on the
## beer helmet, and the folded can that angry customers throw. Drawn unlit, centred.

const BEER := preload("res://art/models/DoubleCooked_Jupiler.fbx")
const COLA := preload("res://art/models/DoubleCooked_Coca.fbx")
const FOLDED := preload("res://art/models/DoubleCooked_FoledCan.fbx")
## In flight they are drawn bigger than life (a real can is 19 cm), to be seen across the kitchen.
const FLIGHT_SCALE := 1.4


static func beer(scale := 1.0) -> Node3D:
    return _model(BEER, scale)


## A thrown drink (DLC 1: any drink): the Jupiler can for the beers, the Coca can for the sodas
## (the artist has no Maes or Sprite model).
static func drink(kind: StringName, scale := 1.0) -> Node3D:
    return _model(BEER if kind in Menu.BEERS else COLA, scale)


static func folded(scale := 1.0) -> Node3D:
    return _model(FOLDED, scale)


static func _model(scene: PackedScene, scale: float) -> Node3D:
    var model: Node3D = scene.instantiate()
    model.scale = Vector3.ONE * scale
    UnlitArt.apply(model)
    return model
