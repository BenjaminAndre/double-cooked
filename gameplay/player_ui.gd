extends Node3D
## The hearts and the name over a player.

@export var player : Player

@onready var _hearts: Label3D = $Hearts
@onready var _pseudo: Label3D = $Pseudo


func _process(_delta: float) -> void:
    _hearts.text = "♥".repeat(player.health)
    _pseudo.text = player.pseudo + (" (K.O.)" if player.health <= 0 else "")
