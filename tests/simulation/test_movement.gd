extends GutTest
## Walking on the node graph, occupancy and bumps (GDD §5.2, §5.3).

const RIGHT := Simulation.Command.MOVE_RIGHT
const LEFT := Simulation.Command.MOVE_LEFT
## One unit between nodes: 3 ticks per edge at WALK_SPEED 10 and TICK_RATE 30.
const EDGE_TICKS := 3

var level: SimLevel
var a: int
var b: int
var c: int
var d: int


## A straight corridor A - B - C - D, one unit apart, with SOINS at D.
func before_each() -> void:
    level = SimLevel.new()
    a = level.add_node(Vector3(0, 0, 0), SimLevel.NONE, "A")
    b = level.add_node(Vector3(1, 0, 0), SimLevel.NONE, "B")
    c = level.add_node(Vector3(2, 0, 0), SimLevel.NONE, "C")
    d = level.add_node(Vector3(3, 0, 0), level.add_station(&"soins"), "D")
    for pair in [[a, b], [b, c], [c, d]]:
        level.link(pair[0], SimLevel.Direction.RIGHT, pair[1])
        level.link(pair[1], SimLevel.Direction.LEFT, pair[0])


func test_walks_to_a_neighbour() -> void:
    var scenario := Scenario.new(level, [a]).at(0, 0, RIGHT)
    var player := scenario.run_until(1).players[0]
    assert_true(player.is_moving(), "sets off on the tick of the key press")
    assert_eq(player.occupied_node(), b, "claims the node it walks to")
    scenario.run_until(1 + EDGE_TICKS)
    assert_eq(player.node, b)
    assert_false(player.is_moving())


func test_queued_moves_are_walked_in_a_row() -> void:
    var player := Scenario.new(level, [a]).at(0, 0, RIGHT).at(0, 0, RIGHT).at(0, 0, RIGHT) \
            .run_until(1 + 3 * EDGE_TICKS).players[0]
    assert_eq(player.node, d)
    assert_true(player.path.is_empty())


func test_heading_back_cuts_the_loop() -> void:
    var player := Scenario.new(level, [a]).at(0, 0, RIGHT).at(0, 0, RIGHT).at(0, 0, LEFT) \
            .run_until(1).players[0]
    assert_eq(player.path, [b] as Array[int], "C is dropped instead of walking B - C - B")


func test_a_missing_neighbour_is_ignored() -> void:
    var player := Scenario.new(level, [a]).at(0, 0, LEFT).run_until(1).players[0]
    assert_false(player.is_moving())
    assert_eq(player.node, a)


func test_walking_into_a_player_bumps_them_and_stops() -> void:
    var scenario := Scenario.new(level, [a, b]).at(0, 0, RIGHT).at(0, 0, RIGHT)
    var sim := scenario.run_until(1)
    assert_eq(sim.players[0].node, a)
    assert_false(sim.players[0].is_moving())
    assert_true(sim.players[0].path.is_empty(), "the whole planned path is dropped")
    assert_eq(sim.players[1].node, b, "the bumped player stays put")
    assert_eq(scenario.events, [{"type": &"bump", "by": 0, "target": 1, "tick": 0}] as Array[Dictionary])


func test_simultaneous_entry_goes_to_the_lower_slot() -> void:
    var scenario := Scenario.new(level, [a, c]).at(0, 0, RIGHT).at(0, 1, LEFT)
    var sim := scenario.run_until(1)
    assert_eq(sim.players[0].occupied_node(), b, "slot 0 gets the node")
    assert_eq(sim.players[1].node, c)
    assert_false(sim.players[1].is_moving())
    assert_eq(scenario.events, [{"type": &"bump", "by": 1, "target": 0, "tick": 0}] as Array[Dictionary])


func test_a_node_is_free_once_its_occupant_sets_off() -> void:
    var scenario := Scenario.new(level, [a, b]).at(0, 1, RIGHT).at(1, 0, RIGHT)
    var sim := scenario.run_until(2)
    assert_eq(sim.players[0].occupied_node(), b)
    assert_eq(sim.players[1].occupied_node(), c)
    assert_true(scenario.events.is_empty())


func test_swapping_places_bumps_both() -> void:
    var scenario := Scenario.new(level, [a, b]).at(0, 0, RIGHT).at(0, 1, LEFT)
    var sim := scenario.run_until(1)
    assert_eq(sim.players[0].node, a)
    assert_eq(sim.players[1].node, b)
    assert_eq(scenario.events.size(), 2)


func test_interacting_at_soins_restores_hearts() -> void:
    var damage := Simulation.Command.DEBUG_DAMAGE
    var scenario := Scenario.new(level, [d]).at(0, 0, damage).at(0, 0, damage)
    var player := scenario.run_until(1).players[0]
    assert_eq(player.health, SimPlayer.MAX_HEALTH - 2)
    scenario.at(1, 0, Simulation.Command.INTERACT).run_until(2)
    assert_eq(player.health, SimPlayer.MAX_HEALTH)


func test_interacting_elsewhere_does_nothing() -> void:
    var scenario := Scenario.new(level, [a]).at(0, 0, Simulation.Command.DEBUG_DAMAGE) \
            .at(1, 0, Simulation.Command.INTERACT)
    assert_eq(scenario.run_until(2).players[0].health, SimPlayer.MAX_HEALTH - 1)


func test_health_never_goes_below_zero() -> void:
    var scenario := Scenario.new(level, [a])
    for i in SimPlayer.MAX_HEALTH + 2:
        scenario.at(0, 0, Simulation.Command.DEBUG_DAMAGE)
    assert_eq(scenario.run_until(1).players[0].health, 0)


func test_focus_switches_hands() -> void:
    var scenario := Scenario.new(level, [a]).at(0, 0, Simulation.Command.FOCUS_RIGHT)
    var player := scenario.run_until(1).players[0]
    assert_eq(player.focus, SimPlayer.Hand.RIGHT)
    scenario.at(1, 0, Simulation.Command.FOCUS_LEFT).run_until(2)
    assert_eq(player.focus, SimPlayer.Hand.LEFT)


func test_same_inputs_give_the_same_night() -> void:
    var hashes := []
    for run in 2:
        var scenario := Scenario.new(level, [a, d], 1234)
        for tick in 60:
            scenario.at(tick, tick % 2, RIGHT if tick % 3 else LEFT)
        hashes.append(scenario.run_until(60).state_hash())
    assert_eq(hashes[0], hashes[1])
