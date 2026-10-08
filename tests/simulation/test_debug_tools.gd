extends GutTest
## The host's test tools (F4, GDD §9.3): commands like any key, so they replay.

const NEVER := 1 << 30
const Tool := Simulation.DebugTool

var level: SimLevel
var extinguisher: int
var fryer: int
var fridge: int
var rules: SimRules


## A row EXTINCTEUR - CUISSON 1 - FRIGO, one unit apart, no customers unless a tool brings them.
func before_each() -> void:
    level = SimLevel.new()
    extinguisher = level.add_node(Vector3(0, 0, 0), level.add_station(&"extincteur"), "X")
    fryer = level.add_node(Vector3(1, 0, 0), level.add_station(&"cuisson_1"), "F")
    fridge = level.add_node(Vector3(2, 0, 0), level.add_station(&"frigo"), "K")
    for pair in [[extinguisher, fryer], [fryer, fridge]]:
        level.link(pair[0], SimLevel.Direction.RIGHT, pair[1])
        level.link(pair[1], SimLevel.Direction.LEFT, pair[0])
    rules = SimRules.new()
    rules.first_arrival = NEVER
    rules.line_pressure_every = NEVER


func test_the_mood_tool_sets_each_level_without_ending_the_night() -> void:
    for mood in SimCrowd.Level.values():
        var sim := _run([fryer], [[0, 0, Simulation.debug_command(Tool.MOOD, mood)]], 2)
        assert_eq(sim.crowd.level(), mood)
        assert_eq(sim.outcome, &"")


func test_the_clock_moves_forward_while_the_steps_go_on() -> void:
    var sim := _run([fryer], [[0, 0, Simulation.debug_command(Tool.CLOCK, Simulation.ClockJump.HALF_HOUR)]], 1)
    assert_eq(sim.clock_minutes(), 30)
    assert_eq(sim.tick, 1, "the replay's ticks are untouched")
    sim = _run([fryer], [[0, 0, Simulation.debug_command(Tool.CLOCK, Simulation.ClockJump.BOSS)]], 2)
    assert_eq(sim.clock_minutes(), 480, "02:00")
    assert_true(sim.crowd.boss_came, "the boss walks in at his time")


func test_closing_time_ends_an_empty_night() -> void:
    var sim := _run([fryer], [[0, 0, Simulation.debug_command(Tool.CLOCK, Simulation.ClockJump.CLOSING)]], 2)
    assert_eq(sim.outcome, &"won")


func test_the_boss_comes_now_and_the_line_fills_up() -> void:
    var sim := _run([fryer], [[0, 0, Simulation.debug_command(Tool.BOSS)],
            [1, 0, Simulation.debug_command(Tool.FILL_LINE)]], 2)
    assert_true(sim.crowd.line[0].boss)
    assert_eq(sim.crowd.line.size(), rules.max_line)


func test_the_fridge_fills_up() -> void:
    var scenario := Scenario.new(level, [fryer], 0, rules)
    var sim := scenario.run_until(1)
    sim.stations[2].beers = 0
    scenario.at(1, 0, Simulation.debug_command(Tool.FRIDGE)).run_until(2)
    assert_eq(sim.stations[2].beers, rules.fridge_beers)


func test_a_fire_starts_where_the_player_stands_or_at_the_first_fryer_and_goes_out() -> void:
    var sim := _run([fridge], [[0, 0, Simulation.debug_command(Tool.FIRE)]], 1)
    assert_true(sim.stations[2].burning, "at the FRIGO, where the player stands")
    sim = _run([extinguisher], [[0, 0, Simulation.debug_command(Tool.FIRE)]], 1)
    assert_false(sim.stations[0].burning, "the extinguisher never burns")
    assert_true(sim.stations[1].burning, "the CUISSON 1 instead")
    sim = _run([extinguisher], [[0, 0, Simulation.debug_command(Tool.FIRE)],
            [1, 0, Simulation.debug_command(Tool.FIRES_OUT)]], 2)
    assert_false(sim.stations.any(func(station: SimStation) -> bool: return station.burning))


func test_players_are_knocked_out_fed_up_and_healed() -> void:
    var sim := _run([fryer, fridge], [[0, 0, Simulation.debug_command(Tool.KNOCK_OUT, 1)],
            [0, 0, Simulation.debug_command(Tool.HUNGRY, 0)]], 1)
    assert_true(sim.players[1].down)
    assert_false(sim.players[0].down)
    assert_eq(sim.players[0].bmi, rules.knockout_bmi + 1)
    sim = _run([fryer, fridge], [[0, 0, Simulation.debug_command(Tool.KNOCK_OUT, 1)],
            [1, 0, Simulation.debug_command(Tool.HEAL)]], 2)
    assert_false(sim.players[1].down)
    assert_eq(sim.players[1].health, SimPlayer.MAX_HEALTH)
    sim = _run([fryer, fridge], [[0, 1, Simulation.debug_command(Tool.FAT, 1)]], 1)
    assert_eq(rules.fat_stage(sim.players[1].bmi), rules.fat_stages.size(), "the heaviest stage")


func test_the_tools_replay_to_the_same_night() -> void:
    rules.first_arrival = 1
    var timeline := [[0, 0, Simulation.debug_command(Tool.FILL_LINE)], [3, 0, Simulation.debug_command(Tool.FIRE)],
            [5, 0, Simulation.debug_command(Tool.MOOD, SimCrowd.Level.CHAUD)]]
    var first := _run([fryer], timeline, 60)
    var again := _run([fryer], timeline, 60)
    assert_eq(again.state_hash(), first.state_hash())
    assert_true(_run([fryer], [], 60).state_hash() != first.state_hash())


func test_the_tools_do_nothing_in_the_lobby() -> void:
    rules.lobby = true
    var sim := _run([fryer], [[0, 0, Simulation.debug_command(Tool.FIRE)],
            [0, 0, Simulation.debug_command(Tool.FILL_LINE)]], 1)
    assert_false(sim.stations[1].burning)
    assert_true(sim.crowd.line.is_empty())


## timeline: [tick, slot, command] entries.
func _run(spawns: Array, timeline: Array, ticks: int) -> Simulation:
    var scenario := Scenario.new(level, PackedInt32Array(spawns), 0, rules)
    for entry: Array in timeline:
        scenario.at(entry[0], entry[1], entry[2])
    return scenario.run_until(ticks)
