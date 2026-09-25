extends GutTest
## The line, orders, patience, the mood and the end of the night (GDD §4, §6).

const INTERACT := Simulation.Command.INTERACT
const NEVER := 1 << 30

var level: SimLevel
var till: int
var rules: SimRules


## A single CAISSE node, and rules that isolate one effect at a time: one customer at tick 1,
## one-item orders, no drift.
func before_each() -> void:
    level = SimLevel.new()
    till = level.add_node(Vector3.ZERO, level.add_station(&"caisse"), "C")
    rules = SimRules.new()
    rules.first_arrival = 1
    rules.arrival_min = NEVER
    rules.arrival_max = NEVER
    rules.two_items_chance = 0.0
    rules.drift_every_soiree = NEVER
    rules.drift_every_rush = NEVER
    rules.drift_every_after = NEVER
    rules.line_pressure_every = NEVER
    rules.night_ticks = NEVER


func test_a_customer_arrives_with_an_order() -> void:
    var sim := _scenario().run_until(2)
    assert_eq(sim.crowd.line.size(), 1)
    assert_eq(sim.crowd.front().order, [SimCrowd.FRITES_MAYO] as Array[StringName])


func test_orders_have_one_or_two_items() -> void:
    rules.arrival_min = 1
    rules.arrival_max = 1
    rules.max_line = 50
    rules.two_items_chance = 0.5
    rules.patience = NEVER
    var sizes := {}
    for customer in _scenario().run_until(40).crowd.line:
        sizes[customer.order.size()] = true
    assert_eq(sizes.keys().size(), 2, "both sizes show up")
    assert_true(sizes.has(1) and sizes.has(2))


func test_the_line_never_grows_past_its_maximum() -> void:
    rules.arrival_min = 1
    rules.arrival_max = 1
    rules.max_line = 3
    assert_eq(_scenario().run_until(20).crowd.line.size(), 3)


func test_the_front_customer_loses_patience_faster() -> void:
    rules.arrival_min = 1
    rules.arrival_max = 1
    rules.max_line = 2
    var line := _scenario().run_until(12).crowd.line
    # Arrivals on ticks 1 and 2; the first one has been at the front for 11 ticks.
    assert_eq(line[0].patience, rules.patience - 11 * rules.front_drain)
    assert_eq(line[1].patience, rules.patience - 10 * rules.back_drain)


func test_a_customer_out_of_patience_walks_out_and_the_mood_rises() -> void:
    rules.patience = 10 * rules.front_drain
    var scenario := _scenario()
    var sim := scenario.run_until(12)
    assert_true(sim.crowd.line.is_empty())
    assert_eq(sim.crowd.mood, rules.mood_walk_out)
    assert_true(scenario.events.any(func(e: Dictionary) -> bool: return e.type == &"walk_out"))


func test_serving_good_fries_completes_the_order_and_calms_the_room() -> void:
    var scenario := _scenario()
    var sim := scenario.run_until(2)
    sim.crowd.mood = 500
    sim.players[0].hands[0] = _fries(Fryer.FRIES_GOOD, true)
    scenario.at(2, 0, INTERACT).run_until(3)
    assert_null(sim.players[0].hands[0], "the fries are handed over")
    assert_true(sim.crowd.line.is_empty(), "the customer leaves happy")
    assert_eq(sim.crowd.mood, 500 + rules.mood_good_item)


func test_bad_fries_are_accepted_at_a_mood_penalty() -> void:
    var scenario := _scenario()
    var sim := scenario.run_until(2)
    sim.players[0].hands[0] = _fries(Fryer.FRIES_BURNT, true)
    scenario.at(2, 0, INTERACT).run_until(3)
    assert_true(sim.crowd.line.is_empty())
    assert_eq(sim.crowd.mood, rules.mood_bad_item)


func test_a_two_item_order_is_handed_over_one_item_at_a_time() -> void:
    rules.two_items_chance = 1.0
    var scenario := _scenario()
    var sim := scenario.run_until(2)
    sim.players[0].hands = [_fries(Fryer.FRIES_GOOD, true), _fries(Fryer.FRIES_GOOD, true)]
    scenario.at(2, 0, INTERACT).run_until(3)
    assert_eq(sim.crowd.front().order.size(), 1, "one item ticked off")
    scenario.at(3, 0, Simulation.Command.FOCUS_RIGHT).at(3, 0, INTERACT).run_until(4)
    assert_true(sim.crowd.line.is_empty())


func test_fries_without_sauce_are_not_what_was_ordered() -> void:
    var scenario := _scenario()
    var sim := scenario.run_until(2)
    sim.players[0].hands[0] = _fries(Fryer.FRIES_GOOD, false)
    scenario.at(2, 0, INTERACT).run_until(3)
    assert_not_null(sim.players[0].hands[0], "the player keeps them")
    assert_eq(sim.crowd.line.size(), 1)


func test_the_mood_drifts_up_faster_as_the_night_goes_on() -> void:
    rules.first_arrival = NEVER
    rules.night_ticks = 1000
    rules.drift_every_soiree = 10
    rules.drift_every_rush = 5
    rules.drift_every_after = 2
    var sim := _scenario().run_until(999)
    # Soirée ticks 1-399: 39, Rush 400-699: 60, After 700-998: 150.
    assert_eq(sim.crowd.mood, 39 + 60 + 150)


func test_more_players_bring_customers_faster() -> void:
    rules.first_arrival = 0
    rules.arrival_min = 300
    rules.arrival_max = 300
    var solo := Simulation.new(level, [till], 1, rules)
    var four := Simulation.new(level, [till, till, till, till], 1, rules)
    solo.step([])
    four.step([])
    assert_eq(solo.crowd.next_arrival, 300)
    assert_eq(four.crowd.next_arrival, 120)


func test_a_riot_loses_the_night_and_freezes_it() -> void:
    var scenario := _scenario()
    var sim := scenario.run_until(1)
    sim.crowd.mood = rules.riot - 1
    sim.crowd.change_mood(1)
    scenario.run_until(3)
    assert_eq(sim.outcome, &"lost")
    var frozen := sim.state_hash()
    scenario.run_until(10)
    assert_eq(sim.crowd.mood, rules.riot, "nothing moves once the night is over")
    assert_eq(sim.tick, 10)
    assert_ne(frozen, 0)


func test_reaching_closing_time_wins_the_night() -> void:
    rules.night_ticks = 50
    var scenario := _scenario()
    var sim := scenario.run_until(49)
    assert_eq(sim.outcome, &"")
    assert_eq(sim.clock_minutes(), 49 * 600 / 50)
    scenario.run_until(50)
    assert_eq(sim.outcome, &"won")
    assert_eq(sim.clock_minutes(), 600, "04:00")
    assert_eq(scenario.events.back(), {"type": &"night_over", "outcome": &"won", "tick": 49})


func _scenario() -> Scenario:
    return Scenario.new(level, [till], 7, rules)


func _fries(kind: StringName, sauce: bool) -> SimItem:
    var item := SimItem.new(kind)
    item.sauce = sauce
    return item
