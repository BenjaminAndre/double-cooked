class_name StationModels
extends RefCounted
## Dresses a station with the artist's models (docs/ART_PLAN.md). Every model has its front
## towards +x and its length along z; GridRoom turns the station so the front faces its cells.
##
## The fryer is one unit: raw fries at one end, cooked fries in the middle, two baskets at the
## other. It is stretched over CUISSON 1 (two cells) and the CUISSON 2 right after it, and its
## baskets are taken out and set one on each CUISSON 2: raw fries and cooked ones on CUISSON 1,
## a basket per CUISSON 2. A CUISSON 2 on its own gets a 1 m counter with a basket, until the
## artist draws a module.

const MODELS := "res://art/models/DoubleCooked_%s.fbx"
## The 1 m counter is drawn 0.46 m high; it stands twice that, level with the fryer.
const COUNTER_HEIGHT := 2.0
const COUNTER_TOP := 0.46 * COUNTER_HEIGHT
const FRYER_TOP := 1.01
## The sauce bottles are drawn small.
const SAUCE_SCALE := 2.2
## The fryer as drawn is 3 m long.
const FRYER_LENGTH := 3.0
## Where the middle of its two oil wells (and baskets) is, along the drawn fryer.
const WELLS_MIDDLE := -0.9425
## Animations, in frames at 30 per second (docs/art/Readme_Settings.txt).
const FPS := 30.0
const DOOR_OPEN := Vector2(1, 10)
const DOOR_CLOSE := Vector2(11, 24)
## Meta keys on the returned root: the baskets in order, and the cooked fries on CUISSON 1.
const BASKETS := &"baskets"
const COOKED := &"cooked"
## Meta key on each basket: its "eject food" move (_eject_frames), frames 0 to 30 of the
## fryer's animation (Readme_SettingsV2).
const EJECT := &"eject"
const EJECT_FRAMES := Vector2i(0, 30)


## Builds the models for a station of this kind over cells cells (1 or more), centred on the
## root, drawn unlit. cell_z: the root's z at the middle of each cell it covers, first cell
## first; for CUISSON 1 they go on over the CUISSON 2 its fryer also covers, one basket each.
## Returns the root node, or null when this kind has no model.
static func build(kind: StringName, cells: int, cell_z: Array[float] = []) -> Node3D:
    var root := Node3D.new()
    root.name = "Models"
    match kind:
        &"frigo":
            _add(root, "Fridge")
        &"cuisson_1":
            _fryer(root, cells, cell_z)
        &"cuisson_2":
            _add(root, "Furniture")
            var fryer: Node3D = load(MODELS % "DeepFryer").instantiate()
            var basket := _take(fryer, "DoubleCooked_DeepFryer_Basket01", root)
            basket.position.y -= FRYER_TOP - COUNTER_TOP
            basket.position.z = 0
            fryer.free()
            root.set_meta(BASKETS, [basket])
        &"pain":
            _add(root, "Furniture")
            _on_top(root, "BreadBag")
        &"extincteur":
            _add(root, "Furniture")
            _on_top(root, "FireCase")
        &"sauces":
            _add(root, "Furniture")
            # Drawn small: bigger, so they read from the camera.
            for sauce: Array in [["SauceMayo", 0.28], ["SauceAndalouse", 0.0], ["SauceKetchup", -0.28]]:
                _on_top(root, sauce[0], Vector3(0, 0, sauce[1])).scale = Vector3.ONE * SAUCE_SCALE
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


## The fryer, stretched over every cell in cell_z; what stands on it is taken out first, so it
## keeps its own shape, and set on its cell.
static func _fryer(root: Node3D, cells: int, cell_z: Array[float]) -> void:
    var span := maxi(cell_z.size(), cells)
    var fryer := _add(root, "DeepFryer")
    var raw := _take(fryer, "DoubleCooked_FriesRaw", root)
    var cooked: Array[Node3D] = []
    for index in range(1, 6):
        cooked.append(_take(fryer, "DoubleCooked_FriesCooked%02d" % index, root))
    var baskets: Array[Node3D] = [_take(fryer, "DoubleCooked_DeepFryer_Basket02", root),
            _take(fryer, "DoubleCooked_DeepFryer_Basket01", root)]
    var stretch := span / FRYER_LENGTH
    fryer.scale.z = stretch
    # The model animates its baskets where they were: not any more. Each keeps the artist's
    # "eject food" move, as offsets from where it rests, to play wherever it ends up.
    var player := fryer.find_child("AnimationPlayer", true, false) as AnimationPlayer
    if player:
        if not player.get_animation_list().is_empty():
            var animation := player.get_animation(player.get_animation_list()[0])
            for basket in baskets:
                basket.set_meta(EJECT, _eject_frames(animation, basket.name))
        player.free()
    # Slid so its two oil wells fall on the CUISSON 2 it covers, one in each.
    var following := span - cells
    if following > 0:
        var target := 0.0
        for index in following:
            target += cell_z[cells + index] / following
        fryer.position.z = target - WELLS_MIDDLE * stretch
    for basket in baskets:
        basket.position.z = basket.position.z * stretch + fryer.position.z
    if cell_z.size() >= 2:
        raw.position.z = cell_z[0]
        var middle := 0.0
        for fries in cooked:
            middle += fries.position.z / cooked.size()
        for fries in cooked:
            fries.position.z += cell_z[1] - middle
    # Each CUISSON 2 gets the basket nearest to it.
    var placed: Array[Node3D] = []
    for index in following:
        var nearest: Node3D = null
        for basket in baskets:
            if basket not in placed and (not nearest or absf(basket.position.z - cell_z[cells + index])
                    < absf(nearest.position.z - cell_z[cells + index])):
                nearest = basket
        if nearest:
            placed.append(nearest)
    for basket in baskets:
        if basket not in placed:
            basket.free()
    root.set_meta(BASKETS, placed)
    root.set_meta(COOKED, cooked)


## A basket's tracks over EJECT_FRAMES, one [offset, rotation] per frame, both in the basket's
## own space and from its first frame (a basket rests unrotated).
static func _eject_frames(animation: Animation, basket: String) -> Array:
    var position_track := -1
    var rotation_track := -1
    for track in animation.get_track_count():
        if not String(animation.track_get_path(track)).ends_with(basket):
            continue
        match animation.track_get_type(track):
            Animation.TYPE_POSITION_3D:
                position_track = track
            Animation.TYPE_ROTATION_3D:
                rotation_track = track
    if position_track < 0 or rotation_track < 0:
        return []
    var start := animation.position_track_interpolate(position_track, EJECT_FRAMES.x / FPS)
    var frames := []
    for frame in range(EJECT_FRAMES.x, EJECT_FRAMES.y + 1):
        frames.append([animation.position_track_interpolate(position_track, frame / FPS) - start,
                animation.rotation_track_interpolate(rotation_track, frame / FPS)])
    return frames


## Moves one of a model's parts to root, keeping where it stands in the model.
static func _take(model: Node3D, part_name: String, root: Node3D) -> Node3D:
    var part := model.find_child(part_name, true, false) as Node3D
    var where := Transform3D.IDENTITY
    var node: Node = part
    while node and node != model:
        where = (node as Node3D).transform * where
        node = node.get_parent()
    where = model.transform * where
    part.get_parent().remove_child(part)
    part.owner = null
    root.add_child(part)
    part.transform = where
    return part


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


## Depth of the modules, front to back.
const DEPTH := 0.77


## How tall a station's model stands, for its highlight and labels.
static func height(kind: StringName) -> float:
    match kind:
        &"frigo":
            return 1.27
        &"cuisson_1", &"cuisson_2":
            return FRYER_TOP
        &"poubelle":
            return 0.46
        &"viandes":
            return 0.95
    return COUNTER_TOP
