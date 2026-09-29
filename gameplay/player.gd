class_name Player
extends Node3D
## Display of one player. The state and the rules live in the Simulation; Night calls
## show_state() every frame.

const BUMP_HOP := 0.15
## How much wider a player gets per BMI point over a healthy start, and thinner per point under.
const FAT_WIDTH := 0.12
const THIN_WIDTH := 0.07
## The menu and hint panel sits on screen above this point, clear of the hand, hearts and name.
const PANEL_HEIGHT := 2.15
## Where a hat sits: the top of the drawn head.
const HEAD_TOP := PaperFigure.HEIGHT - 0.12

# Identification (may be outside of player scope later)
var health : int = SimPlayer.MAX_HEALTH
var pseudo : String = "Player"
var is_local_player : bool = true
## Close to collapsing from hunger (GDD §5.1): the name says so.
var hungry := false
## Set by Night from SimRules.
var level_start_bmi := 21
var hungry_below := 18

var _bump_tween: Tween
var _hands_label: Label3D
## Menu and key hints on screen, for local players only.
var _panel: PlayerPanel
## Three stars circling the head while stunned.
var _stars: Node3D
## What the body and hat last showed (SimPlayer.color, hat), to change them only when needed.
var _color := -1
var _hat := -1
var _helmet: Node3D
## The paper cut-out (docs/ART_PLAN.md).
var _figure: PaperFigure


func _ready() -> void:
    _figure = PaperFigure.new()
    $PlayerModel.add_child(_figure)
    _hands_label = _label(1.98, 28)
    if is_local_player:
        var layer := CanvasLayer.new()
        add_child(layer)
        _panel = PlayerPanel.new()
        layer.add_child(_panel)
    _stars = Node3D.new()
    _stars.position.y = PaperFigure.HEIGHT - 0.1
    add_child(_stars)
    for index in 3:
        var star := Sprite3D.new()
        star.texture = Icons.star()
        star.modulate = Color(1.0, 0.85, 0.2)
        star.pixel_size = 0.0025
        star.billboard = BaseMaterial3D.BILLBOARD_ENABLED
        star.position = Vector3.RIGHT.rotated(Vector3.UP, index * TAU / 3) * 0.25
        _stars.add_child(star)
    _stars.visible = false


## What this player's keys would do here, as [key name, verb] rows (only for local players).
func show_hint(rows: Array) -> void:
    if _panel:
        _panel.show_hints(rows)


func hint_rows() -> Array:
    return _panel.hint_rows() if _panel else []


## An open station menu: its options side by side, the selected one highlighted.
## An empty list hides it.
func show_menu(options: Array, choice: int, disabled: Array = []) -> void:
    if _panel:
        _panel.show_menu(options, choice, disabled)


## alpha: how far we are towards the next tick, so walking stays smooth between ticks.
func show_state(state: SimPlayer, level: SimLevel, alpha: float) -> void:
    health = state.health
    var held := ItemNames.of(state.item) if state.item else ""
    if _hands_label.text != held:
        _hands_label.text = held
    # Stunned after a bump: stars and a shake, for as long as it lasts.
    _stars.visible = state.stun > 0
    _stars.rotation.y = Time.get_ticks_msec() * 0.008
    # A paper figure can't turn: it shakes sideways instead.
    $PlayerModel.position.x = sin(Time.get_ticks_msec() * 0.06) * 0.06 if state.stun > 0 else 0.0
    var shown := level.positions[state.node]
    if state.is_moving():
        var t := minf((state.progress + alpha) / state.edge_ticks, 1.0)
        shown = shown.lerp(level.positions[state.path[0]], t)
    global_position = shown
    # Wider with every BMI point, thinner as they waste away (GDD §5.1).
    var over := state.bmi - level_start_bmi
    var girth := 1.0 + (FAT_WIDTH if over > 0 else THIN_WIDTH) * over
    hungry = state.bmi <= hungry_below
    _figure.set_girth(girth)
    if state.color != _color:
        _color = state.color
        _figure.set_picture(Looks.character(_color))
    if state.hat != _hat:
        _hat = state.hat
        _wear(Looks.HATS[_hat])
    # Knocked out: lying on the floor.
    _figure.set_lying(state.down)
    if _helmet:
        _helmet.visible = _hat == Looks.HATS.find(Looks.BEER_HELMET) and not state.down
    var camera := get_viewport().get_camera_3d()
    if _panel and camera:
        _panel.place(camera.unproject_position(global_position + Vector3.UP * PANEL_HEIGHT))
    for node in state.path:
        DebugDraw3D.draw_sphere(level.positions[node], 0.12, Color.GREEN)


func _label(height: float, size: int) -> Label3D:
    var label := Label3D.new()
    label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    label.position = Vector3(0, height, 0)
    label.font_size = size
    label.outline_size = 8
    add_child(label)
    return label


## The cap is drawn on the characters, so "rien" still shows it until the artist draws them
## without (docs/ART_PLAN.md); the beer helmet goes on top.
func _wear(hat: StringName) -> void:
    if hat == Looks.BEER_HELMET and not _helmet:
        _helmet = _beer_helmet()
        $PlayerModel.add_child(_helmet)
    if _helmet:
        _helmet.visible = hat == Looks.BEER_HELMET


## A helmet with a can on each side and straws down to the mouth, built in code for now.
func _beer_helmet() -> Node3D:
    var helmet := Node3D.new()
    helmet.position.y = HEAD_TOP
    var dome := MeshInstance3D.new()
    var sphere := SphereMesh.new()
    sphere.radius = 0.2
    sphere.height = 0.2
    sphere.is_hemisphere = true
    var shell := StandardMaterial3D.new()
    shell.albedo_color = Color(0.95, 0.8, 0.15)
    sphere.material = shell
    dome.mesh = sphere
    helmet.add_child(dome)
    var straw_material := StandardMaterial3D.new()
    straw_material.albedo_color = Color(0.95, 0.95, 0.95)
    for side in [-1.0, 1.0]:
        var can := BeerCan.new()
        can.scale = Vector3.ONE * 0.55
        can.position = Vector3(side * 0.24, 0.05, 0)
        helmet.add_child(can)
        # From the top of the can, down in front of the face.
        var straw := MeshInstance3D.new()
        var tube := CylinderMesh.new()
        tube.top_radius = 0.012
        tube.bottom_radius = 0.012
        tube.height = 0.34
        tube.material = straw_material
        straw.mesh = tube
        straw.position = Vector3(side * 0.13, -0.02, -0.12)
        straw.rotation = Vector3(-0.5, 0, side * 0.9)
        helmet.add_child(straw)
    return helmet


## A small hop when someone runs into this player.
func show_bump() -> void:
    if _bump_tween:
        _bump_tween.kill()
    var model: Node3D = $PlayerModel
    model.position.y = 0.0
    _bump_tween = create_tween()
    _bump_tween.tween_property(model, "position:y", BUMP_HOP, 0.06)
    _bump_tween.tween_property(model, "position:y", 0.0, 0.09)


## A discreet "+Gras" (or "-Gras" as walking burns it off) rising and fading by the head.
func show_fat_change(gained: bool) -> void:
    var label := _label(1.3, 30)
    # To the side, clear of the hint and hand above the head.
    label.position.x = 0.45
    label.text = "+Gras" if gained else "-Gras"
    label.modulate = Color(1.0, 0.8, 0.45) if gained else Color(0.6, 0.85, 1.0)
    var tween := create_tween().set_parallel()
    tween.tween_property(label, "position:y", 2.0, 1.2)
    tween.tween_property(label, "modulate:a", 0.0, 1.2)
    tween.chain().tween_callback(label.queue_free)
