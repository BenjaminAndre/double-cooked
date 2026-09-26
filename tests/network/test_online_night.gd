extends GutTest
## A host and a client in one process, each with its own game scene and multiplayer API,
## connected by an in-memory LoopbackPeer (no socket, no network rights needed). The Night
## code only sees Godot's multiplayer API, so this exercises the same RPCs as Tube, which
## only adds the WebRTC transport and signaling.

const GAME_SCENE := preload("res://game.tscn")

var host_api: SceneMultiplayer
var client_api: SceneMultiplayer
var host_night: Night
var client_night: Night


func before_each() -> void:
    var host_root := _peer_root("Host")
    var client_root := _peer_root("Client")
    host_api = SceneMultiplayer.new()
    client_api = SceneMultiplayer.new()
    get_tree().set_multiplayer(host_api, host_root.get_path())
    get_tree().set_multiplayer(client_api, client_root.get_path())
    var peers := LoopbackPeer.pair()
    host_api.multiplayer_peer = peers[0]
    client_api.multiplayer_peer = peers[1]
    host_night = host_root.get_node("Game/Night")
    client_night = client_root.get_node("Game/Night")
    await wait_until(func() -> bool: return host_api.get_peers().size() == 1, 5.0)


func after_each() -> void:
    host_api.multiplayer_peer.close()
    client_api.multiplayer_peer.close()
    get_tree().set_multiplayer(null, host_night.owner.get_parent().get_path())
    get_tree().set_multiplayer(null, client_night.owner.get_parent().get_path())


func test_the_client_joins_the_hosts_night() -> void:
    host_night.host_online()
    await wait_until(func() -> bool: return client_night.role == Night.Role.CLIENT, 5.0)
    assert_eq(client_night.simulation.players.size(), 2)
    assert_eq(client_night.local_slots(), PackedInt32Array([1]))
    assert_eq(client_night.simulation.rng.seed, host_night.simulation.rng.seed)


func test_both_players_moves_reach_both_peers_identically() -> void:
    host_night.host_online()
    await wait_until(func() -> bool: return client_night.role == Night.Role.CLIENT, 5.0)
    # The host (slot 0, at Anchor) walks right; the client (slot 1, at Anchor6) walks down.
    host_night.submit(0, Simulation.Command.MOVE_RIGHT)
    client_night.submit(0, Simulation.Command.MOVE_DOWN)
    await wait_until(func() -> bool: return _walked(host_night) and _walked(client_night), 5.0)
    # Freeze the host and let the client catch up to the same tick.
    host_night.set_process(false)
    await wait_until(func() -> bool:
            return client_night.simulation.tick == host_night.simulation.tick, 5.0)
    var level := host_night.simulation.level
    for night in [host_night, client_night]:
        assert_eq(level.names[night.simulation.players[0].node], "Anchor2")
        assert_eq(level.names[night.simulation.players[1].node], "Anchor13")
    assert_eq(client_night.simulation.state_hash(), host_night.simulation.state_hash())
    assert_true(client_night.simulation.tick >= Night.CHECK_EVERY, "at least one fingerprint check ran")
    assert_eq(client_night.desyncs, 0)


func test_a_client_that_drifts_from_the_host_shows_it_and_keeps_it_in_its_replay() -> void:
    host_night.host_online()
    await wait_until(func() -> bool: return client_night.role == Night.Role.CLIENT, 5.0)
    # Something only the client sees: the next fingerprint check can't match.
    client_night.simulation.crowd.mood += 1
    await wait_until(func() -> bool: return client_night.desyncs > 0, 5.0)
    assert_eq(host_night.desyncs, 0)
    assert_ne(Hud.desync_text(client_night.desyncs), "")
    assert_eq(Hud.desync_text(0), "")
    var replay: Dictionary = client_night.replay()
    assert_eq(replay.desync_ticks.size(), client_night.desyncs)
    assert_eq(replay.desync_ticks[0] % Night.CHECK_EVERY, 0)


func _peer_root(root_name: String) -> Node:
    var root := Node.new()
    root.name = root_name
    add_child_autofree(root)
    root.add_child(GAME_SCENE.instantiate())
    return root


## Both players have arrived one node away from their spawn, and a fingerprint check is due.
func _walked(night: Night) -> bool:
    var players := night.simulation.players
    return players[0].node != night.simulation.level.find("Anchor") \
            and players[1].node != night.simulation.level.find("Anchor6") \
            and night.simulation.tick > Night.CHECK_EVERY
