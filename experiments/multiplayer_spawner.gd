extends MultiplayerSpawner

@export var player_scene: PackedScene

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
    Signals.server_created.connect(_on_server_created)
    multiplayer.peer_connected.connect(_on_peer_connected)
    multiplayer.peer_disconnected.connect(_on_peer_disconnected)
    multiplayer.server_disconnected.connect(_on_server_disconnected)

func _on_peer_connected(id: int) -> void:
    if !is_multiplayer_authority() : return
    _add_player(str(id))
    
func _on_server_created(id: String) -> void:
    _add_player(id)

func _on_peer_disconnected(id: int) -> void:    
    if !is_multiplayer_authority() : return
    var player_node = get_node_or_null("/root/World/Players/%s" % str(id))
    if player_node:
        player_node.queue_free()
        
func _on_server_disconnected() -> void:
    for child in get_node("/root/World/Players").get_children():
        child.queue_free()


func _add_player(id: String) -> void:
    var player_instance = player_scene.instantiate()
    player_instance.name = id
    player_instance.set_multiplayer_authority(int(id))
    print("Spawning player with id: %s" % id)
    get_node("/root/World/Players").add_child(player_instance)
