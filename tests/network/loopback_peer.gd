class_name LoopbackPeer
extends MultiplayerPeerExtension
## An in-memory MultiplayerPeer for tests: two paired peers exchange packets through queues,
## with no socket, port or network permission involved. Packets are delivered in order on
## the receiver's next poll, like a reliable ordered channel.

const HOST_ID := 1

var _id: int
var _other: LoopbackPeer
## Each packet is [from, bytes, channel, mode]. The front one is the "current" packet.
var _inbox: Array = []
var _target := 0
var _channel := 0
var _mode := TRANSFER_MODE_RELIABLE
var _status := CONNECTION_CONNECTING


## A host (id 1) and a client, already paired. They connect on their first poll.
static func pair(client_id := 2) -> Array[LoopbackPeer]:
    var host := LoopbackPeer.new()
    var client := LoopbackPeer.new()
    host._id = HOST_ID
    client._id = client_id
    host._other = client
    client._other = host
    return [host, client]


func _poll() -> void:
    if _status == CONNECTION_CONNECTING and _other:
        _status = CONNECTION_CONNECTED
        peer_connected.emit(_other._id)


func _put_packet_script(buffer: PackedByteArray) -> Error:
    if _status != CONNECTION_CONNECTED:
        return ERR_UNCONFIGURED
    if _target == 0 or _target == _other._id or (_target < 0 and -_target != _other._id):
        _other._inbox.append([_id, buffer, _channel, _mode])
    return OK


func _get_available_packet_count() -> int:
    return _inbox.size()


func _get_packet_script() -> PackedByteArray:
    return _inbox.pop_front()[1]


func _get_packet_peer() -> int:
    return _inbox[0][0]


func _get_packet_channel() -> int:
    return _inbox[0][2]


func _get_packet_mode() -> TransferMode:
    return _inbox[0][3]


func _set_target_peer(peer: int) -> void:
    _target = peer


func _set_transfer_channel(channel: int) -> void:
    _channel = channel


func _get_transfer_channel() -> int:
    return _channel


func _set_transfer_mode(mode: TransferMode) -> void:
    _mode = mode


func _get_transfer_mode() -> TransferMode:
    return _mode


func _get_max_packet_size() -> int:
    return 1 << 24


func _get_unique_id() -> int:
    return _id


func _is_server() -> bool:
    return _id == HOST_ID


func _is_server_relay_supported() -> bool:
    return false


func _get_connection_status() -> ConnectionStatus:
    return _status


func _disconnect_peer(_peer: int, _force: bool) -> void:
    _close()


func _close() -> void:
    if _status == CONNECTION_DISCONNECTED:
        return
    _status = CONNECTION_DISCONNECTED
    _inbox.clear()
    var other := _other
    _other = null
    if other:
        other._close()
