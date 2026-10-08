extends GutTest
## The campaign (GDD §4.2): a menu that grows night after night, busier nights, stations with
## nothing to do greyed out and inert, and each player's own stats for the summary.

const INTERACT := Simulation.Command.INTERACT
const NEVER := 1 << 30

var level: SimLevel
var till: int
var fridge: int
var meats: int
var bread: int


## A row CAISSE - FRIGO - VIANDES - PAIN, one unit apart.
func before_each() -> void:
    level = SimLevel.new()
    till = level.add_node(Vector3(0, 0, 0), level.add_station(&"caisse"), "C")
    fridge = level.add_node(Vector3(1, 0, 0), level.add_station(&"frigo"), "K")
    meats = level.add_node(Vector3(2, 0, 0), level.add_station(&"viandes"), "V")
    bread = level.add_node(Vector3(3, 0, 0), level.add_station(&"pain"), "P")
    var row := [till, fridge, meats, bread]
    for index in row.size() - 1:
        level.link(row[index], SimLevel.Direction.RIGHT, row[index + 1])
        level.link(row[index + 1], SimLevel.Direction.LEFT, row[index])


func test_the_menu_grows_night_after_night() -> void:
    assert_eq(Campaign.menu_for(1), [&"frites", Menu.NATURE, Menu.BEER] as Array[StringName])
    assert_false(Menu.COLA in Campaign.menu_for(1))
    assert_true(Menu.MAYO in Campaign.menu_for(2))
    assert_true(Menu.COLA in Campaign.menu_for(2))
    assert_eq(Campaign.new_on(1), [] as Array[StringName], "nothing is new on the first night")
    assert_eq(Campaign.new_on(3), [&"cervelas_froid"] as Array[StringName])
    var everything := Campaign.menu_for(Campaign.UNLOCKS.size() + 5)
    for entry in Menu.FULL_MENU:
        assert_true(entry in everything, "%s is unlocked in the end" % entry)


func test_a_single_night_has_the_whole_menu_at_the_base_pace() -> void:
    var rules := Campaign.rules_for(0)
    assert_eq(rules.night_number, 0)
    assert_eq(rules.menu, Menu.FULL_MENU)


func test_the_first_night_only_orders_plain_fries_and_beer() -> void:
    var rules := _busy(Campaign.rules_for(1))
    var sim := Scenario.new(level, [till], 3, rules).run_until(200)
    assert_gt(sim.crowd.line.size(), 50)
    var seen := {}
    for customer in sim.crowd.line:
        seen[customer.order] = true
    assert_eq(seen.size(), 2)
    assert_true(seen.has(&"frites:nature"))
    assert_true(seen.has(Menu.BEER))


func test_each_night_brings_customers_faster() -> void:
    var first := Campaign.rules_for(1)
    var later := Campaign.rules_for(11)
    for rules in [first, later]:
        rules.first_arrival = 0
        rules.arrival_min = 300
        rules.arrival_max = 300
        rules.calm_arrival_factor = 1.0
    var sims: Array[Simulation] = [Simulation.new(level, [till], 1, first), Simulation.new(level, [till], 1, later)]
    for sim in sims:
        sim.step([])
    assert_eq(sims[0].crowd.next_arrival, 300)
    # Ten nights later: 1 + 0.05 × 10 times faster.
    assert_eq(sims[1].crowd.next_arrival, 200)


func test_stations_only_offer_what_tonight_needs() -> void:
    assert_eq(Menu.options(&"viandes", Campaign.menu_for(3)), [Menu.CERVELAS])
    assert_eq(Menu.options(&"viandes", Campaign.menu_for(4)), [Menu.CERVELAS, Menu.FRICADELLE_RAW])
    assert_eq(Menu.options(&"sauces", Campaign.menu_for(2)), [Menu.MAYO, Menu.ANDALOUSE])
    assert_eq(Menu.options(&"frigo", Campaign.menu_for(1)), [Menu.BEER], "a beer to crawl to from the start")
    assert_eq(Menu.options(&"frigo", Campaign.menu_for(2)), [Menu.COLA, Menu.BEER])
    assert_false(Menu.station_in_use(&"pain", Campaign.menu_for(8)), "no bread before the second week")
    assert_true(Menu.station_in_use(&"caisse", Campaign.menu_for(1)))


func test_a_station_with_nothing_to_do_tonight_is_inert() -> void:
    var rules := Campaign.rules_for(1)
    var sim := Scenario.new(level, [meats, bread], 1, rules).simulation
    for player in sim.players:
        assert_eq(sim.action_for(player), &"", "nothing at %s on the first night" % sim.stations[
                sim.level.node_stations[player.node]].kind)
    sim = Scenario.new(level, [fridge, meats], 1, Campaign.rules_for(3)).simulation
    assert_eq(sim.action_for(sim.players[0]), &"fridge")
    assert_eq(sim.action_for(sim.players[1]), &"meat")


func test_the_viandes_menu_only_holds_tonights_meats() -> void:
    var rules := Campaign.rules_for(3)
    var scenario := Scenario.new(level, [meats], 1, rules)
    # Right goes nowhere: the cervelas is the only meat tonight.
    var sim := scenario.at(0, 0, INTERACT).at(1, 0, Simulation.Command.MOVE_RIGHT).at(2, 0, INTERACT).run_until(3)
    assert_eq(sim.players[0].item.kind, Menu.CERVELAS)


func test_each_player_has_their_own_stats() -> void:
    var rules := SimRules.new()
    rules.first_arrival = 1
    rules.arrival_min = NEVER
    rules.arrival_max = NEVER
    rules.line_pressure_every = NEVER
    rules.boss_orders = 0
    var scenario := Scenario.new(level, [fridge, till], 7, rules)
    var sim := scenario.run_until(2)
    sim.crowd.front().order = &"cola"
    sim.players[1].item = SimItem.new(Menu.COLA)
    scenario.at(2, 1, INTERACT).run_until(3)
    assert_eq(sim.stats.served_by, [0, 1])
    assert_eq(sim.stats.missed_by, [0, 0])
    var slot := sim.add_player(bread, -1, -1)
    assert_eq(sim.stats.beers_by.size(), 3, "a player joining late has stats too")
    assert_eq(sim.stats.served_by[slot], 0)


## Rules where customers keep coming, one per tick, and never leave.
func _busy(rules: SimRules) -> SimRules:
    rules.first_arrival = 1
    rules.arrival_min = 1
    rules.arrival_max = 1
    rules.max_line = 300
    rules.patience = NEVER
    rules.boss_orders = 0
    return rules


func test_a_knocked_out_player_can_drink_a_beer_from_the_first_night() -> void:
    var scenario := Scenario.new(level, [fridge], 1, Campaign.rules_for(1))
    var player := scenario.simulation.players[0]
    player.health = 0
    player.down = true
    scenario.at(0, 0, INTERACT).at(1, 0, INTERACT).run_until(2)
    assert_eq(player.item.kind, Menu.BEER, "the FRIGO's only option tonight")


func test_a_menu_with_nothing_in_it_never_opens() -> void:
    var rules := Campaign.rules_for(1)
    rules.menu.erase(Menu.BEER)
    var scenario := Scenario.new(level, [fridge], 1, rules)
    var player := scenario.simulation.players[0]
    player.health = 0
    player.down = true
    assert_eq(scenario.simulation.action_for(player), &"")
    scenario.at(0, 0, INTERACT).run_until(1)
    assert_eq(player.menu, SimLevel.NONE)


func test_each_night_is_a_day_of_the_week() -> void:
    assert_eq(Campaign.day_label(1), "lundi")
    assert_eq(Campaign.day_label(7), "dimanche")
    assert_eq(Campaign.day_label(8), "lundi, semaine 2")
    assert_eq(Campaign.day_label(16), "mardi, semaine 3")


func test_sundays_take_turns_and_later_weeks_have_one_more_event() -> void:
    assert_eq(Campaign.events_for(7), [[0.3, Campaign.ROTATION[0]]], "first Sunday")
    assert_eq(Campaign.events_for(14)[0], [0.3, Campaign.ROTATION[1]], "second Sunday")
    assert_eq(Campaign.events_for(8).size(), 1, "Monday of week 2: one extra")
    for night in range(8, 30):
        var events := Campaign.events_for(night)
        if events.size() == 2:
            assert_ne(events[0][1], events[1][1], "never twice the same in a night")
            assert_lt(events[0][0], events[1][0], "in their order")
