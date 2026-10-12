extends GutTest
## Grease on the floor (GDD §8): stepping on it drops what is held and slides on.

const INTERACT := Simulation.Command.INTERACT
const LEFT := Simulation.Command.MOVE_LEFT
const RIGHT := Simulation.Command.MOVE_RIGHT
const NEVER := 1 << 30

var level: SimLevel
var extinguisher: int
var fryer: int
var sauces: int
var fridge: int
var rules: SimRules


## A row EXTINCTEUR - CUISSON 1 - SAUCES - FRIGO, one unit apart, no customers.
func before_each() -> void:
    level = SimLevel.new()
    extinguisher = level.add_node(Vector3(0, 0, 0), level.add_station(&"extincteur"), "X")
    fryer = level.add_node(Vector3(1, 0, 0), level.add_station(&"cuisson_1"), "F")
    sauces = level.add_node(Vector3(2, 0, 0), level.add_station(&"sauces"), "S")
    fridge = level.add_node(Vector3(3, 0, 0), level.add_station(&"frigo"), "K")
    for pair in [[extinguisher, fryer], [fryer, sauces], [sauces, fridge]]:
        level.link(pair[0], SimLevel.Direction.RIGHT, pair[1])
        level.link(pair[1], SimLevel.Direction.LEFT, pair[0])
    rules = SimRules.new()
    rules.first_arrival = NEVER
    rules.night_ticks = NEVER


func test_grease_drops_what_is_held_and_slides_into_the_fryer() -> void:
    var scenario := _scenario([fridge], [sauces])
    var sim := scenario.simulation
    sim.players[0].item = SimItem.new(Menu.COLA)
    var sim_after := scenario.at(0, 0, LEFT).run_until(40)
    assert_null(sim_after.players[0].item, "the cola is lost")
    assert_eq(sim.players[0].node, fryer, "slid one node further")
    assert_eq(sim.players[0].health, SimPlayer.MAX_HEALTH - 1, "the hot oil burns")
    assert_true(scenario.events.any(func(e: Dictionary) -> bool: return e.type == &"slipped"))


func test_a_slide_goes_on_over_more_grease_until_a_wall() -> void:
    var scenario := _scenario([fridge], [sauces, fryer])
    var sim := scenario.at(0, 0, LEFT).run_until(60)
    assert_eq(sim.players[0].node, extinguisher)
    assert_false(sim.players[0].sliding)


func test_grease_against_a_wall_only_stuns() -> void:
    var scenario := _scenario([sauces], [fridge])
    var sim := scenario.at(0, 0, RIGHT).run_until(12)
    assert_eq(sim.players[0].node, fridge)
    assert_gt(sim.players[0].stun, 0)
    assert_eq(sim.players[0].health, SimPlayer.MAX_HEALTH)


func test_sliding_into_a_teammate_bumps_them() -> void:
    var scenario := _scenario([fridge, fryer], [sauces])
    var sim := scenario.at(0, 0, LEFT).run_until(20)
    assert_eq(sim.players[0].node, sauces, "stopped by the teammate")
    assert_eq(sim.players[1].node, fryer)
    assert_true(scenario.events.any(func(e: Dictionary) -> bool: return e.type == &"bump" and e.target == 1))


func test_moves_are_ignored_while_sliding_and_grease_dries() -> void:
    var scenario := _scenario([fridge], [sauces])
    var sim := scenario.at(0, 0, LEFT).run_until(rules.grease_ticks + 1)
    assert_false(sim.grease.has(sauces), "dried")


func test_putting_out_a_fire_leaves_grease() -> void:
    var scenario := _scenario([fryer], [])
    var sim := scenario.simulation
    sim.stations[1].burning = true
    sim.players[0].item = SimItem.new(Simulation.EXTINGUISHER)
    scenario.at(0, 0, INTERACT).run_until(rules.spray_ticks + 2)
    assert_false(sim.stations[1].burning)
    assert_true(sim.grease.has(fryer))


func test_burnt_food_lifted_from_the_oil_leaves_grease() -> void:
    var oil := SimLevel.new()
    var node := oil.add_node(Vector3.ZERO, oil.add_station(&"cuisson_2"), "C")
    var scenario := Scenario.new(oil, PackedInt32Array([node]), 0, rules)
    var sim := scenario.simulation
    var station := sim.stations[0]
    station.basket = SimItem.new(Fryer.FRIES_BLANCHED)
    station.frying = true
    station.cook = Fryer.window(station).y + 1
    scenario.at(0, 0, INTERACT).run_until(1)
    assert_eq(sim.players[0].item.kind, Fryer.FRIES_BURNT)
    assert_true(sim.grease.has(node))


func test_the_debug_tool_spills_grease_where_the_host_stands() -> void:
    var sim := _scenario([sauces], []).at(0, 0, Simulation.debug_command(Simulation.DebugTool.GREASE)).run_until(1)
    assert_true(sim.grease.has(sauces))


## Players at these nodes, grease already on those.
func _scenario(spawns: Array, greasy: Array) -> Scenario:
    var scenario := Scenario.new(level, PackedInt32Array(spawns), 0, rules)
    for node: int in greasy:
        scenario.simulation.grease[node] = rules.grease_ticks
    return scenario
