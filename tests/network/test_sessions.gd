extends GutTest
## Online sessions (GDD §9.1): joining a night under way, getting one's slot back after a drop,
## and a new host taking over when the host leaves. Every peer is a game scene with its own
## multiplayer API, linked in memory (LoopbackPeer, no socket).

const GAME_SCENE := preload("res://game.tscn")
const C := Simulation.Command

var _roots: Array[Node] = []
var _apis: Array[SceneMultiplayer] = []


func after_each() -> void:
    for api in _apis:
        if api.multiplayer_peer:
            api.multiplayer_peer.close()
    for root in _roots:
        get_tree().set_multiplayer(null, root.get_path())
    _roots.clear()
    _apis.clear()


func test_a_player_joining_a_night_under_way_catches_up_and_plays() -> void:
    var hub := LoopbackPeer.host()
    var host := _peer("Host", "H", hub)
    var guest := _peer("Guest", "G", hub.add_client(2))
    await _gather(host, [guest])
    host.submit(0, C.MOVE_RIGHT)
    guest.submit(0, C.MOVE_DOWN)
    await wait_seconds(0.6)
    var late := _peer("Late", "L", hub.add_client(3))
    await _linked(host, late)
    late.say_hello()
    await wait_until(func() -> bool:
            return late.role == Night.Role.CLIENT and late.simulation.players.size() == 3, 5.0)
    assert_eq(host.simulation.players.size(), 3)
    assert_eq(late.local_slots(), PackedInt32Array([2]))
    # The newcomer plays at once.
    late.submit(0, C.MOVE_RIGHT)
    await wait_seconds(0.5)
    await _same_night([host, guest, late])
    var nodes := {}
    for player in host.simulation.players:
        nodes[player.node] = true
    assert_eq(nodes.size(), 3, "nobody stands on anyone")


func test_a_dropped_player_gets_their_slot_back() -> void:
    var hub := LoopbackPeer.host()
    var host := _peer("Host", "H", hub)
    var guest := _peer("Guest", "G", hub.add_client(2))
    await _gather(host, [guest])
    guest.submit(0, C.MOVE_DOWN)
    await wait_seconds(0.5)
    # The guest's connection drops (the Lobby tells Night on peer_disconnected).
    _api(guest).multiplayer_peer.close()
    host.peer_left(2)
    assert_eq(host._views[1].pseudo, Night.GONE)
    await wait_seconds(0.3)
    _api(guest).multiplayer_peer = hub.add_client(7)
    await _linked(host, guest)
    guest.say_hello()
    await wait_until(func() -> bool: return guest.simulation.tick >= host.simulation.tick - 5, 5.0)
    assert_eq(guest.local_slots(), PackedInt32Array([1]))
    assert_eq(host.simulation.players.size(), 2, "no new player")
    assert_eq(host._views[1].pseudo, "", "back")
    guest.submit(0, C.MOVE_UP)
    await wait_seconds(0.4)
    await _same_night([host, guest])


func test_when_the_host_leaves_the_next_player_takes_over() -> void:
    var hub := LoopbackPeer.host()
    var host := _peer("Host", "H", hub)
    var first := _peer("First", "A", hub.add_client(2))
    var second := _peer("Second", "B", hub.add_client(3))
    await _gather(host, [first, second])
    first.submit(0, C.MOVE_DOWN)
    second.submit(0, C.MOVE_UP)
    await wait_seconds(0.6)
    # The host's tab closes.
    host.set_process(false)
    hub.close()
    await wait_seconds(0.2)
    assert_true(first.host_lost(), "slot 1 is next")
    assert_false(second.host_lost())
    assert_true(first.reconnecting)
    var tick := first.simulation.tick
    # The new host opens a session; the other rejoins it.
    var new_hub := LoopbackPeer.host()
    _api(first).multiplayer_peer = new_hub
    first.become_host()
    assert_true(first.reconnecting, "waits for the other player")
    await wait_seconds(0.3)
    assert_eq(first.simulation.tick, tick, "the night stands still meanwhile")
    _api(second).multiplayer_peer = new_hub.add_client(9)
    await _linked(first, second)
    second.say_hello()
    await wait_until(func() -> bool: return not first.reconnecting, 5.0)
    assert_eq(first.role, Night.Role.HOST)
    assert_eq(second.local_slots(), PackedInt32Array([2]), "same slot")
    assert_eq(first._views[0].pseudo, Night.GONE, "the old host is gone")
    second.submit(0, C.MOVE_DOWN)
    await wait_seconds(0.5)
    await _same_night([first, second])
    assert_gt(first.simulation.tick, tick, "and it goes on")


## A game scene with its own multiplayer API and this player id; returns its Night.
func _peer(root_name: String, id: String, peer: MultiplayerPeer) -> Night:
    var root := Node.new()
    root.name = root_name
    add_child_autofree(root)
    root.add_child(GAME_SCENE.instantiate())
    var api := SceneMultiplayer.new()
    get_tree().set_multiplayer(api, root.get_path())
    api.multiplayer_peer = peer
    _roots.append(root)
    _apis.append(api)
    var night: Night = root.get_node("Game/Night")
    night.looks_path = ""
    night.player_id = id
    return night


func _api(night: Night) -> SceneMultiplayer:
    return _apis[_roots.find(night.owner.get_parent())]


## As the Lobby does it: the host opens the lobby, the others say hello and join it, then the
## host opens the door.
func _gather(host: Night, guests: Array) -> void:
    for guest: Night in guests:
        await _linked(host, guest)
    host.host_lobby()
    for guest: Night in guests:
        guest.say_hello()
    var everyone := guests.size() + 1
    var in_lobby := func(g: Night) -> bool:
        return g.in_lobby and g.role == Night.Role.CLIENT and g.simulation.players.size() == everyone
    await wait_until(func() -> bool: return guests.all(in_lobby), 5.0)
    host.host_online()
    await wait_until(func() -> bool:
            return guests.all(func(g: Night) -> bool: return not g.in_lobby), 5.0)


## Until the host and this guest both see each other.
func _linked(host: Night, guest: Night) -> void:
    await wait_until(func() -> bool:
            return _api(guest).get_peers().has(1) and _api(host).get_peers().has(_api(guest).get_unique_id()), 5.0)


## Until this host sees this many peers.
func _connected(host: Night, peers: int) -> void:
    await wait_until(func() -> bool: return _api(host).get_peers().size() == peers, 5.0)


## Freezes the host, lets the others catch up, and checks they all agree.
func _same_night(nights: Array) -> void:
    var host: Night = nights[0]
    host.set_process(false)
    await wait_until(func() -> bool:
            return nights.all(func(n: Night) -> bool: return n.simulation.tick == host.simulation.tick), 5.0)
    for night: Night in nights:
        assert_eq(night.simulation.tick, host.simulation.tick, "%s is at the host's tick" % night.owner.get_parent().name)
        assert_eq(night.simulation.state_hash(), host.simulation.state_hash(),
                "%s agrees with the host" % night.owner.get_parent().name)
    host.set_process(true)
