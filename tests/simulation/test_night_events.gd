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
    var scenario := Scenario.new(level, [fridge], 1, rules)
    var sim := scenario.run_until(501)
    assert_eq(sim.crowd.line.size(), 1, "the first at once")
    scenario.run_until(501 + rules.rush_every * (rules.rush_customers - 1))
    assert_eq(sim.crowd.line.size(), rules.rush_customers, "all of them, one after the other")
    var first := sim.crowd.line[0]
    assert_eq(first.full_patience, roundi(roundi(rules.patience) * rules.rush_patience), "in a hurry")
    assert_eq(Campaign.events_for(3), [[0.3, NightEvents.DIABLES_ROUGES]], "mercredi")
