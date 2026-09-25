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
    assert_eq(level.station_kind_at(level.find("Anchor")), &"frigo")
    assert_eq(level.node_stations[level.find("Anchor2")], level.node_stations[level.find("Anchor3")],
            "both anchors reach the same CUISSON 1")
    assert_eq(level.station_kinds.size(), 10)
    game.free()


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
            .at(done + 30, 0, C.INTERACT).at(done + 31, 0, C.INTERACT) \
            .at(done + 32, 0, C.MOVE_RIGHT).at(done + 32, 0, C.MOVE_DOWN) \
            .at(done + 60, 0, C.INTERACT)
    var sim := scenario.run_until(done + 1)
    assert_eq(level.station_kind_at(sim.players[0].node), &"cuisson_2")
    assert_eq(sim.players[0].item.kind, Fryer.FRIES_GOOD)
    # Orders are random; this customer wants what the script makes (SAUCES' first option).
    sim.crowd.front().order = &"frites:mayo"
    sim = scenario.run_until(done + 61)
    assert_eq(level.station_kind_at(sim.players[0].node), &"caisse")
    assert_null(sim.players[0].item, "handed over")
    assert_eq(sim.stats.served, 1)
    assert_eq(sim.stats.angry, 0)


## Knocked out alone, a player crawls to the FRIGO, takes a beer and drinks it to get up.
func test_knocked_out_alone_a_player_crawls_to_the_fridge_and_drinks() -> void:
    var game := GAME_SCENE.instantiate()
    var level := LevelReader.read(game.get_node("DemoLevel/Anchors"))
    game.free()
    const C := Simulation.Command
    var scenario := Scenario.new(level, [level.find("Anchor2")], 1)
    for i in SimPlayer.MAX_HEALTH:
        scenario.at(0, 0, C.DEBUG_DAMAGE)
    var sim := scenario.at(1, 0, C.MOVE_LEFT).run_until(1 + 2 * sim_rules().crawl_ticks)
    var player := sim.players[0]
    assert_true(player.down)
    assert_eq(level.station_kind_at(player.node), &"frigo")
    assert_eq(sim.action_for(player), &"fridge", "the fridge still works when down")
    var t := sim.tick
    scenario.at(t, 0, C.INTERACT).at(t + 1, 0, C.MOVE_RIGHT).at(t + 2, 0, C.INTERACT).run_until(t + 3)
    assert_eq(player.item.kind, Menu.BEER)
    assert_eq(sim.action_for(player), &"drink")
    scenario.at(t + 3, 0, C.INTERACT).at(t + 3, 0, C.RELEASE).run_until(t + 4)
    assert_false(player.down)
    assert_eq(player.health, 1)
    assert_eq(player.fat, 1)


func test_the_drink_hint_shows_when_knocked_out_with_a_beer() -> void:
    var game: Node = add_child_autofree(GAME_SCENE.instantiate())
    var night: Night = game.get_node("Night")
    await wait_process_frames(1)
    var player := night.simulation.players[0]
    player.health = 0
    player.down = true
    player.item = SimItem.new(Menu.BEER)
    await wait_process_frames(2)
    var view: Player = night._views[0]
    assert_eq(view._hint_label.text, "Espace : boire")
    night.submit(0, Simulation.Command.INTERACT)
    night.submit(0, Simulation.Command.RELEASE)
    await wait_seconds(0.2)
    assert_false(player.down)


func sim_rules() -> SimRules:
    return SimRules.new()
