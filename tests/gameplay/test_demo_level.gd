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


func test_the_clock_runs_from_18_00_to_04_00() -> void:
    assert_eq(Hud.clock(0), "18:00")
    assert_eq(Hud.clock(363), "00:03")
    assert_eq(Hud.clock(600), "04:00")


func test_enter_starts_a_new_night_once_it_is_over() -> void:
    var game: Node = add_child_autofree(GAME_SCENE.instantiate())
    var night: Night = game.get_node("Night")
    await wait_process_frames(1)
    var enter := InputEventKey.new()
    enter.physical_keycode = KEY_ENTER
    enter.pressed = true
    var before := night.simulation
    night._unhandled_input(enter)
    assert_eq(night.simulation, before, "Enter does nothing during the night")
    night.simulation.crowd.mood = night.simulation.rules.riot
    await wait_process_frames(3)
    assert_eq(night.simulation.outcome, &"lost")
    night._unhandled_input(enter)
    assert_ne(night.simulation, before)
    assert_eq(night.simulation.outcome, &"")


## The whole slice on the real kitchen: fry a batch, finish a portion, sauce, serve the first customer.
func test_a_scripted_player_serves_good_fries_on_the_demo_level() -> void:
    var game := GAME_SCENE.instantiate()
    var level := LevelReader.read(game.get_node("DemoLevel/Anchors"))
    game.free()
    const C := Simulation.Command
    var lift := 10 + Fryer.FIRST_FRY_MIN
    var put_in := lift + 20
    var done := put_in + Fryer.SECOND_FRY_MIN
    var scenario := Scenario.new(level, [level.find("Anchor")], 1) \
            .at(0, 0, C.MOVE_RIGHT) \
            .at(10, 0, C.INTERACT) \
            .at(lift, 0, C.INTERACT) \
            .at(lift + 1, 0, C.INTERACT) \
            .at(lift + 2, 0, C.MOVE_RIGHT).at(lift + 2, 0, C.MOVE_RIGHT) \
            .at(put_in, 0, C.INTERACT) \
            .at(done, 0, C.INTERACT) \
            .at(done + 1, 0, C.MOVE_DOWN).at(done + 1, 0, C.MOVE_LEFT).at(done + 1, 0, C.MOVE_LEFT) \
            .at(done + 30, 0, C.INTERACT) \
            .at(done + 31, 0, C.MOVE_RIGHT).at(done + 31, 0, C.MOVE_DOWN) \
            .at(done + 60, 0, C.INTERACT)
    var sim := scenario.run_until(done + 1)
    assert_eq(level.station_kind_at(sim.players[0].node), &"cuisson_2")
    assert_eq(sim.players[0].focused_item().kind, Fryer.FRIES_GOOD)
    sim = scenario.run_until(done + 61)
    assert_eq(level.station_kind_at(sim.players[0].node), &"caisse")
    assert_null(sim.players[0].focused_item(), "handed over")
    assert_eq(sim.stats.dishes, 1)
    assert_eq(sim.stats.bad_dishes, 0)


## Playtest bug: knocked out alone, crawling to SOINS didn't get the player back up.
func test_knocked_out_alone_a_player_crawls_to_soins_and_gets_up() -> void:
    var game := GAME_SCENE.instantiate()
    var level := LevelReader.read(game.get_node("DemoLevel/Anchors"))
    game.free()
    const C := Simulation.Command
    var scenario := Scenario.new(level, [level.find("Anchor")], 1)
    for i in SimPlayer.MAX_HEALTH:
        scenario.at(0, 0, C.DEBUG_DAMAGE)
    # Arrows pressed one at a time, as a player would, while crawling.
    for i in 6:
        scenario.at(1 + i * 70, 0, C.MOVE_RIGHT)
    var sim := scenario.run_until(1 + 6 * 70)
    var player := sim.players[0]
    assert_eq(level.names[player.node], "Anchor7", "at SOINS")
    assert_false(player.is_moving())
    assert_eq(sim.action_for(player), &"heal")
    scenario.at(sim.tick, 0, C.INTERACT).run_until(sim.tick + 1)
    assert_false(player.down)
    assert_eq(player.health, SimPlayer.MAX_HEALTH)


func test_the_heal_hint_shows_when_knocked_out_at_soins() -> void:
    var game: Node = add_child_autofree(GAME_SCENE.instantiate())
    var night: Night = game.get_node("Night")
    await wait_process_frames(1)
    var sim := night.simulation
    var player := sim.players[0]
    player.node = sim.level.find("Anchor7")
    player.health = 0
    player.down = true
    await wait_process_frames(2)
    var view: Player = night._views[0]
    assert_eq(view._hint_label.text, "Espace : se soigner")
    night.submit(0, Simulation.Command.INTERACT)
    await wait_seconds(0.2)
    assert_false(player.down)
