extends GutTest
## Pigeons (GDD §8): they steal the fries waiting on CUISSON 1, squat stations until shooed,
## and spoil an AFSCA inspection.

const INTERACT := Simulation.Command.INTERACT
const PIGEON := Simulation.DebugTool.PIGEON
const NEVER := 1 << 30

var level: SimLevel
var fryer: int
var sauces: int
var rules: SimRules


## CUISSON 1 - SAUCES, no customers, pigeons only when a test calls one.
func before_each() -> void:
    level = SimLevel.new()
    fryer = level.add_node(Vector3(0, 0, 0), level.add_station(&"cuisson_1"), "F")
    sauces = level.add_node(Vector3(1, 0, 0), level.add_station(&"sauces"), "S")
    level.link(fryer, SimLevel.Direction.RIGHT, sauces)
    level.link(sauces, SimLevel.Direction.LEFT, fryer)
    rules = SimRules.new()
    rules.first_arrival = NEVER
    rules.night_ticks = NEVER


func test_a_pigeon_steals_a_portion_of_the_waiting_fries() -> void:
    var scenario := Scenario.new(level, PackedInt32Array([sauces]), 0, rules)
    var sim := scenario.simulation
    sim.stations[0].basket = SimItem.new(Fryer.FRIES_BLANCHED)
    sim.stations[0].basket.portions = 3
    scenario.at(0, 0, Simulation.debug_command(PIGEON)).run_until(1)
    assert_eq(sim.pigeons[0].station, 0, "straight to the fries")
    scenario.run_until(1 + rules.pigeon_flight + rules.pigeon_peck + 1)
    assert_eq(sim.stations[0].basket.portions, 2)
    assert_true(sim.pigeons.is_empty(), "off with its portion")


func test_a_squatting_pigeon_blocks_the_station_until_shooed() -> void:
    var scenario := Scenario.new(level, PackedInt32Array([sauces]), 0, rules)
    var sim := scenario.simulation
    scenario.at(0, 0, Simulation.debug_command(PIGEON)).run_until(1)
    # Nothing to steal: one of the two stations, from its own stream.
    var at := sim.pigeons[0].station
    sim.players[0].node = fryer if at == 0 else sauces
    scenario.run_until(1 + rules.pigeon_flight + 1)
    assert_eq(sim.action_for(sim.players[0]), &"shoo")
    scenario.run_until(rules.pigeon_flight + 200)
    assert_eq(sim.pigeons.size(), 1, "it stays")
    scenario.at(sim.tick, 0, INTERACT).run_until(sim.tick + 1)
    assert_true(sim.pigeons.is_empty())


func test_pigeons_come_on_their_own_the_same_on_the_same_seed() -> void:
    var times := []
    for run in 2:
        var scenario := Scenario.new(level, PackedInt32Array([sauces]), 7, Campaign.rules_for(PIGEON_NIGHT()))
        scenario.simulation.rules.first_arrival = NEVER
        scenario.run_until(Campaign.PIGEON_EVERY.y * SimRules.SECOND + 1)
        var arrived := scenario.events.filter(func(e: Dictionary) -> bool: return e.type == &"pigeon_arrived")
        assert_false(arrived.is_empty())
        times.append(arrived[0].tick)
    assert_eq(times[0], times[1])
    assert_eq(Campaign.rules_for(1).pigeon_every_min, 0, "none on the first nights")


func test_a_landed_pigeon_fails_an_inspection() -> void:
    var scenario := Scenario.new(level, PackedInt32Array([sauces]), 0, rules)
    var sim := scenario.at(0, 0, Simulation.debug_command(PIGEON)) \
            .at(rules.pigeon_flight + 2, 0, Simulation.debug_command(Simulation.DebugTool.INSPECTION)) \
            .run_until(rules.pigeon_flight + rules.surprise_warning + rules.inspection_ticks + 4)
    assert_eq(sim.outcome_reason, &"afsca")


func test_a_fire_chases_a_pigeon_away() -> void:
    var scenario := Scenario.new(level, PackedInt32Array([sauces]), 0, rules)
    var sim := scenario.at(0, 0, Simulation.debug_command(PIGEON)).run_until(rules.pigeon_flight + 2)
    sim.stations[sim.pigeons[0].station].burning = true
    scenario.run_until(sim.tick + 1)
    assert_true(sim.pigeons.is_empty())


static func PIGEON_NIGHT() -> int:
    return Campaign.PIGEONS_FROM
