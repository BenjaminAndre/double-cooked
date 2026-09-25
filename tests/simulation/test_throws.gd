extends GutTest
## Throwing beers to the line, and angry customers throwing cans back (GDD §8).

const C := Simulation.Command
const NEVER := 1 << 30

var level: SimLevel
var spot: int
var side: int
var rules: SimRules


## Two plain nodes in the kitchen, and a line of customers two units away. No drift, no
## random cans unless a test asks for them.
func before_each() -> void:
    level = SimLevel.new()
    spot = level.add_node(Vector3(0, 0, 0), SimLevel.NONE, "P")
    side = level.add_node(Vector3(2, 0, 0), SimLevel.NONE, "S")
    level.link(spot, SimLevel.Direction.RIGHT, side)
    level.link(side, SimLevel.Direction.LEFT, spot)
    level.queue_front = Vector3(0, 0, -2)
    level.queue_step = Vector3(-0.5, 0, 0)
    rules = SimRules.new()
    rules.first_arrival = 0
    rules.arrival_min = 1
    rules.arrival_max = 1
    rules.calm_arrival_factor = 1.0
    rules.max_line = 3
    rules.night_ticks = NEVER
    rules.calm_drift_every = NEVER
    rules.mad_drift_every = NEVER
    rules.line_pressure_every = NEVER


func test_holding_a_beer_aims_and_releasing_throws_it_to_that_customer() -> void:
    var scenario := _with_line(["frites:mayo", "cola", "fricadelle:nature"])
    var sim := scenario.simulation
    var player := sim.players[0]
    player.item = SimItem.new(Menu.BEER)
    sim.crowd.line[1].patience = 100
    var start := sim.tick
    scenario.at(start, 0, C.INTERACT).at(start + 1, 0, C.MOVE_RIGHT)
    scenario.run_until(start + 2)
    assert_eq(player.aim, 1, "the arrows pick the second customer")
    assert_eq(player.node, spot, "and don't move the player")
    var release := start + rules.aim_hold + 1
    scenario.at(release, 0, C.RELEASE).run_until(release + 1)
    assert_null(player.item, "thrown")
    assert_eq(sim.projectiles.size(), 1)
    scenario.run_until(release + rules.beer_flight + 1)
    assert_true(sim.projectiles.is_empty())
    assert_gt(sim.crowd.line[1].patience, 100, "caught: they're glad of a beer they didn't order")
    assert_eq(sim.stats.beers, 1)


func test_a_customer_who_ordered_a_beer_is_served_by_a_thrown_one() -> void:
    var scenario := _with_line(["frites:mayo", "biere"])
    var sim := scenario.simulation
    sim.players[0].item = SimItem.new(Menu.BEER)
    var start := sim.tick
    scenario.at(start, 0, C.INTERACT).at(start, 0, C.MOVE_RIGHT) \
            .at(start + rules.aim_hold + 1, 0, C.RELEASE)
    scenario.run_until(start + rules.aim_hold + rules.beer_flight + 3)
    assert_eq(sim.stats.served, 1)
    assert_eq(sim.crowd.line.size(), 1, "the beer drinker left happy")


func test_a_quick_tap_with_a_beer_still_uses_the_station() -> void:
    var till := level.add_station(&"poubelle")
    level.node_stations[spot] = till
    var scenario := _with_line([])
    var player := scenario.simulation.players[0]
    player.item = SimItem.new(Menu.BEER)
    var start := scenario.simulation.tick
    scenario.at(start, 0, C.INTERACT).at(start + 2, 0, C.RELEASE).run_until(start + 3)
    assert_null(player.item, "binned, not thrown")
    assert_true(scenario.simulation.projectiles.is_empty())


func test_a_beer_that_lands_where_nobody_stands_is_lost() -> void:
    var scenario := _with_line(["cola", "cola", "cola"])
    var sim := scenario.simulation
    sim.players[0].item = SimItem.new(Menu.BEER)
    var start := sim.tick
    scenario.at(start, 0, C.INTERACT).at(start, 0, C.MOVE_RIGHT).at(start, 0, C.MOVE_RIGHT) \
            .at(start + rules.aim_hold + 1, 0, C.RELEASE)
    scenario.run_until(start + rules.aim_hold + 2)
    sim.crowd.line.resize(1)
    scenario.run_until(start + rules.aim_hold + rules.beer_flight + 3)
    assert_true(scenario.events.any(func(e: Dictionary) -> bool: return e.type == &"beer_missed"))
    assert_eq(sim.stats.beers, 0)


func test_escape_puts_the_aim_down_and_keeps_the_beer() -> void:
    var scenario := _with_line(["cola"])
    var player := scenario.simulation.players[0]
    player.item = SimItem.new(Menu.BEER)
    var start := scenario.simulation.tick
    scenario.at(start, 0, C.INTERACT).at(start + rules.aim_hold + 2, 0, C.CANCEL) \
            .at(start + rules.aim_hold + 3, 0, C.RELEASE).run_until(start + rules.aim_hold + 4)
    assert_eq(player.aim, -1)
    assert_eq(player.item.kind, Menu.BEER)


func test_an_angry_customer_throws_a_can_that_hits_a_player_standing_still() -> void:
    var scenario := _with_line(["frites:mayo"])
    var sim := scenario.simulation
    sim.players[0].item = SimItem.new(Menu.COLA)
    sim.crowd.front().patience = 1
    var start := sim.tick
    scenario.run_until(start + 2)
    assert_eq(sim.projectiles.size(), 1, "walking out, they throw a can")
    scenario.run_until(start + rules.can_flight + 3)
    assert_eq(sim.players[0].health, SimPlayer.MAX_HEALTH - 1)
    assert_eq(sim.players[0].stun, 0, "a can doesn't bump")
    assert_eq(sim.players[0].node, spot)
    assert_eq(sim.stats.cans_hit, 1)


func test_moving_away_dodges_the_can() -> void:
    var scenario := _with_line(["frites:mayo"])
    var sim := scenario.simulation
    sim.crowd.front().patience = 1
    var start := sim.tick
    scenario.at(start + 3, 0, C.MOVE_RIGHT).run_until(start + rules.can_flight + 3)
    assert_eq(sim.players[0].health, SimPlayer.MAX_HEALTH, "dodged")


func test_a_riled_up_room_throws_cans_at_random() -> void:
    var scenario := _with_line(["cola", "cola", "cola"])
    var sim := scenario.simulation
    rules.patience = NEVER
    for customer in sim.crowd.line:
        customer.patience = NEVER
    rules.can_every = 20
    sim.crowd.mood = rules.riot - 1
    scenario.run_until(sim.tick + 200)
    assert_true(scenario.events.any(func(e: Dictionary) -> bool: return e.type == &"can_thrown"))
    sim.crowd.mood = 0
    var thrown := scenario.events.size()
    scenario.run_until(sim.tick + 200)
    var later := scenario.events.slice(thrown).filter(func(e: Dictionary) -> bool: return e.type == &"can_thrown")
    assert_true(later.is_empty(), "a calm room throws nothing")


func test_the_hint_says_throw_once_the_aim_is_held() -> void:
    var scenario := _with_line(["cola"])
    var sim := scenario.simulation
    var player := sim.players[0]
    player.item = SimItem.new(Menu.BEER)
    scenario.at(sim.tick, 0, C.INTERACT).run_until(sim.tick + 1)
    assert_eq(sim.action_for(player), &"")
    scenario.run_until(sim.tick + rules.aim_hold)
    assert_eq(sim.action_for(player), &"throw")


## A player at spot and a full line with these orders (first customers first).
func _with_line(orders: Array) -> Scenario:
    var scenario := Scenario.new(level, [spot], 5, rules)
    scenario.run_until(rules.max_line + 1)
    var sim := scenario.simulation
    sim.crowd.line.resize(orders.size())
    for index in orders.size():
        sim.crowd.line[index].order = StringName(orders[index])
        sim.crowd.line[index].patience = rules.patience
    sim.crowd.next_arrival = NEVER
    return scenario
