extends GutTest
## The yellow BB gun under the CAISSE (GDD §8): it shoots pigeons, the AFSCA inspector and
## teammates, never customers.

const INTERACT := Simulation.Command.INTERACT
const RELEASE := Simulation.Command.RELEASE
const RIGHT := Simulation.Command.MOVE_RIGHT
const NEVER := 1 << 30

var level: SimLevel
var till: int
var fryer: int
var rules: SimRules


## CAISSE - CUISSON 1, no customers.
func before_each() -> void:
    level = SimLevel.new()
    till = level.add_node(Vector3(0, 0, 0), level.add_station(&"caisse"), "C")
    fryer = level.add_node(Vector3(1, 0, 0), level.add_station(&"cuisson_1"), "F")
    level.link(till, SimLevel.Direction.RIGHT, fryer)
    level.link(fryer, SimLevel.Direction.LEFT, till)
    rules = SimRules.new()
    rules.first_arrival = NEVER
    rules.night_ticks = NEVER


func test_the_gun_is_taken_and_put_back_at_the_caisse() -> void:
    var scenario := Scenario.new(level, PackedInt32Array([till]), 0, rules)
    var sim := scenario.simulation
    assert_eq(sim.action_for(sim.players[0]), &"take_gun")
    scenario.at(0, 0, INTERACT).run_until(1)
    assert_eq(sim.players[0].item.kind, Simulation.GUN)
    assert_false(sim.stations[0].gun)
    # A quick tap puts it back.
    scenario.at(1, 0, INTERACT).at(2, 0, RELEASE).run_until(3)
    assert_null(sim.players[0].item)
    assert_true(sim.stations[0].gun)


func test_a_shot_pigeon_flies_off() -> void:
    var scenario := _armed([till])
    var sim := scenario.simulation
    scenario.at(1, 0, Simulation.debug_command(Simulation.DebugTool.PIGEON)).run_until(rules.pigeon_flight + 3)
    assert_eq(sim.gun_targets(sim.players[0]), [[&"pigeon", 0]])
    _shoot(scenario)
    assert_true(sim.pigeons.is_empty())


func test_shooting_the_inspector_ends_the_inspection_without_a_verdict() -> void:
    var scenario := _armed([till])
    var sim := scenario.simulation
    sim.grease[fryer] = NEVER
    scenario.at(1, 0, Simulation.debug_command(Simulation.DebugTool.INSPECTION)).run_until(rules.surprise_warning + 3)
    assert_eq(sim.gun_targets(sim.players[0]), [[&"inspector", 0]])
    var mood := sim.crowd.mood
    _shoot(scenario)
    assert_eq(sim.night_events.inspection, 0)
    scenario.run_until(sim.tick + rules.inspection_ticks)
    assert_eq(sim.outcome, &"", "the dirty kitchen stays open")
    assert_eq(sim.crowd.mood, mood + rules.mood_inspector_shot, "but the room saw it")


func test_a_shot_teammate_loses_a_heart_and_is_stunned() -> void:
    var scenario := _armed([till, fryer])
    var sim := scenario.simulation
    assert_eq(sim.gun_targets(sim.players[0]), [[&"mate", 1]], "never the customers")
    _shoot(scenario)
    assert_eq(sim.players[1].health, SimPlayer.MAX_HEALTH - 1)
    assert_gt(sim.players[1].stun, 0)


func test_left_and_right_pick_the_target() -> void:
    var scenario := _armed([till, fryer])
    var sim := scenario.simulation
    scenario.at(1, 0, Simulation.debug_command(Simulation.DebugTool.PIGEON)).run_until(rules.pigeon_flight + 3)
    var targets := sim.gun_targets(sim.players[0])
    assert_eq(targets.size(), 2)
    var tick := sim.tick
    scenario.at(tick, 0, INTERACT).at(tick + 1, 0, RIGHT).run_until(tick + 2)
    assert_eq(targets[sim.players[0].aim], [&"mate", 1])


func test_a_slip_sends_the_gun_back_under_the_caisse() -> void:
    var scenario := _armed([till])
    var sim := scenario.simulation
    sim.grease[fryer] = NEVER
    scenario.at(1, 0, RIGHT).run_until(30)
    assert_null(sim.players[0].item)
    assert_true(sim.stations[0].gun)


## Players at these nodes, the first holding the gun from the CAISSE (tick 0).
func _armed(spawns: Array) -> Scenario:
    var scenario := Scenario.new(level, PackedInt32Array(spawns), 0, rules)
    scenario.at(0, 0, INTERACT).run_until(1)
    return scenario


## Holds the trigger long enough, on the current target, then lets go.
func _shoot(scenario: Scenario) -> void:
    var tick := scenario.simulation.tick
    scenario.at(tick, 0, INTERACT).at(tick + rules.aim_hold + 1, 0, RELEASE).run_until(tick + rules.aim_hold + 2)
