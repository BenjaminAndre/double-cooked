extends MultiplayerSpawner

@export var player_scene: PackedScene

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
    Signals.server_created.connect(_on_server_created)
    multiplayer.peer_connected.connect(_on_peer_connected)

func _on_peer_connected(id: int) -> void:
    _add_player(str(id))
    
func _on_server_created(id: String) -> void:
    _add_player(id)

func _add_player(id: String) -> void:
    DisplayServer.window_set_title(id)
    var player_instance = player_scene.instantiate()
    player_instance.name = id
    add_child(player_instance)