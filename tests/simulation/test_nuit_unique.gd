extends GutTest
## The Nuit unique (GDD §4.3): a score attack whose pace follows the crew.

const INTERACT := Simulation.Command.INTERACT
const NEVER := 1 << 30

var level: SimLevel
var till: int
var rules: SimRules


func before_each() -> void:
    level = SimLevel.new()
    till = level.add_node(Vector3.ZERO, level.add_station(&"caisse"), "C")
    rules = Campaign.rules_for(0)
    rules.first_arrival = 1
    rules.arrival_min = NEVER
    rules.arrival_max = NEVER
    rules.line_pressure_every = NEVER
    rules.night_ticks = NEVER
    rules.boss_orders = 0


func test_a_single_night_is_the_score_attack() -> void:
    assert_true(Campaign.rules_for(0).score_attack)
    assert_false(Campaign.rules_for(3).score_attack)


func test_the_faster_a_customer_is_served_the_more_it_scores() -> void:
    var points := []
    for left in [0.9, 0.5, 0.1]:
        var scenario := Scenario.new(level, [till], 1, rules)
        var sim := scenario.run_until(2)
        var customer := sim.crowd.front()
        customer.order = &"frites:mayo"
        customer.patience = roundi(customer.full_patience * left)
        var fries := SimItem.new(Fryer.FRIES_GOOD)
        fries.sauce = Menu.MAYO
        sim.players[0].item = fries
        scenario.at(2, 0, INTERACT).run_until(3)
        points.append(sim.score())
    assert_eq(points, [rules.points_very_fast, rules.points_fast, rules.points_served])


func test_the_pace_follows_the_crew_both_ways() -> void:
    var scenario := Scenario.new(level, [till], 1, rules)
    var sim := scenario.run_until(2)
    sim.crowd.front().order = &"cola"
    sim.players[0].item = SimItem.new(Menu.COLA)
    scenario.at(2, 0, INTERACT).run_until(3)
    assert_almost_eq(sim.crowd.pace, 1.0 + rules.pace_up, 0.0001, "served: faster")
    # A walk-out slows it back down.
    sim.crowd.line.append(SimCrowd.Customer.new())
    sim.crowd.line[0].patience = 1
    scenario.run_until(4)
    assert_almost_eq(sim.crowd.pace, (1.0 + rules.pace_up) * (1.0 - rules.pace_down), 0.0001)


func test_a_lost_night_scores_nothing() -> void:
    var scenario := Scenario.new(level, [till], 1, rules)
    var sim := scenario.run_until(2)
    sim.crowd.score = 500
    sim.crowd.mood = rules.riot
    scenario.run_until(3)
    assert_eq(sim.outcome, &"lost")
    assert_eq(sim.score(), 0)


func test_the_campaign_scores_nothing() -> void:
    var campaign := Campaign.rules_for(2)
    campaign.first_arrival = 1
    var scenario := Scenario.new(level, [till], 1, campaign)
    var sim := scenario.run_until(2)
    sim.crowd.front().order = &"cola"
    sim.players[0].item = SimItem.new(Menu.COLA)
    scenario.at(2, 0, INTERACT).run_until(3)
    assert_eq(sim.score(), 0)
    assert_eq(sim.crowd.pace, 1.0)
