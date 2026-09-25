class_name Player
extends Node3D
## Display of one player. The state and the rules live in the Simulation; Night calls
## show_state() every frame.

const BUMP_HOP := 0.15
## How much wider a player gets per thing eaten or drunk.
const FAT_WIDTH := 0.12

# Identification (may be outside of player scope later)
var health : int = SimPlayer.MAX_HEALTH
var pseudo : String = "Player"
var is_local_player : bool = true

var _bump_tween: Tween
var _hands_label: Label3D
var _hint_label: Label3D
var _menu_label: Label3D
var _stun_label: Label3D


func _ready() -> void:
    _hands_label = _label(1.3, 28)
    _hint_label = _label(1.55, 26)
    _hint_label.modulate = Color(1.0, 0.9, 0.3)
    _menu_label = _label(1.8, 30)
    _menu_label.modulate = Color(0.6, 0.9, 1.0)
    _stun_label = _label(0.95, 48)
    _stun_label.text = "✶ ✶ ✶"
    _stun_label.modulate = Color(1.0, 0.85, 0.2)
    _stun_label.visible = false


## What this player's interact key would do here, "" for nothing (only for local players).
func show_hint(text: String) -> void:
    _hint_label.text = text


## An open station menu: its options side by side, the selected one in brackets.
## An empty list hides it.
func show_menu(options: Array, choice: int) -> void:
    var shown := []
    for index in options.size():
        shown.append("[%s]" % options[index] if index == choice else options[index])
    _menu_label.text = "  ".join(shown)


## alpha: how far we are towards the next tick, so walking stays smooth between ticks.
func show_state(state: SimPlayer, level: SimLevel, alpha: float) -> void:
    health = state.health
    _hands_label.text = ItemNames.of(state.item) if state.item else ""
    # Stunned after a bump: stars and a shake, for as long as it lasts.
    _stun_label.visible = state.stun > 0
    $PlayerModel.rotation.y = sin(Time.get_ticks_msec() * 0.06) * 0.5 if state.stun > 0 else 0.0
    var shown := level.positions[state.node]
    if state.is_moving():
        var t := minf((state.progress + alpha) / state.edge_ticks, 1.0)
        shown = shown.lerp(level.positions[state.path[0]], t)
    global_position = shown
    # Wider with every bite of the night (GDD §5.1).
    var girth := 1.0 + FAT_WIDTH * state.fat
    $PlayerModel.scale = Vector3(girth, 1.0, girth)
    # Knocked out: lying on the floor.
    $PlayerModel.rotation.z = PI / 2 if state.down else 0.0
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


## A small hop when someone runs into this player.
func show_bump() -> void:
    if _bump_tween:
        _bump_tween.kill()
    var model: Node3D = $PlayerModel
    model.position.y = 0.0
    _bump_tween = create_tween()
    _bump_tween.tween_property(model, "position:y", BUMP_HOP, 0.06)
    _bump_tween.tween_property(model, "position:y", 0.0, 0.09)


## A discreet "+Gras" rising and fading over the player's head.
func show_fat_gain() -> void:
    var label := _label(1.1, 30)
    # To the side, clear of the hint and hand above the head.
    label.position.x = 0.45
    label.text = "+Gras"
    label.modulate = Color(1.0, 0.8, 0.45)
    var tween := create_tween().set_parallel()
    tween.tween_property(label, "position:y", 2.0, 1.2)
    tween.tween_property(label, "modulate:a", 0.0, 1.2)
    tween.chain().tween_callback(label.queue_free)
