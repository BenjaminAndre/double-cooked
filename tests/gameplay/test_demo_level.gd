extends GutTest
## The real kitchen: reading its anchors, and the game scene starting up.

const GAME_SCENE := preload("res://game.tscn")


func test_reads_every_anchor_with_its_links_and_stations() -> void:
    var game := GAME_SCENE.instantiate()
    var level := LevelReader.read(game.get_node("DemoLevel/Anchors"))
    assert_eq(level.positions.size(), 15)
    var spawn := level.find("Anchor")
    assert_eq(level.neighbour(spawn, SimLevel.Direction.RIGHT), level.find("Anchor2"))
    assert_eq(level.neighbour(spawn, SimLevel.Direction.DOWN), level.find("Anchor8"))
    assert_eq(level.neighbour(spawn, SimLevel.Direction.UP), SimLevel.NONE)
    assert_eq(level.station_kind_at(level.find("Anchor7")), &"soins")
    assert_eq(level.node_stations[level.find("Anchor2")], level.node_stations[level.find("Anchor3")],
            "both anchors reach the same CUISSON 1")
    assert_eq(level.station_kinds.size(), 11)
    game.free()


func test_walks_from_the_spawn_to_soins_and_heals() -> void:
    var game := GAME_SCENE.instantiate()
    var level := LevelReader.read(game.get_node("DemoLevel/Anchors"))
    game.free()
    var scenario := Scenario.new(level, [level.find("Anchor")]) \
            .at(0, 0, Simulation.Command.DEBUG_DAMAGE)
    for i in 6:
        scenario.at(0, 0, Simulation.Command.MOVE_RIGHT)
    var player := scenario.run_until(60).players[0]
    assert_eq(level.names[player.node], "Anchor7")
    assert_eq(player.health, SimPlayer.MAX_HEALTH - 1)
    scenario.at(60, 0, Simulation.Command.INTERACT).run_until(61)
    assert_eq(player.health, SimPlayer.MAX_HEALTH)


func test_the_game_scene_starts_a_night_and_toggles_duo() -> void:
    var game: Node = add_child_autofree(GAME_SCENE.instantiate())
    var night: Night = game.get_node("Night")
    await wait_process_frames(2)
    assert_eq(night.simulation.players.size(), 1)
    assert_eq(game.get_node("DemoLevel").get_children().filter(func(n): return n is Player).size(), 1)
    night.play_local(2)
    await wait_process_frames(2)
    assert_eq(night.simulation.players.size(), 2)
    assert_eq(game.get_node("DemoLevel").get_children().filter(func(n): return n is Player).size(), 2)
