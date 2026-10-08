extends GutTest
## The breads (GDD §7.3, the artist's recipes): burgers and mitraillettes, filled in any order.

const INTERACT := Simulation.Command.INTERACT
const RIGHT := Simulation.Command.MOVE_RIGHT
const LEFT := Simulation.Command.MOVE_LEFT
const DOWN := Simulation.Command.MOVE_DOWN

var level: SimLevel
var bread: int
var meat_fryer: int
var fries_fryer: int
var meats: int
var sauces: int


## A row PAIN - CUISSON VIANDE - CUISSON 2 - VIANDES - SAUCES, one unit apart.
func before_each() -> void:
    level = SimLevel.new()
    var row := []
    for kind in [&"pain", &"cuisson_viande", &"cuisson_2", &"viandes", &"sauces"]:
        row.append(level.add_node(Vector3(row.size(), 0, 0), level.add_station(kind), String(kind)))
    bread = row[0]
    meat_fryer = row[1]
    fries_fryer = row[2]
    meats = row[3]
    sauces = row[4]
    for index in row.size() - 1:
        level.link(row[index], SimLevel.Direction.RIGHT, row[index + 1])
        level.link(row[index + 1], SimLevel.Direction.LEFT, row[index])


func test_pain_hands_out_a_bun_or_a_baguette() -> void:
    var sim := Scenario.new(level, [bread]).at(0, 0, INTERACT).at(1, 0, INTERACT).run_until(2)
    assert_eq(sim.players[0].item.kind, Menu.BUN, "first option")
    sim = Scenario.new(level, [bread]).at(0, 0, INTERACT).at(1, 0, RIGHT).at(2, 0, INTERACT).run_until(3)
    assert_eq(sim.players[0].item.kind, Menu.BAGUETTE)


func test_a_bun_takes_a_steak_only_in_the_green() -> void:
    var scenario := Scenario.new(level, [meat_fryer])
    var sim := scenario.simulation
    var fryer := sim.stations[1]
    fryer.basket = SimItem.new(Menu.STEAK_RAW)
    fryer.frying = true
    sim.players[0].item = SimItem.new(Menu.BUN)
    assert_eq(sim.action_for(sim.players[0]), &"", "too early: no")
    fryer.cook = Fryer.SECOND_FRY_MIN
    assert_eq(sim.action_for(sim.players[0]), &"fill")
    scenario.at(0, 0, INTERACT).run_until(1)
    var burger := sim.players[0].item
    assert_eq(burger.filling.kind, Menu.STEAK)
    assert_null(fryer.basket)
    assert_eq(Menu.order_key(burger), &"burger:nature")
    assert_true(Menu.done_right(burger))


func test_salad_and_tomato_make_a_burger_complet_and_sauce_goes_on_too() -> void:
    var scenario := Scenario.new(level, [meats])
    var sim := scenario.simulation
    var burger := SimItem.new(Menu.BUN)
    burger.filling = SimItem.new(Menu.STEAK)
    sim.players[0].item = burger
    assert_eq(sim.action_for(sim.players[0]), &"veg")
    scenario.at(0, 0, INTERACT).run_until(1)
    assert_true(burger.veg)
    # Then SAUCES, first option.
    scenario.at(1, 0, RIGHT).at(10, 0, INTERACT).at(11, 0, INTERACT).run_until(12)
    assert_eq(Menu.order_key(sim.players[0].item), &"burger_complet:mayo")


func test_a_mitraillette_in_any_order() -> void:
    # Fries first, then the meat.
    var scenario := Scenario.new(level, [fries_fryer])
    var sim := scenario.simulation
    var fries := sim.stations[2]
    fries.basket = SimItem.new(Fryer.FRIES_BLANCHED)
    fries.frying = true
    fries.cook = Fryer.SECOND_FRY_MIN
    var meat := sim.stations[1]
    meat.basket = SimItem.new(Menu.FRICADELLE_RAW)
    meat.frying = true
    meat.cook = Fryer.SECOND_FRY_MIN
    sim.players[0].item = SimItem.new(Menu.BAGUETTE)
    scenario.at(0, 0, INTERACT).at(1, 0, LEFT).at(10, 0, INTERACT).run_until(11)
    var baguette := sim.players[0].item
    assert_eq(baguette.fries.kind, Fryer.FRIES_GOOD)
    assert_eq(baguette.filling.kind, Menu.FRICADELLE)
    assert_eq(Menu.order_key(baguette), &"mitraillette:nature")
    # A baguette never takes a steak, nor a bun fries.
    assert_false(Recipes.takes_meat(SimItem.new(Menu.BAGUETTE), Menu.STEAK))
    assert_false(Recipes.takes_fries(SimItem.new(Menu.BUN)))


func test_pain_wraps_a_good_meat_already_in_hand() -> void:
    var scenario := Scenario.new(level, [bread])
    var sim := scenario.simulation
    sim.players[0].item = SimItem.new(Menu.STEAK)
    assert_eq(sim.action_for(sim.players[0]), &"wrap")
    scenario.at(0, 0, INTERACT).at(1, 0, INTERACT).run_until(2)
    assert_eq(Menu.order_key(sim.players[0].item), &"burger:nature")
    # A burnt steak doesn't go in.
    sim.players[0].item = SimItem.new(Menu.STEAK_BURNT)
    assert_eq(sim.action_for(sim.players[0]), &"")


func test_half_a_mitraillette_is_no_dish_yet() -> void:
    var baguette := SimItem.new(Menu.BAGUETTE)
    baguette.filling = SimItem.new(Menu.BROCHETTE)
    assert_eq(Menu.order_key(baguette), &"")
    assert_eq(Menu.order_key(SimItem.new(Menu.BUN)), &"")


func test_breads_come_in_the_second_week_and_wait_longer() -> void:
    assert_false(&"burger" in Campaign.menu_for(8))
    assert_true(&"burger" in Campaign.menu_for(9))
    assert_true(&"mitraillette" in Campaign.menu_for(11))
    assert_false(Menu.station_in_use(&"pain", Campaign.menu_for(8)))
    assert_eq(Menu.options(&"pain", Campaign.menu_for(9)), [Menu.BUN])
    var rules := SimRules.new()
    rules.menu = [&"burger"] as Array[StringName]
    rules.first_arrival = 1
    var sim := Scenario.new(level, [bread], 1, rules).run_until(2)
    assert_eq(sim.crowd.front().patience, roundi(rules.patience * rules.bread_patience) - rules.front_drain)
