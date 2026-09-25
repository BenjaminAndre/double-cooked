extends Node3D
## The hearts and the name over a player.

@export var player : Player

@onready var _hearts: Label3D = $Hearts
@onready var _pseudo: Label3D = $Pseudo


func _process(_delta: float) -> void:
    _hearts.text = "♥".repeat(player.health)
    var state := " (K.O.)" if player.health <= 0 else " (affamé)" if player.hungry else ""
    _pseudo.text = player.pseudo + state
    _pseudo.modulate = Color(1.0, 0.6, 0.2) if player.hungry else Color.WHITE
