extends GutTest
## The lobby's rules (GDD §4.1): looks, the phone, ready tiles and the door.

const C := Simulation.Command

var level: SimLevel
var rules: SimRules


## In a row, left to right: PEINTURE, CASQUETTE, TÉLÉPHONE, PORTE, PRÊT, PRÊT.
func before_each() -> void:
    level = SimLevel.new()
    var nodes := []
    for kind in [&"peinture", &"casquette", &"telephone", &"porte", &"pret", &"pret"]:
        nodes.append(level.add_node(Vector3(-nodes.size(), 0, 0), level.add_station(kind), String(kind)))
    for index in nodes.size() - 1:
        level.link(nodes[index], SimLevel.Direction.RIGHT, nodes[index + 1])
        level.link(nodes[index + 1], SimLevel.Direction.LEFT, nodes[index])
    rules = SimRules.new()
    rules.lobby = true


func test_players_start_with_distinct_colours_and_a_cap() -> void:
    var sim := _scenario([0, 4]).simulation
    assert_eq(sim.players[0].color, 0)
    assert_eq(sim.players[1].color, 1)
    assert_eq(Looks.HATS[sim.players[0].hat], Looks.CAP)


func test_the_four_characters_sit_around_the_first_one() -> void:
    var scenario := _scenario([0])
    var sim := scenario.at(0, 0, C.INTERACT).run_until(1)
    assert_eq(sim.players[0].menu_choice, 0, "opens in the centre")
    # The fourth option sits below the first.
    scenario.at(1, 0, C.MOVE_DOWN).at(1, 0, C.INTERACT).run_until(2)
    assert_eq(sim.players[0].color, 3)
    # Nothing above: up stays put; the third is on the left.
    scenario.at(2, 0, C.INTERACT).at(2, 0, C.MOVE_UP).at(2, 0, C.MOVE_LEFT).at(2, 0, C.INTERACT)
    scenario.run_until(3)
    assert_eq(sim.players[0].color, 2)


func test_menus_grow_around_their_first_option_without_moving_it() -> void:
    # Right, left, below, bottom right, bottom left, above, top right, top left.
    var cells := [Vector2i(1, 1), Vector2i(2, 1), Vector2i(0, 1), Vector2i(1, 2), Vector2i(2, 2),
            Vector2i(0, 2), Vector2i(1, 0), Vector2i(2, 0), Vector2i(0, 0)]
    for index in cells.size():
        assert_eq(Menu.option_at(cells[index], 9), index)
        assert_eq(Menu.option_at(cells[index], index), -1, "empty until the menu has that many")


func test_a_colour_worn_by_a_teammate_cant_be_taken() -> void:
    var scenario := _scenario([0, 4])
    var sim := scenario.simulation
    sim.players[0].color = 2
    sim.players[1].color = 0
    scenario.at(0, 0, C.INTERACT).at(0, 0, C.INTERACT).run_until(1)
    assert_eq(sim.players[0].color, 2, "the middle one is taken")
    assert_ne(sim.players[0].menu, SimLevel.NONE, "the menu stays open")


func test_the_hat_stand_offers_three_hats() -> void:
    var scenario := _scenario([1])
    var sim := scenario.at(0, 0, C.INTERACT).at(0, 0, C.MOVE_LEFT).at(0, 0, C.INTERACT).run_until(1)
    assert_eq(Looks.HATS[sim.players[0].hat], Looks.BEER_HELMET)


func test_saved_looks_come_as_a_command() -> void:
    var scenario := _scenario([4, 5])
    scenario.at(0, 0, Looks.command(1, 0)).run_until(1)
    assert_eq(scenario.simulation.players[0].color, 0, "rouge is worn by the second player")
    assert_eq(scenario.simulation.players[0].hat, 0)
    scenario.at(1, 0, Looks.command(3, 2)).run_until(2)
    assert_eq(scenario.simulation.players[0].color, 3)


func test_the_phone_reports_the_choice() -> void:
    var scenario := _scenario([2])
    scenario.at(0, 0, C.INTERACT).at(0, 0, C.MOVE_RIGHT).at(0, 0, C.INTERACT).run_until(1)
    var phone := scenario.events.filter(func(e: Dictionary) -> bool: return e.type == &"phone")
    assert_eq(phone.size(), 1)
    assert_eq(phone[0].choice, Menu.PHONE_JOIN)


func test_the_host_opens_the_door_once_everyone_else_is_ready() -> void:
    # The host at the door, a teammate one tile before the PRÊT tiles.
    var scenario := _scenario([3, 2])
    var sim := scenario.simulation
    assert_eq(sim.action_for(sim.players[0]), &"door_wait")
    assert_eq(sim.action_for(sim.players[1]), &"phone")
    scenario.at(0, 0, C.INTERACT).run_until(1)
    assert_false(_started(scenario), "not while a teammate isn't ready")
    # The teammate can't walk through the host: go round by putting them on a PRÊT tile.
    sim.players[1].node = level.find("pret")
    assert_eq(sim.action_for(sim.players[0]), &"open")
    assert_eq(sim.action_for(sim.players[1]), &"")
    # The door opens its menu: a campaign first, or a single night.
    scenario.at(1, 0, C.INTERACT).run_until(2)
    assert_false(_started(scenario), "not before choosing")
    assert_eq(Menu.options(&"porte")[sim.players[0].menu_choice], Menu.DOOR_CAMPAIGN)
    scenario.at(2, 0, C.INTERACT).run_until(3)
    assert_true(_started(scenario))


func test_only_the_host_opens_the_door() -> void:
    var scenario := _scenario([4, 3])
    assert_eq(scenario.simulation.action_for(scenario.simulation.players[1]), &"door_host")


func test_nothing_else_happens_in_the_lobby() -> void:
    var scenario := _scenario([4])
    var sim := scenario.run_until(60 * Simulation.TICK_RATE)
    assert_true(sim.crowd.line.is_empty())
    assert_eq(sim.outcome, &"")
    # Walking back and forth burns nothing.
    for tick in range(sim.tick, sim.tick + 200, 20):
        scenario.at(tick, 0, C.MOVE_LEFT if tick % 40 == 0 else C.MOVE_RIGHT)
    scenario.run_until(sim.tick + 220)
    assert_eq(sim.players[0].bmi, rules.start_bmi)


func _scenario(nodes: Array) -> Scenario:
    var spawns := PackedInt32Array()
    for node in nodes:
        spawns.append(node)
    return Scenario.new(level, spawns, 1, rules)


func _started(scenario: Scenario) -> bool:
    return scenario.events.any(func(e: Dictionary) -> bool: return e.type == &"start_night")
