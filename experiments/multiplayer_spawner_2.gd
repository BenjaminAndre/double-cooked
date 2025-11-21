extends MultiplayerSpawner

@export var the_ball : PackedScene


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
    Signals.server_created.connect(_on_server_created)
    multiplayer.server_disconnected.connect(_on_server_disconnected)
    
func _on_server_created(_id: String) -> void:
    if !is_multiplayer_authority() : return
    _add_the_ball()

func _on_server_disconnected() -> void:
    get_node("/root/World/Ball").queue_free()


func _add_the_ball() -> void:
    var ball = the_ball.instantiate()
    ball.name = "Ball"
    get_node("/root/World/").add_child(ball)
