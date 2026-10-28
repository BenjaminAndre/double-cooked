extends GutTest
## Two CAISSE serve two customers at once (4 players, GDD §6.2): the one closest to the front of
## the line serves the first customer, the other the second.

const INTERACT := Simulation.Command.INTERACT
## Holding a drink, interact starts aiming (any drink can be thrown): a quick release serves.
const RELEASE := Simulation.Command.RELEASE
const NEVER := 1 << 30

var level: SimLevel
var rules: SimRules


## Two registers along the line: the front one at the first place, the other at the second.
func before_each() -> void:
    level = SimLevel.new()
    level.add_node(Vector3(0, 0, 1), level.add_station(&"caisse"), "Front")
    level.add_node(Vector3(-0.45, 0, 1), level.add_station(&"caisse"), "Second")
    rules = SimRules.new()
    rules.first_arrival = NEVER
    rules.line_pressure_every = NEVER
    rules.night_ticks = NEVER


func test_each_register_serves_its_own_customer_at_the_same_time() -> void:
    var scenario := _with_line([&"cola", &"frites:mayo"])
    var sim := scenario.simulation
    assert_eq(sim.register_of(0), 0)
    assert_eq(sim.register_of(1), 1)
    sim.players[0].item = SimItem.new(Menu.COLA)
    var fries := SimItem.new(Fryer.FRIES_GOOD)
    fries.sauce = Menu.MAYO
    sim.players[1].item = fries
    scenario.at(1, 0, INTERACT).at(1, 0, RELEASE).at(1, 1, INTERACT).run_until(2)
    assert_eq(sim.stats.served, 2)
    assert_true(sim.crowd.line.is_empty())


func test_the_second_register_refuses_its_own_customer_only() -> void:
    var scenario := _with_line([&"cola", &"frites:mayo"])
    var sim := scenario.simulation
    var second := sim.crowd.line[1]
    var patience := second.patience
    # Fries without the mayo they ordered.
    sim.players[1].item = SimItem.new(Fryer.FRIES_GOOD)
    scenario.at(1, 1, INTERACT).run_until(2)
    assert_eq(sim.crowd.line.size(), 2, "nobody served")
    assert_lt(second.patience, patience - rules.wrong_delivery + 1)
    assert_eq(sim.players[1].item.kind, Fryer.FRIES_GOOD, "the fries stay in hand")


func test_a_lone_customer_can_be_served_at_either_register() -> void:
    var scenario := _with_line([&"cola"])
    var sim := scenario.simulation
    sim.players[1].item = SimItem.new(Menu.COLA)
    assert_eq(sim.action_for(sim.players[1]), &"serve")
    scenario.at(1, 1, INTERACT).at(1, 1, RELEASE).run_until(2)
    assert_eq(sim.stats.served, 1)


func test_the_customer_at_the_second_register_stays_there_when_the_first_leaves() -> void:
    var scenario := _with_line([&"cola", &"cola", &"cola"])
    var sim := scenario.simulation
    var second := sim.crowd.line[1]
    sim.players[0].item = SimItem.new(Menu.COLA)
    scenario.at(1, 0, INTERACT).at(1, 0, RELEASE).run_until(2)
    assert_eq(sim.crowd.at_register(1), second, "the next in line takes the first register")


## Players at the front and second registers; the line holds these orders at tick 1.
func _with_line(orders: Array) -> Scenario:
    var scenario := Scenario.new(level, PackedInt32Array([0, 1]), 0, rules)
    var sim := scenario.run_until(1)
    for order: StringName in orders:
        var customer := SimCrowd.Customer.new()
        customer.order = order
        customer.patience = rules.patience
        customer.full_patience = rules.patience
        sim.crowd.line.append(customer)
    return scenario
