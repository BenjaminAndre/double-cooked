extends GutTest
## The boss (GDD §6.3): he cuts in, orders several dishes in a row, wants a drink on the side,
## and throws cans.

const INTERACT := Simulation.Command.INTERACT
const RELEASE := Simulation.Command.RELEASE
const NEVER := 1 << 30
const ARRIVAL := 100

var level: SimLevel
var till: int
var rules: SimRules


## A single CAISSE node, one customer at tick 1 and the boss at ARRIVAL.
func before_each() -> void:
    level = SimLevel.new()
    till = level.add_node(Vector3.ZERO, level.add_station(&"caisse"), "C")
    rules = SimRules.new()
    rules.first_arrival = 1
    rules.arrival_min = NEVER
    rules.arrival_max = NEVER
    rules.line_pressure_every = NEVER
    rules.night_ticks = 1000
    rules.boss_at = float(ARRIVAL) / rules.night_ticks


func test_the_boss_cuts_in_front_of_a_customer_being_served() -> void:
    var scenario := Scenario.new(level, [till], 3, rules)
    var sim := scenario.run_until(ARRIVAL + 1)
    assert_eq(sim.crowd.line.size(), 2)
    assert_true(sim.crowd.front().boss)
    assert_false(sim.crowd.line[1].boss, "the customer at the counter goes back one place")
    assert_eq(sim.crowd.front().orders.size(), rules.boss_orders)
    for order in sim.crowd.front().orders:
        assert_false(order in Menu.DRINKS, "his drinks go on the side")
    assert_true(sim.stats.boss_came)


func test_his_orders_come_one_after_the_other_and_a_miss_is_a_salvo() -> void:
    var scenario := Scenario.new(level, [till], 3, rules)
    var sim := scenario.run_until(ARRIVAL + 1)
    var boss := _set_orders(sim, [&"frites:mayo", &"frites:andalouse", &"cervelas_froid:nature"])
    _serve(scenario, sim, _item(Fryer.FRIES_GOOD, Menu.MAYO))
    assert_eq(Array(boss.results), [SimCrowd.Result.SERVED, SimCrowd.Result.WAITING, SimCrowd.Result.WAITING])
    assert_eq(boss.order, &"frites:andalouse")
    var mood := sim.crowd.mood
    _serve(scenario, sim, _item(Fryer.FRIES_GOOD, Menu.MAYO))
    assert_eq(boss.results[1], SimCrowd.Result.MISSED, "the wrong sauce")
    assert_eq(sim.crowd.mood, mood + rules.mood_boss_miss)
    assert_eq(sim.projectiles.size(), rules.boss_cans)
    assert_true(sim.crowd.front().boss, "he stays for his last order")
    _serve(scenario, sim, _item(Menu.CERVELAS, &""))
    assert_false(sim.crowd.front().boss, "he leaves after his last order")
    assert_eq(sim.stats.boss_served, 2)
    assert_true(scenario.events.any(func(e: Dictionary) -> bool:
            return e.type == &"boss_left" and e.served == 2))


func test_all_his_orders_served_right_cheer_the_room_up() -> void:
    var scenario := Scenario.new(level, [till], 3, rules)
    var sim := scenario.run_until(ARRIVAL + 1)
    _set_orders(sim, [&"frites:mayo", &"frites:mayo", &"frites:mayo"])
    sim.crowd.mood = 500
    for order in 3:
        _serve(scenario, sim, _item(Fryer.FRIES_GOOD, Menu.MAYO))
    assert_eq(sim.crowd.mood, 500 + 3 * rules.mood_served + rules.mood_boss_served)


func test_running_out_of_patience_misses_his_order() -> void:
    var scenario := Scenario.new(level, [till], 3, rules)
    var sim := scenario.run_until(ARRIVAL + 1)
    var boss := sim.crowd.front()
    boss.patience = 1
    scenario.run_until(sim.tick + 1)
    assert_eq(boss.results[0], SimCrowd.Result.MISSED)
    assert_eq(boss.patience, sim.crowd.boss_patience(), "a fresh patience for the next one")
    assert_eq(sim.projectiles.size(), rules.boss_cans)


func test_his_drink_is_served_at_the_counter_or_thrown() -> void:
    var scenario := Scenario.new(level, [till], 3, rules)
    var sim := scenario.run_until(ARRIVAL + rules.boss_drink_again + 1)
    var boss := sim.crowd.front()
    assert_ne(boss.drink, &"", "he orders a drink while he waits")
    boss.drink = Menu.COLA
    _serve(scenario, sim, SimItem.new(Menu.COLA))
    assert_eq(boss.drink, &"")
    assert_eq(boss.results[0], SimCrowd.Result.WAITING, "a drink isn't his order")
    boss.drink = Menu.BEER
    var events: Array[Dictionary] = []
    sim.crowd.give_beer(0, 0, events)
    assert_eq(boss.drink, &"", "a thrown beer counts")
    assert_eq(events[0].type, &"boss_drank")


func test_a_drink_left_waiting_or_the_wrong_one_costs_patience() -> void:
    var scenario := Scenario.new(level, [till], 3, rules)
    var sim := scenario.run_until(ARRIVAL + rules.boss_drink_again + 1)
    var boss := sim.crowd.front()
    boss.drink = Menu.COLA
    var before := boss.patience
    _serve(scenario, sim, SimItem.new(Menu.BEER))
    assert_lt(boss.patience, before - rules.boss_drink_penalty + rules.front_drain)
    assert_eq(boss.drink, &"")
    boss.drink = Menu.COLA
    boss.drink_patience = 1
    before = boss.patience
    scenario.run_until(sim.tick + 1)
    assert_eq(boss.drink, &"")
    assert_eq(boss.patience, before - rules.front_drain - rules.boss_drink_penalty)


func test_while_he_waits_he_throws_cans_at_random() -> void:
    var scenario := Scenario.new(level, [till], 3, rules)
    var sim := scenario.run_until(ARRIVAL + 1)
    assert_eq(sim.projectiles.size(), 0)
    scenario.run_until(ARRIVAL + rules.boss_can_every + 1)
    assert_eq(sim.projectiles.size(), 1)


func test_no_boss_without_orders() -> void:
    rules.boss_orders = 0
    var sim := Scenario.new(level, [till], 3, rules).run_until(ARRIVAL + 1)
    assert_false(sim.crowd.front().boss)
    assert_false(sim.stats.boss_came)


func _set_orders(sim: Simulation, orders: Array[StringName]) -> SimCrowd.Customer:
    var boss := sim.crowd.front()
    boss.orders = orders
    boss.order = orders[0]
    return boss


## Hands item over at the counter on the next tick.
func _serve(scenario: Scenario, sim: Simulation, item: SimItem) -> void:
    sim.players[0].item = item
    scenario.at(sim.tick, 0, INTERACT).at(sim.tick, 0, RELEASE).run_until(sim.tick + 1)


func _item(kind: StringName, sauce: StringName) -> SimItem:
    var item := SimItem.new(kind)
    item.sauce = sauce
    return item
