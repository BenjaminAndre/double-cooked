extends GutTest
## The double cuisson, hands and the stations around it (GDD §5.4, §7.1).

const INTERACT := Simulation.Command.INTERACT
const RIGHT := Simulation.Command.MOVE_RIGHT
const LEFT := Simulation.Command.MOVE_LEFT

var level: SimLevel
var fryer_1: int
var fryer_2: int
var sauces: int
var bin: int


## A row CUISSON 1 - CUISSON 2 - SAUCES - POUBELLE, one unit apart.
func before_each() -> void:
    level = SimLevel.new()
    fryer_1 = level.add_node(Vector3(0, 0, 0), level.add_station(&"cuisson_1"), "F1")
    fryer_2 = level.add_node(Vector3(1, 0, 0), level.add_station(&"cuisson_2"), "F2")
    sauces = level.add_node(Vector3(2, 0, 0), level.add_station(&"sauces"), "S")
    bin = level.add_node(Vector3(3, 0, 0), level.add_station(&"poubelle"), "B")
    for pair in [[fryer_1, fryer_2], [fryer_2, sauces], [sauces, bin]]:
        level.link(pair[0], SimLevel.Direction.RIGHT, pair[1])
        level.link(pair[1], SimLevel.Direction.LEFT, pair[0])


func test_an_empty_fryer_spawns_raw_fries_into_the_oil() -> void:
    var sim := Scenario.new(level, [fryer_1]).at(0, 0, INTERACT).run_until(10)
    var station := sim.stations[0]
    assert_eq(station.basket.kind, Fryer.FRIES_RAW)
    assert_true(station.frying)
    assert_eq(station.cook, 10)
    assert_null(sim.players[0].item, "the fries go into the oil, not the hand")


func test_lifting_too_early_gives_cold_fries() -> void:
    var sim := _first_fry_lifted_at(Fryer.FIRST_FRY_MIN - 1)
    assert_eq(sim.players[0].item.kind, Fryer.FRIES_COLD)
    assert_null(sim.stations[0].basket)


func test_lifting_in_time_leaves_the_batch_on_the_fryer() -> void:
    var sim := _first_fry_lifted_at(Fryer.FIRST_FRY_MIN)
    assert_null(sim.players[0].item)
    assert_eq(sim.stations[0].basket.kind, Fryer.FRIES_BLANCHED)
    assert_eq(sim.stations[0].basket.portions, Fryer.BATCH)
    assert_false(sim.stations[0].frying)


func test_lifting_too_late_gives_overcooked_fries() -> void:
    var sim := _first_fry_lifted_at(Fryer.FIRST_FRY_MAX + 1)
    assert_eq(sim.players[0].item.kind, Fryer.FRIES_OVERCOOKED)


func test_a_ruined_batch_goes_whole_into_the_hand() -> void:
    var item := _first_fry_lifted_at(Fryer.FIRST_FRY_MIN - 1).players[0].item
    assert_eq(item.kind, Fryer.FRIES_COLD)
    assert_eq(item.portions, Fryer.BATCH)


func test_lifting_into_the_hand_needs_a_free_hand() -> void:
    var scenario := Scenario.new(level, [fryer_1]).at(0, 0, INTERACT)
    var player := scenario.run_until(1).players[0]
    player.item = SimItem.new(Fryer.FRIES_COLD)
    scenario.at(1, 0, INTERACT).run_until(2)
    assert_true(scenario.simulation.stations[0].frying, "nothing happens with a full hand")


func test_portions_are_taken_one_at_a_time_until_the_fryer_is_free() -> void:
    var lift := Fryer.FIRST_FRY_MIN
    var scenario := Scenario.new(level, [fryer_1]).at(0, 0, INTERACT).at(lift, 0, INTERACT)
    var sim := scenario.run_until(lift + 1)
    var player := sim.players[0]
    for taken in Fryer.BATCH:
        scenario.at(sim.tick, 0, INTERACT).run_until(sim.tick + 1)
        assert_eq(player.item.kind, Fryer.FRIES_BLANCHED)
        assert_eq(player.item.portions, 1)
        player.item = null
    assert_null(sim.stations[0].basket, "CUISSON 1 is free once the batch is used up")


func test_a_blanched_portion_comes_out_good_from_a_timely_second_fry() -> void:
    var sim := _second_fry(Fryer.SECOND_FRY_MIN)
    assert_eq(sim.players[0].item.kind, Fryer.FRIES_GOOD)
    assert_eq(sim.stations[0].basket.portions, Fryer.BATCH - 1, "the rest of the batch waits")


func test_second_fry_lifted_too_early_is_soggy_and_too_late_is_burnt() -> void:
    assert_eq(_second_fry(Fryer.SECOND_FRY_MIN - 1).players[0].item.kind, Fryer.FRIES_SOGGY)
    assert_eq(_second_fry(Fryer.SECOND_FRY_MAX + 1).players[0].item.kind, Fryer.FRIES_BURNT)


func test_cuisson_2_only_takes_blanched_fries() -> void:
    var scenario := Scenario.new(level, [fryer_2])
    scenario.simulation.players[0].item = SimItem.new(Fryer.FRIES_COLD)
    scenario.at(0, 0, INTERACT).run_until(1)
    assert_null(scenario.simulation.stations[1].basket)
    assert_null(scenario.simulation.players[0].item, "the fryer won't take them, so they get eaten")
    assert_eq(scenario.simulation.players[0].bmi, 22)


func test_the_sauces_menu_puts_the_chosen_sauce_on() -> void:
    var scenario := Scenario.new(level, [sauces])
    var player := scenario.simulation.players[0]
    player.item = SimItem.new(Fryer.FRIES_GOOD)
    scenario.at(0, 0, INTERACT).run_until(1)
    assert_eq(player.menu, 2, "the first press opens the menu")
    assert_eq(player.item.sauce, &"", "nothing chosen yet")
    scenario.at(1, 0, RIGHT).at(2, 0, INTERACT).run_until(3)
    assert_eq(player.item.sauce, Menu.ANDALOUSE)
    assert_eq(player.menu, SimLevel.NONE, "choosing closes the menu")
    assert_eq(player.node, sauces, "the arrows didn't move the player")


func test_escape_closes_a_menu_without_taking_anything() -> void:
    var scenario := Scenario.new(level, [sauces])
    var player := scenario.simulation.players[0]
    player.item = SimItem.new(Fryer.FRIES_GOOD)
    scenario.at(0, 0, INTERACT).at(1, 0, Simulation.Command.CANCEL).run_until(2)
    assert_eq(player.menu, SimLevel.NONE)
    assert_eq(player.item.sauce, &"")
    scenario.at(2, 0, RIGHT).run_until(3)
    assert_true(player.is_moving(), "arrows move the player again")


func test_sauces_only_open_for_a_food_without_sauce() -> void:
    var scenario := Scenario.new(level, [sauces])
    var player := scenario.simulation.players[0]
    player.item = SimItem.new(Fryer.FRIES_COLD)
    scenario.at(0, 0, INTERACT).run_until(1)
    assert_eq(player.menu, SimLevel.NONE, "no sauce on cold fries")
    player.item = SimItem.new(Menu.COLA)
    scenario.at(1, 0, INTERACT).run_until(2)
    assert_eq(player.menu, SimLevel.NONE, "nor on a cola")
    assert_eq(player.menu, SimLevel.NONE, "no sauce on cold fries nor on a cola")


func test_the_menu_wraps_around() -> void:
    var scenario := Scenario.new(level, [sauces])
    var player := scenario.simulation.players[0]
    player.item = SimItem.new(Fryer.FRIES_GOOD)
    scenario.at(0, 0, INTERACT).at(1, 0, LEFT).run_until(2)
    assert_eq(player.menu_choice, Menu.SAUCES.size() - 1)


func test_the_bin_empties_the_hand() -> void:
    var scenario := Scenario.new(level, [bin])
    var player := scenario.simulation.players[0]
    player.item = SimItem.new(Fryer.FRIES_BURNT)
    scenario.at(0, 0, INTERACT).run_until(1)
    assert_null(player.item)


func test_a_bump_stops_the_bumper_and_stuns_the_bumped_who_keeps_their_item() -> void:
    var scenario := Scenario.new(level, [fryer_2, sauces])
    var bumped := scenario.simulation.players[0]
    bumped.item = SimItem.new(Fryer.FRIES_GOOD)
    scenario.at(0, 1, LEFT).at(0, 1, LEFT).run_until(1)
    var bumper := scenario.simulation.players[1]
    assert_true(bumper.path.is_empty(), "the bumper stops and must pick another way")
    assert_eq(bumped.item.kind, Fryer.FRIES_GOOD)
    assert_eq(bumped.stun, SimRules.new().bump_stun)


func test_a_stunned_player_can_neither_move_nor_act() -> void:
    var scenario := Scenario.new(level, [fryer_2, sauces]).at(0, 1, LEFT)
    var sim := scenario.run_until(1)
    var bumped := sim.players[0]
    scenario.at(1, 0, LEFT).at(2, 0, INTERACT).run_until(3)
    assert_eq(bumped.node, fryer_2)
    assert_false(bumped.is_moving(), "the press during the stun is lost")
    assert_null(sim.stations[1].basket)
    scenario.run_until(1 + sim.rules.bump_stun)
    assert_eq(bumped.stun, 0)
    scenario.at(sim.tick, 0, LEFT).run_until(sim.tick + 1)
    assert_true(bumped.is_moving(), "moves again once it wears off")


func _first_fry_lifted_at(tick: int) -> Simulation:
    return Scenario.new(level, [fryer_1]).at(0, 0, INTERACT).at(tick, 0, INTERACT).run_until(tick + 1)


## The whole route: first fry lifted in time, one portion taken and carried to CUISSON 2,
## put in, then lifted after second_fry ticks.
func _second_fry(second_fry: int) -> Simulation:
    var lift := Fryer.FIRST_FRY_MIN
    var put_in := lift + 10
    var scenario := Scenario.new(level, [fryer_1]).at(0, 0, INTERACT).at(lift, 0, INTERACT) \
            .at(lift + 1, 0, INTERACT).at(lift + 2, 0, RIGHT) \
            .at(put_in, 0, INTERACT).at(put_in + second_fry, 0, INTERACT)
    return scenario.run_until(put_in + second_fry + 1)


func test_the_hint_matches_what_each_fryer_step_would_do() -> void:
    var scenario := Scenario.new(level, [fryer_1])
    var sim := scenario.simulation
    var player := sim.players[0]
    assert_eq(sim.action_for(player), &"fry", "empty CUISSON 1")
    scenario.at(0, 0, INTERACT).run_until(10)
    assert_eq(sim.action_for(player), &"lift", "frying, free hand")
    player.item = SimItem.new(Fryer.FRIES_COLD)
    assert_eq(sim.action_for(player), &"eat", "too early with a full hand: the fryer can't, so you eat")
    scenario.run_until(Fryer.FIRST_FRY_MIN)
    assert_eq(sim.action_for(player), &"lift", "in the window the basket stays, so a full hand is fine")
    scenario.at(Fryer.FIRST_FRY_MIN, 0, INTERACT).run_until(Fryer.FIRST_FRY_MIN + 1)
    assert_eq(sim.action_for(player), &"eat", "batch waiting, but the hand is full")
    player.item = null
    assert_eq(sim.action_for(player), &"take")


func test_the_hint_at_cuisson_2_sauces_and_the_bin() -> void:
    var scenario := Scenario.new(level, [fryer_2])
    var sim := scenario.simulation
    var player := sim.players[0]
    assert_eq(sim.action_for(player), &"", "nothing to put in")
    player.item = SimItem.new(Fryer.FRIES_BLANCHED)
    assert_eq(sim.action_for(player), &"fry")
    player.node = sauces
    player.item = SimItem.new(Fryer.FRIES_GOOD)
    assert_eq(sim.action_for(player), &"sauce")
    player.item.sauce = Menu.MAYO
    assert_eq(sim.action_for(player), &"eat", "already has mayo, so it's dinner")
    player.node = bin
    assert_eq(sim.action_for(player), &"trash")
    player.item = null
    assert_eq(sim.action_for(player), &"")
