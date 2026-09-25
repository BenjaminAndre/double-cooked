class_name Player
extends Node3D
## Display of one player. The state and the rules live in the Simulation; Night calls
## show_state() every frame.

const BUMP_HOP := 0.15

# Identification (may be outside of player scope later)
var health : int = SimPlayer.MAX_HEALTH
var pseudo : String = "Player"
var is_local_player : bool = true

var _bump_tween: Tween
var _hands_label: Label3D
var _hint_label: Label3D
var _menu_label: Label3D


func _ready() -> void:
    _hands_label = _label(1.3, 28)
    _hint_label = _label(1.55, 26)
    _hint_label.modulate = Color(1.0, 0.9, 0.3)
    _menu_label = _label(1.8, 30)
    _menu_label.modulate = Color(0.6, 0.9, 1.0)


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
    # Left hand on the left, the focused one in brackets.
    var hands := []
    for hand in state.hands.size():
        var text := ItemNames.of(state.hands[hand])
        hands.append("[%s]" % text if hand == state.focus else text)
    _hands_label.text = "%s   %s" % hands
    var shown := level.positions[state.node]
    if state.is_moving():
        var t := minf((state.progress + alpha) / state.edge_ticks, 1.0)
        shown = shown.lerp(level.positions[state.path[0]], t)
    global_position = shown
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
