extends GutTest
## The car crash (GDD §6.4): announced, it wrecks a corner of the kitchen for the night.

const LEFT := Simulation.Command.MOVE_LEFT
const NEVER := 1 << 30

var level: SimLevel
var sauces: int
var meats: int
var fridge: int
var rules: SimRules


## A row SAUCES - VIANDES - FRIGO; the car hits VIANDES.
func before_each() -> void:
    level = SimLevel.new()
    sauces = level.add_node(Vector3(0, 0, 0), level.add_station(&"sauces"), "S")
    meats = level.add_node(Vector3(1, 0, 0), level.add_station(&"viandes"), "V")
    fridge = level.add_node(Vector3(2, 0, 0), level.add_station(&"frigo"), "K")
    for pair in [[sauces, meats], [meats, fridge]]:
        level.link(pair[0], SimLevel.Direction.RIGHT, pair[1])
        level.link(pair[1], SimLevel.Direction.LEFT, pair[0])
    level.crash_nodes = PackedInt32Array([meats])
    rules = Campaign.rules_for(Campaign.CAR_FIRST)
    rules.first_arrival = NEVER
    rules.night_events = []
    rules.pigeon_every_min = 0
    rules.surprise_inspection_chance = 0.0
    rules.line_pressure_every = NEVER


func test_the_car_comes_on_its_nights() -> void:
    assert_true(Campaign.events_for(Campaign.CAR_FIRST).has([Campaign.CAR_AT, NightEvents.CAR_CRASH]))
    assert_true(Campaign.events_for(Campaign.CAR_FIRST + Campaign.CAR_EVERY).has([Campaign.CAR_AT, NightEvents.CAR_CRASH]))
    assert_false(Campaign.events_for(Campaign.CAR_FIRST - 1).has([Campaign.CAR_AT, NightEvents.CAR_CRASH]))
    var events: Array = Campaign.events_for(Campaign.CAR_FIRST)
    for index in events.size() - 1:
        assert_true(events[index][0] <= events[index + 1][0], "in their order")


func test_the_car_knocks_out_whoever_stands_there_and_leaves_rubble() -> void:
    var scenario := _crash([meats, fridge])
    var sim := scenario.simulation
    assert_true(sim.players[0].down)
    assert_ne(sim.players[0].node, meats, "thrown aside")
    assert_false(sim.players[1].down)
    assert_true(sim.stations[1].destroyed)
    # Nobody walks onto the rubble.
    scenario.at(sim.tick, 1, LEFT).run_until(sim.tick + 30)
    assert_eq(sim.players[1].node, fridge)


func test_without_viandes_the_meat_dishes_go_and_their_customers_flee() -> void:
    var scenario := Scenario.new(level, PackedInt32Array([fridge]), 0, rules)
    var sim := scenario.run_until(1)
    for order in [&"fricadelle:mayo", &"frites:nature"]:
        var customer := SimCrowd.Customer.new()
        customer.order = order
        customer.patience = NEVER
        sim.crowd.line.append(customer)
    var mood := sim.crowd.mood
    _crash_now(scenario)
    assert_false(&"fricadelle" in sim.rules.menu)
    assert_eq(sim.crowd.line.size(), 1)
    assert_eq(sim.crowd.line[0].order, &"frites:nature")
    assert_eq(sim.crowd.mood, mood, "too scared to be angry")


func _crash(spawns: Array) -> Scenario:
    var scenario := Scenario.new(level, PackedInt32Array(spawns), 0, rules)
    scenario.run_until(1)
    _crash_now(scenario)
    return scenario


## The car is called (the test tool) and hits after its warning.
func _crash_now(scenario: Scenario) -> void:
    var tick := scenario.simulation.tick
    scenario.at(tick, 0, Simulation.debug_command(Simulation.DebugTool.CAR))
    assert_false(scenario.run_until(tick + rules.car_warning - 2).stations[1].destroyed, "not before the warning ends")
    scenario.run_until(tick + rules.car_warning + 2)
