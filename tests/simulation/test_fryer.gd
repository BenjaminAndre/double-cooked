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
    assert_null(sim.players[0].focused_item(), "the fries go into the oil, not the hand")


func test_lifting_too_early_gives_cold_fries() -> void:
    var sim := _first_fry_lifted_at(Fryer.FIRST_FRY_MIN - 1)
    assert_eq(sim.players[0].focused_item().kind, Fryer.FRIES_COLD)
    assert_null(sim.stations[0].basket)


func test_lifting_in_time_leaves_the_basket_resting_on_the_fryer() -> void:
    var sim := _first_fry_lifted_at(Fryer.FIRST_FRY_MIN)
    assert_null(sim.players[0].focused_item())
    assert_eq(sim.stations[0].basket.kind, Fryer.FRIES_RESTING)
    assert_false(sim.stations[0].frying)


func test_lifting_too_late_gives_overcooked_fries() -> void:
    var sim := _first_fry_lifted_at(Fryer.FIRST_FRY_MAX + 1)
    assert_eq(sim.players[0].focused_item().kind, Fryer.FRIES_OVERCOOKED)


func test_lifting_into_the_hand_needs_the_focused_hand_free() -> void:
    var scenario := Scenario.new(level, [fryer_1]).at(0, 0, INTERACT)
    var player := scenario.run_until(1).players[0]
    player.hands[SimPlayer.Hand.LEFT] = SimItem.new(Fryer.FRIES_COLD)
    scenario.at(1, 0, INTERACT).run_until(2)
    assert_true(scenario.simulation.stations[0].frying, "nothing happens with a full hand")
    scenario.at(2, 0, Simulation.Command.FOCUS_RIGHT).at(2, 0, INTERACT).run_until(3)
    assert_eq(player.hands[SimPlayer.Hand.RIGHT].kind, Fryer.FRIES_COLD)


func test_rest_keeps_running_in_the_hand() -> void:
    var lift := Fryer.FIRST_FRY_MIN
    var scenario := Scenario.new(level, [fryer_1]).at(0, 0, INTERACT).at(lift, 0, INTERACT) \
            .at(lift + 10, 0, INTERACT)
    var player := scenario.run_until(lift + 30).players[0]
    assert_eq(player.focused_item().kind, Fryer.FRIES_RESTING)
    assert_eq(player.focused_item().rest, 30)
    assert_null(scenario.simulation.stations[0].basket, "CUISSON 1 is free again")


func test_rested_fries_come_out_good() -> void:
    var put_in := Fryer.FIRST_FRY_MIN + Fryer.REST_NEEDED
    var sim := _second_fry(put_in, Fryer.SECOND_FRY_MIN)
    assert_eq(sim.players[0].focused_item().kind, Fryer.FRIES_GOOD)


func test_fries_that_didnt_rest_enough_come_out_soggy() -> void:
    var put_in := Fryer.FIRST_FRY_MIN + Fryer.REST_NEEDED - 1
    var sim := _second_fry(put_in, Fryer.SECOND_FRY_MIN)
    assert_eq(sim.players[0].focused_item().kind, Fryer.FRIES_SOGGY)


func test_second_fry_lifted_too_early_is_soggy_and_too_late_is_burnt() -> void:
    var put_in := Fryer.FIRST_FRY_MIN + Fryer.REST_NEEDED
    assert_eq(_second_fry(put_in, Fryer.SECOND_FRY_MIN - 1).players[0].focused_item().kind,
            Fryer.FRIES_SOGGY)
    assert_eq(_second_fry(put_in, Fryer.SECOND_FRY_MAX + 1).players[0].focused_item().kind,
            Fryer.FRIES_BURNT)


func test_cuisson_2_only_takes_resting_fries() -> void:
    var scenario := Scenario.new(level, [fryer_2])
    scenario.simulation.players[0].hands[0] = SimItem.new(Fryer.FRIES_COLD)
    scenario.at(0, 0, INTERACT).run_until(1)
    assert_null(scenario.simulation.stations[1].basket)
    assert_eq(scenario.simulation.players[0].focused_item().kind, Fryer.FRIES_COLD)


func test_sauces_only_go_on_finished_fries() -> void:
    var scenario := Scenario.new(level, [sauces])
    var player := scenario.simulation.players[0]
    player.hands = [SimItem.new(Fryer.FRIES_GOOD), SimItem.new(Fryer.FRIES_COLD)]
    scenario.at(0, 0, INTERACT).at(0, 0, Simulation.Command.FOCUS_RIGHT).at(0, 0, INTERACT)
    scenario.run_until(1)
    assert_true(player.hands[0].sauce)
    assert_false(player.hands[1].sauce)


func test_the_bin_empties_only_the_focused_hand() -> void:
    var scenario := Scenario.new(level, [bin])
    var player := scenario.simulation.players[0]
    player.hands = [SimItem.new(Fryer.FRIES_BURNT), SimItem.new(Fryer.FRIES_GOOD)]
    scenario.at(0, 0, INTERACT).run_until(1)
    assert_null(player.hands[0])
    assert_eq(player.hands[1].kind, Fryer.FRIES_GOOD)


func test_a_bump_drops_the_unfocused_hand_and_keeps_the_focused_one() -> void:
    var scenario := Scenario.new(level, [fryer_2, sauces])
    var bumped := scenario.simulation.players[0]
    bumped.hands = [SimItem.new(Fryer.FRIES_GOOD), SimItem.new(Fryer.FRIES_SOGGY)]
    scenario.at(0, 1, LEFT).run_until(1)
    assert_eq(bumped.hands[0].kind, Fryer.FRIES_GOOD, "focused (left) hand is safe")
    assert_null(bumped.hands[1])
    assert_eq(scenario.events[1], {"type": &"drop", "slot": 0, "item": Fryer.FRIES_SOGGY, "tick": 0})


func test_a_bump_with_an_empty_unfocused_hand_loses_nothing() -> void:
    var scenario := Scenario.new(level, [fryer_2, sauces])
    scenario.simulation.players[0].hands[0] = SimItem.new(Fryer.FRIES_GOOD)
    scenario.at(0, 1, LEFT).run_until(1)
    assert_eq(scenario.simulation.players[0].hands[0].kind, Fryer.FRIES_GOOD)
    assert_eq(scenario.events.size(), 1, "a bump, no drop")


func _first_fry_lifted_at(tick: int) -> Simulation:
    return Scenario.new(level, [fryer_1]).at(0, 0, INTERACT).at(tick, 0, INTERACT).run_until(tick + 1)


## The whole route: first fry lifted in time, fries taken at once, carried to CUISSON 2 and
## put in at put_in, then lifted after second_fry ticks.
func _second_fry(put_in: int, second_fry: int) -> Simulation:
    var lift := Fryer.FIRST_FRY_MIN
    var scenario := Scenario.new(level, [fryer_1]).at(0, 0, INTERACT).at(lift, 0, INTERACT) \
            .at(lift + 1, 0, INTERACT).at(lift + 2, 0, RIGHT) \
            .at(put_in, 0, INTERACT).at(put_in + second_fry, 0, INTERACT)
    return scenario.run_until(put_in + second_fry + 1)
