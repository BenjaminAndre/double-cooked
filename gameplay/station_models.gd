class_name StationModels
extends RefCounted
## Dresses a station with the artist's models (docs/ART_PLAN.md). Every model has its front
## towards +x and its length along z; GridRoom turns the station so the front faces its cells.
##
## The fryer is one 3 m unit: raw fries at one end, cooked fries in the middle, two baskets at
## the other end. It covers CUISSON 1 (two cells) and the CUISSON 2 next to it; another CUISSON 2
## gets a 1 m counter with a basket taken from the fryer, until the artist draws a module.

const MODELS := "res://art/models/DoubleCooked_%s.fbx"
## The 1 m counter is drawn 0.46 m high; it stands twice that, level with the fryer.
const COUNTER_HEIGHT := 2.0
const COUNTER_TOP := 0.46 * COUNTER_HEIGHT
const FRYER_TOP := 1.01
## Animations, in frames at 30 per second (docs/art/Readme_Settings.txt).
const FPS := 30.0
const DOOR_OPEN := Vector2(1, 10)
const DOOR_CLOSE := Vector2(11, 24)
const BASKET_EJECT := Vector2(1, 30)


## Builds the models for a station of this kind over cells cells (1 or more), centred on the
## root, drawn unlit. fryer_end: a CUISSON 2 whose cell the fryer of the CUISSON 1 next to it
## already covers. Returns the root node, or null when there is nothing to draw.
static func build(kind: StringName, cells: int, fryer_end := false) -> Node3D:
    var root := Node3D.new()
    root.name = "Models"
    match kind:
        &"frigo":
            _add(root, "Fridge")
        &"cuisson_1":
            # 3 m: squeezed if it only has two cells.
            _add(root, "DeepFryer").scale.z = minf(cells / 3.0, 1.0)
        &"cuisson_2":
            if fryer_end:
                # The fryer drawn by the CUISSON 1 next door already covers this cell.
                root.free()
                return null
            _add(root, "Furniture")
            var fryer: Node3D = load(MODELS % "DeepFryer").instantiate()
            var basket := fryer.find_child("DoubleCooked_DeepFryer_Basket01", true, false) as MeshInstance3D
            var copy := MeshInstance3D.new()
            copy.mesh = basket.mesh
            copy.transform = Transform3D(Basis(Vector3.RIGHT, -PI / 2), Vector3.ZERO) \
                    * Transform3D(Basis.IDENTITY, Vector3(basket.position.x, 0, COUNTER_TOP))
            copy.position = Vector3(basket.position.x, COUNTER_TOP + 0.05, 0)
            root.add_child(copy)
            fryer.free()
        &"pain":
            _add(root, "Furniture")
            _on_top(root, "BreadBag")
        &"extincteur":
            _add(root, "Furniture")
            _on_top(root, "FireCase")
        &"sauces":
            _add(root, "Furniture")
            _on_top(root, "SauceMayo", Vector3(0, 0, 0.25))
            _on_top(root, "SauceAndalouse", Vector3(0, 0, 0))
            _on_top(root, "SauceKetchup", Vector3(0, 0, -0.25))
        &"caisse":
            _add(root, "Furniture")
            _on_top(root, "CashRegister", Vector3(-0.1, 0, 0.15))
            _on_top(root, "PaperBag", Vector3(0.05, 0, -0.25))
        &"viandes":
            var counter := _add(root, "Counter")
            # A 3 m display counter, squeezed to the cells it covers.
            counter.scale.z = cells / 3.0
        &"poubelle":
            _add(root, "Trash")
        _:
            root.free()
            return null
    UnlitArt.apply(root)
    return root


static func _add(root: Node3D, model: String) -> Node3D:
    var node: Node3D = load(MODELS % model).instantiate()
    node.name = model
    if model == "Furniture":
        node.scale.y = COUNTER_HEIGHT
    root.add_child(node)
    return node


## A small model standing on a 1 m counter.
static func _on_top(root: Node3D, model: String, at := Vector3.ZERO) -> Node3D:
    var node := _add(root, model)
    node.position = at + Vector3(0, COUNTER_TOP, 0)
    return node


## Plays part of a model's only animation, in frames, and stays on its last frame.
static func play(models: Node, frames: Vector2) -> void:
    var player := models.find_child("AnimationPlayer", true, false) as AnimationPlayer
    if not player or player.get_animation_list().is_empty():
        return
    var animation := player.get_animation_list()[0]
    player.play_section(animation, frames.x / FPS, frames.y / FPS)
