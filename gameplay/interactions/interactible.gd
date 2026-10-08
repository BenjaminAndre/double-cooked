class_name Interactible
extends Node3D
## A station the player interacts with from an Anchor. What it does is a Simulation rule
## keyed by kind; this node only shows the station's state, such as the fryers' bubbles.

const FRYERS: Array[StringName] = [&"cuisson_1", &"cuisson_2", &"cuisson_viande"]
const LABEL_HEIGHT := 1.3
## The fire label's colour.
const TOO_LATE := Color(1.0, 0.25, 0.2)

## The artist's animated sheets.
const OIL := {"texture": "res://art/textures/FryingOilSheet.png", "columns": 5, "rows": 5}
const FIRE := {"texture": "res://art/textures/FireSheet.png", "columns": 5, "rows": 3}
## The fire: one flame at a time, the whole sheet once a second, 1 m tall (their scene).
const FIRE_FPS := 15.0
const FIRE_HEIGHT := 0.86
const FIRE_SIZE := 1.0
## The oil bubbling while something fries: their particles (lifetime, rate, speed, sizes, the
## spin and the fade in and out), over the oil.
const OIL_HEIGHT := 0.45
const OIL_LIFETIME := 3.0
const OIL_RATE := 10.0
const OIL_SPEED := 0.05
const OIL_SIZE := 0.2
const OIL_SPIN := 90.0
const OIL_AREA := Vector3(0.15, 0.0, 0.1)
## How high a basket rises when lifted.
const BASKET_LIFT := 0.3

## The artist's models on this station (StationModels), if any: the FRIGO's door, the bin's lid
## and the fryer's baskets are animated. A CUISSON 2 at the fryer's end shares the CUISSON 1's.
var models: Node3D
## Its own basket on the fryer (CUISSON 2), and the cooked fries on the fryer (CUISSON 1).
var basket_model: Node3D
var cooked_models: Array = []
## The FRIGO's beers, one shown per beer left (the artist's Beers01 to 05).
var stock_models: Array = []

## Station kind: cuisson_1, cuisson_2, sauces, poubelle, soins, caisse, extincteur, boissons,
## pain, viandes. Empty means the station does nothing yet.
@export var kind : StringName = &""

var _state_label: Label3D
var _highlight: MeshInstance3D
## A fryer's bubble (CookingBubble), on screen.
var _bubble: CookingBubble
## What the label last showed, so it is only rebuilt when it changes.
var _label_fire := false
var _was_frying := false
var _menu_open := false
## Sheet texture path -> its sprite.
var _flipbooks := {}
var _oil: CPUParticles3D
## Whether the station has something to do tonight (Menu.station_in_use); greyed out if not.
var _in_use := true
## Material -> its darkened copy, shared like UnlitArt's.
static var _greyed := {}
const GREYED := Color(0.4, 0.4, 0.42)


## A pale shell around the station, while a player at this keyboard stands at it.
func set_highlighted(on: bool) -> void:
    if on and not _highlight:
        var box := get_node_or_null("CSGBox3D") as CSGBox3D
        if not box:
            return
        _highlight = MeshInstance3D.new()
        var mesh := BoxMesh.new()
        mesh.size = box.size + Vector3.ONE * 0.08
        mesh.material = _flat_material(Color(1, 1, 1, 0.3))
        _highlight.mesh = mesh
        _highlight.transform = box.transform
        add_child(_highlight)
    if _highlight:
        _highlight.visible = on


## Shows a fire on any station, and over fryers a bubble: how far along what fries is, or the
## portions left of a batch waiting on CUISSON 1.
func show_station(station: SimStation, rules: SimRules) -> void:
    _show_in_use(Menu.station_in_use(kind, rules.menu))
    var label := ""
    var frying := kind in FRYERS and station.basket != null and station.frying and not station.burning
    if station.burning:
        label = "FEU !"
    elif kind == &"frigo" and _in_use:
        label = "bière ×%d" % station.beers
    _show_label(label, station.burning)
    if frying:
        var window := Fryer.window(station)
        _cooking_bubble().show_cooking(station.basket.kind, station.cook, window, window.y + rules.fire_margin)
    elif kind in FRYERS and station.basket and not station.burning:
        _cooking_bubble().show_waiting(station.basket.kind, station.basket.portions)
    elif _bubble:
        _bubble.hide_bubble()
    if _bubble:
        _bubble.place_over(centre(), get_viewport().get_camera_3d())
    # This station's basket comes up when what fries in it is lifted out.
    if _was_frying and not frying and not station.burning and basket_model:
        _lift_basket()
    _was_frying = frying
    # CUISSON 1: as many cooked fries as portions left in a batch waiting to be taken.
    var batch_waiting := station.basket != null and not station.frying and not station.burning
    var left := station.basket.portions if batch_waiting else 0
    for index in cooked_models.size():
        cooked_models[index].visible = index < left
    for index in stock_models.size():
        stock_models[index].visible = index < station.beers
    _show_oil(frying)
    _show_flipbook(FIRE, station.burning, FIRE_HEIGHT, FIRE_SIZE)


## This fryer's bubble, null until it first shows.
func bubble() -> CookingBubble:
    return _bubble


## Whether this fryer shows its bubble, where a player standing at it reads their key hint.
func has_bubble() -> bool:
    return _bubble != null and _bubble.visible


## The key hint of the player standing at this fryer, in its bubble; [] for none.
func show_bubble_hints(rows: Array) -> void:
    if _bubble:
        _bubble.show_hints(rows)


func _cooking_bubble() -> CookingBubble:
    if not _bubble:
        var layer := CanvasLayer.new()
        layer.layer = CookingBubble.CANVAS_LAYER
        add_child(layer)
        _bubble = CookingBubble.new()
        layer.add_child(_bubble)
    return _bubble


## A station with nothing to do tonight is greyed out, its name too (GDD §4.2).
func _show_in_use(on: bool) -> void:
    if on == _in_use:
        return
    _in_use = on
    if models:
        for mesh: MeshInstance3D in models.find_children("*", "MeshInstance3D", true, false):
            if not mesh.mesh:
                continue
            for surface in mesh.mesh.get_surface_count():
                _grey_surface(mesh, surface, not on)
    var name_label := get_node_or_null("Label") as Label3D
    if name_label:
        name_label.modulate = Color.WHITE if on else Color(0.5, 0.5, 0.5)


## Swaps a surface to a darkened copy of its material, or back. Opaque, so it sorts like the
## rest of the kitchen.
static func _grey_surface(mesh: MeshInstance3D, surface: int, grey: bool) -> void:
    var key := "normal_%d" % surface
    if not grey:
        if mesh.has_meta(key):
            # Kept in an array: a null meta would erase itself.
            mesh.set_surface_override_material(surface, mesh.get_meta(key)[0])
            mesh.remove_meta(key)
        return
    var material := mesh.get_active_material(surface) as BaseMaterial3D
    if not material or mesh.has_meta(key):
        return
    mesh.set_meta(key, [mesh.get_surface_override_material(surface)])
    if not _greyed.has(material):
        var copy := material.duplicate() as BaseMaterial3D
        copy.albedo_color = material.albedo_color * GREYED
        _greyed[material] = copy
    mesh.set_surface_override_material(surface, _greyed[material])


## The FRIGO's door stays open while a player has its menu open.
func set_menu_open(open: bool) -> void:
    if open == _menu_open or not models:
        return
    _menu_open = open
    StationModels.play(models, StationModels.DOOR_OPEN if open else StationModels.DOOR_CLOSE)


## Something thrown in the POUBELLE: its lid opens and closes.
func pulse() -> void:
    if models:
        StationModels.play(models, Vector2(StationModels.DOOR_OPEN.x, StationModels.DOOR_CLOSE.y))


## An animated sheet over the station (docs/art/Readme_SettingsV3.txt): the fire. Built on
## first use.
func _show_flipbook(sheet: Dictionary, on: bool, height: float, size: float) -> void:
    var sprite: Sprite3D = _flipbooks.get(sheet.texture)
    if not on:
        if sprite:
            sprite.visible = false
        return
    if not sprite:
        sprite = Sprite3D.new()
        sprite.texture = load(sheet.texture)
        sprite.hframes = sheet.columns
        sprite.vframes = sheet.rows
        sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
        sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
        # Fire over everything, the glass included (Readme_SettingsV2).
        sprite.render_priority = UnlitArt.GLASS_PRIORITY + 1
        sprite.pixel_size = size / (sprite.texture.get_width() / sheet.columns)
        sprite.position = Vector3(_flipbook_x(), height, 0)
        add_child(sprite)
        _flipbooks[sheet.texture] = sprite
    sprite.visible = true
    sprite.frame = int(Time.get_ticks_msec() / 1000.0 * FIRE_FPS) % (sheet.columns * sheet.rows)


## The oil's bubbles (the artist's FryingOil particles), built on first use.
func _show_oil(on: bool) -> void:
    if not _oil:
        if not on:
            return
        _oil = CPUParticles3D.new()
        var quad := QuadMesh.new()
        quad.size = Vector2.ONE * OIL_SIZE
        var material := StandardMaterial3D.new()
        material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
        material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
        material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
        material.vertex_color_use_as_albedo = true
        material.albedo_texture = load(OIL.texture)
        material.particles_anim_h_frames = OIL.columns
        material.particles_anim_v_frames = OIL.rows
        material.particles_anim_loop = false
        quad.material = material
        _oil.mesh = quad
        _oil.amount = int(OIL_RATE * OIL_LIFETIME)
        _oil.lifetime = OIL_LIFETIME
        _oil.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
        _oil.emission_box_extents = OIL_AREA
        _oil.direction = Vector3.UP
        _oil.spread = 0.0
        _oil.gravity = Vector3.ZERO
        _oil.initial_velocity_min = OIL_SPEED
        _oil.initial_velocity_max = OIL_SPEED
        _oil.angular_velocity_min = OIL_SPIN
        _oil.angular_velocity_max = OIL_SPIN
        _oil.scale_amount_min = 0.5
        _oil.scale_amount_max = 1.0
        # The whole sheet once over a bubble's life.
        _oil.anim_speed_min = 1.0
        _oil.anim_speed_max = 1.0
        var fade := Gradient.new()
        fade.offsets = PackedFloat32Array([0.0, 0.18, 0.82, 1.0])
        fade.colors = PackedColorArray([Color(1, 1, 1, 0), Color.WHITE, Color.WHITE, Color(1, 1, 1, 0)])
        _oil.color_ramp = fade
        _oil.position = Vector3(_flipbook_x(), OIL_HEIGHT, 0)
        add_child(_oil)
    _oil.emitting = on


## Over the middle of the station's cells, as its box is.
func _flipbook_x() -> float:
    var box := get_node_or_null("CSGBox3D") as CSGBox3D
    return box.position.x if box else 0.0


## Only what changed is written: rebuilding a Label3D or a mesh every frame is what made fires
## slow on the Web build.
func _show_label(text: String, fire: bool) -> void:
    if text == "" and not _state_label:
        return
    if not _state_label:
        _state_label = Label3D.new()
        _state_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
        # Just above the station's box, however tall it is.
        var box := get_node_or_null("CSGBox3D") as CSGBox3D
        var top := box.position.y + box.size.y / 2 + 0.3 if box else LABEL_HEIGHT
        # Above the station's name, when it shows one.
        var name_label := get_node_or_null("Label") as Label3D
        if name_label and name_label.visible:
            top = name_label.position.y + 0.35
        _state_label.position = Vector3(0, maxf(top, LABEL_HEIGHT), 0)
        _state_label.outline_size = 10
        _state_label.font_size = 40
        add_child(_state_label)
    _state_label.visible = text != ""
    if _state_label.text != text:
        _state_label.text = text
    if fire != _label_fire:
        _label_fire = fire
        _state_label.font_size = 64 if fire else 40
        _state_label.modulate = TOO_LATE if fire else Color.WHITE
        _state_label.scale = Vector3.ONE
    if fire:
        # A fire throbs. Scaling only moves the label, where recolouring rebuilt it.
        _state_label.scale = Vector3.ONE * (1.0 + 0.12 * sin(Time.get_ticks_msec() * 0.02))


func _flat_material(color: Color) -> StandardMaterial3D:
    var material := StandardMaterial3D.new()
    material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    if color.a < 1.0:
        material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    material.albedo_color = color
    return material


## The basket rises out of the oil and drops back.
func _lift_basket() -> void:
    if not basket_model:
        return
    var eject: Array = basket_model.get_meta(StationModels.EJECT, [])
    if eject.size() > 1:
        # The artist's move: the basket tips its food out and comes back.
        var rest_pose: Transform3D = basket_model.get_meta(&"rest", basket_model.transform)
        basket_model.set_meta(&"rest", rest_pose)
        var pose := func(frame: float) -> void:
            var index := mini(int(frame), eject.size() - 2)
            var weight := frame - index
            var offset: Vector3 = eject[index][0].lerp(eject[index + 1][0], weight)
            var turn: Quaternion = eject[index][1].slerp(eject[index + 1][1], weight)
            basket_model.transform = Transform3D(rest_pose.basis * Basis(turn),
                    rest_pose.origin + rest_pose.basis * offset)
        basket_model.create_tween().tween_method(pose, 0.0, eject.size() - 1.0,
                (eject.size() - 1) / StationModels.FPS)
        return
    var rest: float = basket_model.get_meta(&"rest_y", basket_model.position.y)
    basket_model.set_meta(&"rest_y", rest)
    var tween := basket_model.create_tween()
    tween.tween_property(basket_model, "position:y", rest + BASKET_LIFT, 0.15)
    tween.tween_interval(0.25)
    tween.tween_property(basket_model, "position:y", rest, 0.2)


## The middle of the station, where a menu bubble goes over it.
func centre() -> Vector3:
    var box := get_node_or_null("CSGBox3D") as CSGBox3D
    return global_transform * (box.position if box else Vector3.ZERO)
