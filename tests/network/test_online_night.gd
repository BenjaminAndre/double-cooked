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
    host_night.looks_path = ""
    client_night.looks_path = ""
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
    # The host (slot 0, at the FRIGO) walks right; the client (slot 1, at the second CUISSON
    # VIANDE) walks down.
    host_night.submit(0, Simulation.Command.MOVE_RIGHT)
    client_night.submit(0, Simulation.Command.MOVE_DOWN)
    await wait_until(func() -> bool: return _walked(host_night) and _walked(client_night), 5.0)
    # Freeze the host and let the client catch up to the same tick.
    host_night.set_process(false)
    await wait_until(func() -> bool:
            return client_night.simulation.tick == host_night.simulation.tick, 5.0)
    var level := host_night.simulation.level
    for night in [host_night, client_night]:
        assert_eq(level.names[night.simulation.players[0].node], "Cuisson1")
        assert_eq(level.names[night.simulation.players[1].node], "ViandesB")
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


func test_the_hosts_test_tools_keep_the_guest_in_sync_and_a_guests_are_dropped() -> void:
    const Tool := Simulation.DebugTool
    host_night.host_lobby()
    await wait_until(func() -> bool: return client_night.role == Night.Role.CLIENT, 5.0)
    host_night.jump_to_night(4)
    await wait_until(func() -> bool: return client_night.campaign_night == 4, 5.0)
    assert_true(client_night.debug_used, "the guest knows the night was reached with a tool")
    # A guest can't use them: the host drops the command.
    client_night.submit(0, Simulation.debug_command(Tool.MOOD, SimCrowd.Level.EMEUTE))
    host_night.use_tool(Tool.FILL_LINE)
    host_night.use_tool(Tool.FIRE)
    host_night.use_tool(Tool.CLOCK, Simulation.ClockJump.BOSS)
    await wait_until(func() -> bool: return client_night.simulation.crowd.boss_came, 5.0)
    host_night.set_process(false)
    await wait_until(func() -> bool:
            return client_night.simulation.tick == host_night.simulation.tick, 5.0)
    assert_eq(client_night.simulation.state_hash(), host_night.simulation.state_hash())
    assert_eq(host_night.simulation.crowd.level(), SimCrowd.Level.CALME)
    assert_true(client_night.simulation.stations.any(func(s: SimStation) -> bool: return s.burning))
    assert_eq(client_night.desyncs, 0)


func test_a_client_says_when_the_host_goes_silent() -> void:
    host_night.host_online()
    await wait_until(func() -> bool: return client_night.role == Night.Role.CLIENT, 5.0)
    assert_eq(Hud.silence_text(client_night.host_silence()), "")
    # A host whose tab is frozen.
    host_night.set_process(false)
    await wait_seconds(Hud.SILENCE_WARNING + 0.3)
    assert_string_starts_with(Hud.silence_text(client_night.host_silence()), "L'hôte ne répond plus")
    assert_eq(host_night.host_silence(), 0.0)


func test_a_client_far_behind_catches_up_in_one_go() -> void:
    host_night.host_online()
    await wait_until(func() -> bool: return client_night.role == Night.Role.CLIENT, 5.0)
    # A client whose tab was hidden: the host's ticks pile up.
    client_night.set_process(false)
    await wait_seconds(1.0)
    host_night.set_process(false)
    var behind := host_night.simulation.tick - client_night.simulation.tick
    assert_gt(behind, Simulation.TICK_RATE / 2)
    client_night._advance()
    assert_true(host_night.simulation.tick - client_night.simulation.tick <= Night.CLIENT_LAG_TICKS)


func test_a_player_who_leaves_stays_idle_and_is_marked_on_every_peer() -> void:
    host_night.host_online()
    await wait_until(func() -> bool: return client_night.role == Night.Role.CLIENT, 5.0)
    host_night.peer_left(host_api.get_peers()[0])
    await wait_until(func() -> bool: return client_night._views[1].pseudo.ends_with("(parti)"), 5.0)
    assert_string_ends_with(host_night._views[1].pseudo, "(parti)")
    # The host no longer takes that peer's keys, and the night goes on.
    var node := host_night.simulation.players[1].node
    client_night.submit(0, Simulation.Command.MOVE_UP)
    var tick := host_night.simulation.tick
    await wait_seconds(0.5)
    assert_gt(host_night.simulation.tick, tick)
    assert_eq(host_night.simulation.players[1].node, node)


func test_the_lobby_is_shared_and_the_door_takes_everyone_with_their_looks() -> void:
    const C := Simulation.Command
    host_night.host_lobby()
    await wait_until(func() -> bool: return client_night.role == Night.Role.CLIENT, 5.0)
    assert_true(client_night.in_lobby)
    # The guest picks the yellow character and the beer helmet, then stands on the PRÊT tile below them.
    client_night.submit(0, Looks.command(3, 2))
    client_night.submit(0, C.MOVE_DOWN)
    var ready_tile := host_night.simulation.level.find("Cell2_1")
    await wait_until(func() -> bool: return host_night.simulation.players[1].node == ready_tile, 5.0)
    # The host walks right along the middle row, then down across the PRÊT tiles to the door.
    for i in 2:
        host_night.submit(0, C.MOVE_RIGHT)
    for i in 2:
        host_night.submit(0, C.MOVE_DOWN)
    var door := host_night.simulation.level.find("Cell3_2")
    await wait_until(func() -> bool:
            var sim := host_night.simulation
            return sim.players[0].node == door and not sim.players[0].is_moving() \
                    and sim.others_ready(sim.players[0]), 5.0)
    assert_eq(host_night.simulation.action_for(host_night.simulation.players[0]), &"open")
    # The door's menu opens on the campaign.
    host_night.submit(0, C.INTERACT)
    await wait_until(func() -> bool: return host_night.simulation.players[0].menu != SimLevel.NONE, 5.0)
    host_night.submit(0, C.INTERACT)
    await wait_until(func() -> bool: return not client_night.in_lobby, 5.0)
    assert_false(host_night.in_lobby)
    assert_eq(client_night.campaign_night, 1, "the first night of a campaign, on both")
    assert_eq(client_night.simulation.rules.menu, Campaign.menu_for(1))
    for night in [host_night, client_night]:
        assert_eq(night.simulation.players[1].color, 3)
        assert_eq(Looks.HATS[night.simulation.players[1].hat], Looks.BEER_HELMET)
        assert_eq(night.simulation.players[0].color, 0)


func _peer_root(root_name: String) -> Node:
    var root := Node.new()
    root.name = root_name
    add_child_autofree(root)
    root.add_child(GAME_SCENE.instantiate())
    return root


## Both players have arrived one node away from their spawn, and a fingerprint check is due.
func _walked(night: Night) -> bool:
    var players := night.simulation.players
    return players[0].node != night.simulation.level.find("Frigo") \
            and players[1].node != night.simulation.level.find("CuissonViande2") \
            and night.simulation.tick > Night.CHECK_EVERY
