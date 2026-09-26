class_name Interactible
extends Node3D
## A station the player interacts with from an Anchor. What it does is a Simulation rule
## keyed by kind; this node only shows the station's state, such as the fryer gauges.

const FRYERS: Array[StringName] = [&"cuisson_1", &"cuisson_2"]
const LABEL_HEIGHT := 1.3
## The fryer gauge: a horizontal bar facing the camera, yellow while undercooked, blue when
## ready, red from too late up to the fire at its end; a white line shows the progress.
const GAUGE_HEIGHT := 1.1
const GAUGE_SIZE := Vector2(1.0, 0.12)
const GAUGE_ALPHA := 0.75
const UNDERCOOKED := Color(1.0, 0.85, 0.2)
const READY := Color(0.25, 0.55, 1.0)
const TOO_LATE := Color(1.0, 0.25, 0.2)

## Station kind: cuisson_1, cuisson_2, sauces, poubelle, soins, caisse, extincteur, boissons,
## pain, viandes. Empty means the station does nothing yet.
@export var kind : StringName = &""

var _state_label: Label3D
var _highlight: MeshInstance3D
var _gauge: Node3D
## Undercooked, ready and too-late bands, then the progress line.
var _gauge_parts: Array[MeshInstance3D] = []
## What the label and the gauge last showed, so they are only rebuilt when it changes.
var _label_fire := false
var _gauge_zones := Vector3i.ZERO


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


## Shows a fire on any station, and on fryers the gauge while something fries, or the
## portions left of a batch waiting on CUISSON 1.
func show_station(station: SimStation, rules: SimRules) -> void:
    var label := ""
    var frying := kind in FRYERS and station.basket != null and station.frying and not station.burning
    if station.burning:
        label = "FEU !"
    elif kind == &"frigo":
        label = "bière ×%d" % station.beers
    elif kind in FRYERS and station.basket and not station.frying:
        label = "×%d" % station.basket.portions
    _show_label(label, station.burning)
    if frying:
        var window := Fryer.window(station)
        _show_gauge(window, window.y + rules.fire_margin, station.cook)
    elif _gauge:
        _gauge.visible = false


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


## window: the ready zone in ticks; fire: the tick the gauge ends at; cook: ticks so far.
## The zones only move when the window changes; the line slides along the quads, which are
## unit squares scaled into place rather than resized meshes.
func _show_gauge(window: Vector2i, fire: int, cook: int) -> void:
    if not _gauge:
        _gauge = Node3D.new()
        _gauge.position = Vector3(0, GAUGE_HEIGHT, 0)
        add_child(_gauge)
        for color in [UNDERCOOKED, READY, TOO_LATE]:
            _gauge_parts.append(_quad(Color(color, GAUGE_ALPHA)))
        _gauge_parts.append(_quad(Color.WHITE))
        var camera := get_viewport().get_camera_3d()
        if camera:
            _gauge.global_basis = camera.global_basis
    _gauge.visible = true
    var zones := Vector3i(window.x, window.y, fire)
    if zones != _gauge_zones:
        _gauge_zones = zones
        var bounds := [0, window.x, window.y, fire]
        for zone in 3:
            _place(_gauge_parts[zone], float(bounds[zone]) / fire, float(bounds[zone + 1]) / fire, 1.0)
    var at := clampf(float(cook) / fire, 0.0, 1.0)
    _place(_gauge_parts[3], at - 0.012, at + 0.012, 1.8)
    _gauge_parts[3].position.z = 0.002


## Stretches a unit quad over [from, to] of the gauge's width, height scaled by tall.
func _place(part: MeshInstance3D, from: float, to: float, tall: float) -> void:
    part.scale = Vector3(maxf(to - from, 0.001) * GAUGE_SIZE.x, GAUGE_SIZE.y * tall, 1.0)
    part.position.x = ((from + to) / 2 - 0.5) * GAUGE_SIZE.x


func _quad(color: Color) -> MeshInstance3D:
    var part := MeshInstance3D.new()
    var mesh := QuadMesh.new()
    mesh.size = Vector2.ONE
    mesh.material = _flat_material(color)
    part.mesh = mesh
    _gauge.add_child(part)
    return part


func _flat_material(color: Color) -> StandardMaterial3D:
    var material := StandardMaterial3D.new()
    material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    if color.a < 1.0:
        material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    material.albedo_color = color
    return material
