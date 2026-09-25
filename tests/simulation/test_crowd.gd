extends GutTest
## The line, orders, patience, the mood and the end of the night (GDD §4, §6).

const INTERACT := Simulation.Command.INTERACT
const NEVER := 1 << 30

var level: SimLevel
var till: int
var rules: SimRules


## A single CAISSE node, and rules that isolate one effect at a time: one customer at tick 1,
## nothing else moving the mood.
func before_each() -> void:
    level = SimLevel.new()
    till = level.add_node(Vector3.ZERO, level.add_station(&"caisse"), "C")
    rules = SimRules.new()
    rules.first_arrival = 1
    rules.arrival_min = NEVER
    rules.arrival_max = NEVER
    rules.line_pressure_every = NEVER
    rules.night_ticks = NEVER


func test_a_customer_arrives_with_one_order() -> void:
    var sim := _scenario().run_until(2)
    assert_eq(sim.crowd.line.size(), 1)
    assert_ne(sim.crowd.front().order, &"")


func test_orders_cover_the_whole_menu() -> void:
    rules.arrival_min = 1
    rules.arrival_max = 1
    rules.max_line = 300
    rules.patience = NEVER
    var seen := {}
    for customer in _scenario().run_until(250).crowd.line:
        seen[customer.order] = true
    for expected in [&"cola", &"biere", &"frites:nature", &"frites:mayo", &"frites:andalouse",
            &"fricadelle:mayo", &"cervelas_froid:nature", &"cervelas_chaud:andalouse"]:
        assert_true(seen.has(expected), "%s shows up" % expected)


func test_the_line_never_grows_past_its_maximum() -> void:
    rules.arrival_min = 1
    rules.arrival_max = 1
    rules.max_line = 3
    assert_eq(_scenario().run_until(20).crowd.line.size(), 3)


func test_the_front_customer_loses_patience_faster() -> void:
    rules.arrival_min = 1
    rules.arrival_max = 1
    rules.calm_arrival_factor = 1.0
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


func test_the_right_order_done_right_sends_the_customer_off_happy() -> void:
    var scenario := _scenario()
    var sim := _with_order(scenario, &"frites:mayo")
    sim.crowd.mood = 500
    sim.players[0].item = _item(Fryer.FRIES_GOOD, Menu.MAYO)
    scenario.at(2, 0, INTERACT).run_until(3)
    assert_null(sim.players[0].item, "handed over")
    assert_true(sim.crowd.line.is_empty())
    assert_eq(sim.crowd.mood, 500 + rules.mood_served)
    assert_eq(sim.stats.served, 1)


func test_anything_badly_done_sends_them_off_angry() -> void:
    for kind in [Fryer.FRIES_SOGGY, Fryer.FRIES_BURNT]:
        var scenario := _scenario()
        var sim := _with_order(scenario, &"frites:mayo")
        sim.players[0].item = _item(kind, Menu.MAYO)
        scenario.at(2, 0, INTERACT).run_until(3)
        assert_null(sim.players[0].item, "serving always hands the item over")
        assert_true(sim.crowd.line.is_empty(), "they leave")
        assert_eq(sim.crowd.mood, rules.mood_angry)
        assert_eq(sim.stats.angry, 1)


func test_the_wrong_order_sends_them_off_angry() -> void:
    for served in [_item(Fryer.FRIES_GOOD, Menu.ANDALOUSE), _item(Fryer.FRIES_GOOD, &""),
            _item(Menu.CERVELAS, Menu.MAYO), _item(Menu.COLA, &"")]:
        var scenario := _scenario()
        var sim := _with_order(scenario, &"frites:mayo")
        sim.players[0].item = served
        scenario.at(2, 0, Simulation.Command.RELEASE)
        scenario.at(2, 0, INTERACT).run_until(3)
        assert_true(sim.crowd.line.is_empty(), "%s isn't frites mayo" % ItemNames.of(served))
        assert_eq(sim.stats.angry, 1)


func test_a_warm_cervelas_isnt_a_cold_one() -> void:
    var scenario := _scenario()
    var sim := _with_order(scenario, &"cervelas_chaud:nature")
    sim.players[0].item = _item(Menu.CERVELAS, &"")
    scenario.at(2, 0, INTERACT).run_until(3)
    assert_eq(sim.stats.angry, 1)


func test_an_unordered_beer_buys_patience_and_the_customer_stays() -> void:
    var scenario := _scenario()
    var sim := _with_order(scenario, &"frites:mayo")
    sim.crowd.front().patience = 100
    sim.players[0].item = _item(Menu.BEER, &"")
    scenario.at(2, 0, INTERACT).at(2, 0, Simulation.Command.RELEASE).run_until(3)
    assert_null(sim.players[0].item)
    assert_eq(sim.crowd.line.size(), 1, "still waiting for their fries")
    assert_eq(sim.crowd.front().patience, 100 + rules.beer_patience - rules.front_drain)
    assert_eq(sim.stats.beers, 1)
    assert_eq(sim.stats.angry, 0)


func test_an_ordered_beer_is_simply_served() -> void:
    var scenario := _scenario()
    var sim := _with_order(scenario, Menu.BEER)
    sim.players[0].item = _item(Menu.BEER, &"")
    scenario.at(2, 0, INTERACT).at(2, 0, Simulation.Command.RELEASE).run_until(3)
    assert_true(sim.crowd.line.is_empty())
    assert_eq(sim.stats.served, 1)


func test_the_night_starts_calm_and_gets_mad_after_one_in_the_morning() -> void:
    rules.night_ticks = 1000
    assert_eq(rules.intensity(0), 0.0)
    assert_eq(rules.intensity(499), 0.0, "calm until 23:00")
    assert_almost_eq(rules.intensity(600), 0.5, 0.01, "halfway at midnight")
    assert_eq(rules.intensity(700), 1.0, "mad from 01:00")
    assert_eq(rules.intensity(999), 1.0)


func test_the_mood_doesnt_move_on_its_own() -> void:
    rules.first_arrival = NEVER
    rules.night_ticks = 1000
    assert_eq(_scenario().run_until(999).crowd.mood, 0, "only what happens in the fritkot moves it")


func test_a_second_unordered_beer_is_one_too_many() -> void:
    var scenario := _scenario()
    var sim := _with_order(scenario, &"frites:mayo")
    sim.players[0].item = _item(Menu.BEER, &"")
    scenario.at(2, 0, INTERACT).at(2, 0, Simulation.Command.RELEASE).run_until(3)
    assert_eq(sim.crowd.line.size(), 1, "the first one is welcome")
    sim.players[0].item = _item(Menu.BEER, &"")
    scenario.at(3, 0, INTERACT).at(3, 0, Simulation.Command.RELEASE).run_until(4)
    assert_true(sim.crowd.line.is_empty(), "the second sends them off")
    assert_eq(sim.stats.angry, 1)


func test_more_players_bring_customers_faster() -> void:
    rules.first_arrival = 0
    rules.arrival_min = 300
    rules.arrival_max = 300
    rules.calm_arrival_factor = 1.0
    var solo := Simulation.new(level, [till], 1, rules)
    var four := Simulation.new(level, [till, till, till, till], 1, rules)
    solo.step([])
    four.step([])
    assert_eq(solo.crowd.next_arrival, 300)
    assert_eq(four.crowd.next_arrival, 120)


func test_arrivals_come_faster_once_the_night_is_mad() -> void:
    rules.night_ticks = 1000
    rules.arrival_min = 100
    rules.arrival_max = 100
    rules.first_arrival = 0
    var calm := Simulation.new(level, [till], 1, rules)
    calm.step([])
    rules.first_arrival = 900
    var mad := Simulation.new(level, [till], 1, rules)
    mad.tick = 900
    mad.step([])
    assert_eq(calm.crowd.next_arrival, roundi(100 * rules.calm_arrival_factor))
    assert_eq(mad.crowd.next_arrival - 900, roundi(100 * rules.mad_arrival_factor))


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
    assert_eq(scenario.events.back(), {"type": &"night_over", "outcome": &"won", "reason": &"closing",
            "tick": 49})


func _scenario() -> Scenario:
    return Scenario.new(level, [till], 7, rules)


## Steps a simulation made outside a Scenario until tick, with no commands.
func _scenario_on(sim: Simulation, tick: int) -> void:
    while sim.tick < tick:
        sim.step([])


func _item(kind: StringName, sauce: StringName) -> SimItem:
    var item := SimItem.new(kind)
    item.sauce = sauce
    return item


## Runs until the first customer is in line, and replaces their order.
func _with_order(scenario: Scenario, order: StringName) -> Simulation:
    var sim := scenario.run_until(2)
    sim.crowd.front().order = order
    return sim
