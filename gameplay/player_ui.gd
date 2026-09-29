extends Node3D
## The hearts and the name over a player.

## The artist's hearts, full and empty (65 px), all three shown.
const HEART := preload("res://art/textures/UX_Life.png")
const HEART_EMPTY := preload("res://art/textures/UX_LifeEmpty.png")
const HEART_SIZE := 0.0026
const HEART_GAP := 0.19

@export var player : Player

@onready var _hearts: Node3D = $Hearts
@onready var _pseudo: Label3D = $Pseudo


func _ready() -> void:
    for index in SimPlayer.MAX_HEALTH:
        var heart := Sprite3D.new()
        heart.texture = HEART
        heart.pixel_size = HEART_SIZE
        heart.alpha_cut = SpriteBase3D.ALPHA_CUT_OPAQUE_PREPASS
        heart.position.x = (index - (SimPlayer.MAX_HEALTH - 1) / 2.0) * HEART_GAP
        heart.billboard = BaseMaterial3D.BILLBOARD_ENABLED
        _hearts.add_child(heart)


func _process(_delta: float) -> void:
    # Full hearts first, then the lost ones.
    for index in _hearts.get_child_count():
        var heart: Sprite3D = _hearts.get_child(index)
        var picture := HEART if index < player.health else HEART_EMPTY
        if heart.texture != picture:
            heart.texture = picture
    var state := " (K.O.)" if player.health <= 0 else " (affamé)" if player.hungry else ""
    var text := player.pseudo + state
    # Only when it changes: rewriting a Label3D rebuilds it.
    if _pseudo.text != text:
        _pseudo.text = text
        _pseudo.modulate = Color(1.0, 0.6, 0.2) if player.hungry else Color.WHITE
