class_name NightLink
extends Node
## The network messages of an online night (GDD §9.1). Night sits at the same path on
## every peer, so these RPCs reach the matching Night. Peer 1 is the host.

signal command_received(peer_id: int, command: int)
signal night_began(player_count: int, slot: int, seed_value: int, lobby: bool, campaign_night: int,
        looks: PackedInt32Array, ids: PackedStringArray, debug: bool)
signal tick_received(tick: int, check: int, commands: PackedInt32Array)
signal player_left(slot: int)
signal player_back(slot: int)
signal hello_received(peer_id: int, player_id: String, look: PackedInt32Array)
signal caught_up(start: Dictionary, slot: int, ids: PackedStringArray, left: PackedInt32Array)
signal player_joined(tick: int, node: int, color: int, hat: int, player_id: String)
signal night_full


## Client to host: one key press.
@rpc("any_peer", "call_remote", "reliable")
func send_command(command: int) -> void:
    command_received.emit(multiplayer.get_remote_sender_id(), command)


## Client to host, on connecting: who this player is (kept across connections, so a dropped
## player gets their slot back) and their looks (colour, hat).
@rpc("any_peer", "call_remote", "reliable")
func hello(player_id: String, look: PackedInt32Array) -> void:
    hello_received.emit(multiplayer.get_remote_sender_id(), player_id, look)


## Host to one client: a night (or the lobby) starts, and this is the client's slot.
## campaign_night: which night of a campaign (Campaign), 0 for a single night. looks:
## colour, hat per slot; ids: each slot's player; debug: whether a test tool was used on the
## way here (Night.debug_used).
@rpc("authority", "call_remote", "reliable")
func begin_night(player_count: int, slot: int, seed_value: int, lobby: bool, campaign_night: int,
        looks: PackedInt32Array, ids: PackedStringArray, debug: bool) -> void:
    night_began.emit(player_count, slot, seed_value, lobby, campaign_night, looks, ids, debug)


## Host to one client joining (or rejoining) a night under way: how it started and every
## command since, to replay up to now; then the client plays this slot.
@rpc("authority", "call_remote", "reliable")
func catch_up(start: Dictionary, slot: int, ids: PackedStringArray, left: PackedInt32Array) -> void:
    caught_up.emit(start, slot, ids, left)


## Host to clients: a player joins the night, added before this tick.
@rpc("authority", "call_remote", "reliable")
func join_player(tick: int, node: int, color: int, hat: int, player_id: String) -> void:
    player_joined.emit(tick, node, color, hat, player_id)


## Host to one client: the night is full, wait for the next one.
@rpc("authority", "call_remote", "reliable")
func full() -> void:
    night_full.emit()


## Host to clients: the commands applied on a tick, flattened as slot, command, slot, command...
## check is the state fingerprint after that tick, sent every Night.CHECK_EVERY ticks (0 otherwise).
@rpc("authority", "call_remote", "reliable")
func receive_tick(tick: int, check: int, commands: PackedInt32Array) -> void:
    tick_received.emit(tick, check, commands)


## Host to clients: the player in this slot left the night.
@rpc("authority", "call_remote", "reliable")
func mark_left(slot: int) -> void:
    player_left.emit(slot)


## Host to clients: the player in this slot is back.
@rpc("authority", "call_remote", "reliable")
func mark_back(slot: int) -> void:
    player_back.emit(slot)
