extends Node3D
## The hearts and the name over a player.

const HEART_COLOR := Color(0.9, 0.15, 0.2)
const HEART_SIZE := 0.0028
const HEART_GAP := 0.2

@export var player : Player

@onready var _hearts: Node3D = $Hearts
@onready var _pseudo: Label3D = $Pseudo


func _ready() -> void:
    for index in SimPlayer.MAX_HEALTH:
        var heart := Sprite3D.new()
        heart.texture = Icons.heart()
        heart.modulate = HEART_COLOR
        heart.pixel_size = HEART_SIZE
        heart.billboard = BaseMaterial3D.BILLBOARD_ENABLED
        _hearts.add_child(heart)


func _process(_delta: float) -> void:
    # The hearts left, centred over the player.
    for index in _hearts.get_child_count():
        var heart: Sprite3D = _hearts.get_child(index)
        heart.visible = index < player.health
        heart.position.x = (index - (player.health - 1) / 2.0) * HEART_GAP
    var state := " (K.O.)" if player.health <= 0 else " (affamé)" if player.hungry else ""
    _pseudo.text = player.pseudo + state
    _pseudo.modulate = Color(1.0, 0.6, 0.2) if player.hungry else Color.WHITE
