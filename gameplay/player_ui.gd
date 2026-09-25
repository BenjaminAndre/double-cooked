extends Node3D

@export var player : Player

var _heart1: Sprite3D
var _heart2: Sprite3D
var _heart3: Sprite3D
var _pseudo: Label3D

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
    _heart1 = $Heart1
    _heart2 = $Heart2
    _heart3 = $Heart3
    _pseudo = $Pseudo   


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
    _pseudo.text = player.pseudo
    _heart1.visible = player.health >= 1
    _heart2.visible = player.health >= 2
    _heart3.visible = player.health >= 3

    if _heart3.visible :
        _heart1.global_position.x = player.global_position.x
        _heart2.global_position.x = player.global_position.x - 0.2
        _heart3.global_position.x = player.global_position.x + 0.2
    elif _heart2.visible :
        _heart1.global_position.x = player.global_position.x - 0.1
        _heart2.global_position.x = player.global_position.x + 0.1
    elif _heart1.visible :
        _heart1.global_position.x = player.global_position.x

    if player.health <= 0:
        _pseudo.text += " (K.O.)"
