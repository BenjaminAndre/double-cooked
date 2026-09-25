class_name NightLink
extends Node
## The network messages of an online night (GDD §9.1). Night sits at the same path on
## every peer, so these RPCs reach the matching Night. Peer 1 is the host.

signal command_received(peer_id: int, command: int)
signal night_began(player_count: int, slot: int, seed_value: int)
signal tick_received(tick: int, check: int, commands: PackedInt32Array)


## Client to host: one key press.
@rpc("any_peer", "call_remote", "reliable")
func send_command(command: int) -> void:
    command_received.emit(multiplayer.get_remote_sender_id(), command)


## Host to one client: a night starts, and this is the client's slot.
@rpc("authority", "call_remote", "reliable")
func begin_night(player_count: int, slot: int, seed_value: int) -> void:
    night_began.emit(player_count, slot, seed_value)


## Host to clients: the commands applied on a tick, flattened as slot, command, slot, command...
## check is the state fingerprint after that tick, sent every Night.CHECK_EVERY ticks (0 otherwise).
@rpc("authority", "call_remote", "reliable")
func receive_tick(tick: int, check: int, commands: PackedInt32Array) -> void:
    tick_received.emit(tick, check, commands)
