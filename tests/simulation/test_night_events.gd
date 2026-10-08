extends GutTest
## A night's events (GDD §6.4): each at its time, announced, changing the rules for a while.

const NEVER := 1 << 30

var level: SimLevel
var fridge: int


func before_each() -> void:
    level = SimLevel.new()
    fridge = level.add_node(Vector3.ZERO, level.add_station(&"frigo"), "K")


## Rules where only the events happen.
func _rules(events: Array) -> SimRules:
    var rules := SimRules.new()
    rules.night_ticks = 4000
    rules.first_arrival = NEVER
    rules.boss_orders = 0
    rules.night_events = events
    return rules


func test_events_follow_the_week() -> void:
    assert_eq(Campaign.events_for(6), [[0.5, NightEvents.PANNE_FRIGO]], "samedi")
    assert_eq(Campaign.events_for(1), [], "lundi: none")
    assert_eq(Campaign.rules_for(13).night_events, Campaign.events_for(13), "samedi of week 2")


func test_the_fridge_breakdown_stops_the_beers_coming_back() -> void:
    var rules := _rules([[0.125, NightEvents.PANNE_FRIGO]])
    rules.fridge_restock = 10
    var scenario := Scenario.new(level, [fridge], 1, rules)
    var sim := scenario.run_until(501)
    var started := scenario.events.filter(func(e: Dictionary) -> bool: return e.type == &"night_event")
    assert_eq(started.size(), 1)
    assert_eq(started[0].tick, 500, "an eighth of the night in")
    # Emptied just as it breaks down.
    sim.stations[0].beers = 0
    var beers := 0
    scenario.run_until(500 + rules.fridge_breakdown)
    assert_eq(sim.stations[0].beers, beers, "none came back while broken")
    scenario.run_until(500 + rules.fridge_breakdown + 20)
    assert_gt(sim.stations[0].beers, beers, "working again")


func test_the_diables_rouges_bring_a_rush_in_a_hurry() -> void:
    var rules := _rules([[0.125, NightEvents.DIABLES_ROUGES]])
    # Plain fries: no bread customer waiting longer.
    rules.menu = [&"frites", Menu.NATURE] as Array[StringName]
    var scenario := Scenario.new(level, [fridge], 1, rules)
    var sim := scenario.run_until(501)
    assert_eq(sim.crowd.line.size(), 1, "the first at once")
    scenario.run_until(501 + rules.rush_every * (rules.rush_customers - 1))
    assert_eq(sim.crowd.line.size(), rules.rush_customers, "all of them, one after the other")
    var first := sim.crowd.line[0]
    assert_eq(first.full_patience, roundi(roundi(rules.patience) * rules.rush_patience), "in a hurry")
    assert_eq(Campaign.events_for(3), [[0.3, NightEvents.DIABLES_ROUGES]], "mercredi")


func test_the_afsca_inspection_wants_no_fire() -> void:
    for fire in [false, true]:
        var rules := _rules([[0.125, NightEvents.AFSCA]])
        var scenario := Scenario.new(level, [fridge], 1, rules)
        var sim := scenario.run_until(501)
        sim.crowd.mood = 500
        sim.stations[0].burning = fire
        rules.fire_spread_after = NEVER
        scenario.run_until(501 + rules.inspection_ticks)
        var over := scenario.events.filter(func(e: Dictionary) -> bool: return e.type == &"inspection_over")
        assert_eq(over.size(), 1)
        assert_eq(over[0].passed, not fire)
        assert_eq(sim.crowd.mood, 500 + (rules.mood_inspection_failed if fire else rules.mood_inspection_passed))


func _till_level() -> SimLevel:
    var till_level := SimLevel.new()
    till_level.add_node(Vector3.ZERO, till_level.add_station(&"caisse"), "C")
    return till_level


func test_the_colleagues_order_for_everyone_and_are_served_in_any_order() -> void:
    var rules := _rules([[0.125, NightEvents.COLLEGUES]])
    var till_level := _till_level()
    var scenario := Scenario.new(till_level, [0], 1, rules)
    var sim := scenario.run_until(501)
    assert_true(sim.crowd.line.is_empty(), "announced first")
    assert_eq(sim.night_events.group_coming, rules.group_warning)
    scenario.run_until(501 + rules.group_warning)
    var leader := sim.crowd.front()
    assert_true(leader.group)
    assert_gte(leader.orders.count(Menu.BEER), rules.group_beers.x, "beers mostly")
    assert_eq(leader.orders.size() - leader.orders.count(Menu.BEER), rules.group_dishes)
    sim.crowd.mood = 500
    # The last line first: any order goes.
    var player := sim.players[0]
    var lines := leader.orders.duplicate()
    lines.reverse()
    for key: StringName in lines:
        player.item = _item_for(key)
        scenario.at(sim.tick, 0, Simulation.Command.INTERACT).at(sim.tick, 0, Simulation.Command.RELEASE)
        scenario.run_until(sim.tick + 1)
        assert_null(player.item, "%s taken" % key)
    assert_true(sim.crowd.line.is_empty(), "all served, they go")
    assert_lt(sim.crowd.mood, 500)
    var left := scenario.events.filter(func(e: Dictionary) -> bool: return e.type == &"group_left")
    assert_true(left[0].served)


func test_while_the_colleagues_come_the_fridge_restocks_twice_as_fast() -> void:
    var rules := _rules([[0.125, NightEvents.COLLEGUES]])
    rules.fridge_restock = 100
    var scenario := Scenario.new(level, [fridge], 1, rules)
    var sim := scenario.run_until(501)
    sim.stations[0].beers = 0
    sim.stations[0].restock = 0
    scenario.run_until(601)
    assert_eq(sim.stations[0].beers, 2, "two in the time of one")


## An item that serves this order line, done right.
func _item_for(key: StringName) -> SimItem:
    var parts := String(key).split(":")
    if parts.size() == 1:
        return SimItem.new(StringName(parts[0]))
    var kind: StringName = ItemIcons.DISHES[StringName(parts[0])]
    var item := SimItem.new(kind)
    if Recipes.is_bread(SimItem.new(kind)) or parts[0] in Menu.BREAD_DISHES:
        item = SimItem.new(Menu.BUN if parts[0] != "mitraillette" else Menu.BAGUETTE)
        item.filling = SimItem.new(Menu.STEAK if parts[0] != "mitraillette" else Menu.FRICADELLE)
        item.veg = parts[0] == "burger_complet"
        if parts[0] == "mitraillette":
            item.fries = SimItem.new(Fryer.FRIES_GOOD)
    if parts[1] != "nature":
        item.sauce = StringName(parts[1])
    return item
