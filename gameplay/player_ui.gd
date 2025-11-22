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
    if not player.is_local_player:
        _pseudo.text = player.pseudo
        if player.health > 1:
            _heart1.visible = false
            _heart2.visible = false
            _heart3.visible = false
    else:
        _pseudo.text = "You"
        if player.health >= 3:
            _heart1.visible = true
            _heart2.visible = true
            _heart3.visible = true
        elif player.health == 2:
            _heart1.visible = true
            _heart2.visible = true
            _heart3.visible = false
        elif player.health == 1:
            _heart1.visible = true
            _heart2.visible = false
            _heart3.visible = false
        else:
            _heart1.visible = false
            _heart2.visible = false
            _heart3.visible = false
            
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
        _pseudo.text += " (Dead)"
