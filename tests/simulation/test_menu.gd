extends GutTest
## VIANDES, FRIGO and the meats in CUISSON 2 (GDD §7.2).

const INTERACT := Simulation.Command.INTERACT
const RIGHT := Simulation.Command.MOVE_RIGHT
const LEFT := Simulation.Command.MOVE_LEFT

var level: SimLevel
var meats: int
var fryer: int
var fridge: int


## A row VIANDES - CUISSON 2 - FRIGO, one unit apart.
func before_each() -> void:
    level = SimLevel.new()
    meats = level.add_node(Vector3(0, 0, 0), level.add_station(&"viandes"), "V")
    fryer = level.add_node(Vector3(1, 0, 0), level.add_station(&"cuisson_2"), "F")
    fridge = level.add_node(Vector3(2, 0, 0), level.add_station(&"frigo"), "K")
    for pair in [[meats, fryer], [fryer, fridge]]:
        level.link(pair[0], SimLevel.Direction.RIGHT, pair[1])
        level.link(pair[1], SimLevel.Direction.LEFT, pair[0])


func test_viandes_hands_out_the_chosen_meat() -> void:
    var sim := Scenario.new(level, [meats]).at(0, 0, INTERACT).at(1, 0, INTERACT).run_until(2)
    assert_eq(sim.players[0].item.kind, Menu.CERVELAS, "first option")
    sim = Scenario.new(level, [meats]).at(0, 0, INTERACT).at(1, 0, RIGHT).at(2, 0, INTERACT).run_until(3)
    assert_eq(sim.players[0].item.kind, Menu.FRICADELLE_RAW)


func test_frigo_hands_out_the_chosen_drink() -> void:
    var sim := Scenario.new(level, [fridge]).at(0, 0, INTERACT).at(1, 0, RIGHT).at(2, 0, INTERACT).run_until(3)
    assert_eq(sim.players[0].item.kind, Menu.BEER)


func test_menu_stations_need_a_free_hand() -> void:
    var scenario := Scenario.new(level, [fridge])
    scenario.simulation.players[0].item = SimItem.new(Menu.COLA)
    assert_eq(scenario.simulation.action_for(scenario.simulation.players[0]), &"drink", "no menu, so a drink")
    scenario.at(0, 0, INTERACT).run_until(1)
    assert_eq(scenario.simulation.players[0].menu, SimLevel.NONE)


func test_a_fricadelle_fried_in_time_is_done_right() -> void:
    assert_eq(_fried(Menu.FRICADELLE_RAW, Fryer.SECOND_FRY_MIN).kind, Menu.FRICADELLE)
    assert_eq(_fried(Menu.FRICADELLE_RAW, Fryer.SECOND_FRY_MIN - 1).kind, Menu.FRICADELLE_UNDERCOOKED)
    assert_eq(_fried(Menu.FRICADELLE_RAW, Fryer.SECOND_FRY_MAX + 1).kind, Menu.FRICADELLE_BURNT)


func test_a_fried_cervelas_becomes_a_warm_one() -> void:
    var warm := _fried(Menu.CERVELAS, Fryer.SECOND_FRY_MIN)
    assert_eq(warm.kind, Menu.CERVELAS_WARM)
    assert_eq(Menu.order_key(warm), &"cervelas_chaud:nature")
    assert_true(Menu.done_right(warm))
    assert_false(Menu.done_right(_fried(Menu.CERVELAS, 0)), "barely warmed up")


func test_nothing_with_sauce_goes_into_the_fryer() -> void:
    var scenario := Scenario.new(level, [fryer])
    var cervelas := SimItem.new(Menu.CERVELAS)
    cervelas.sauce = Menu.MAYO
    scenario.simulation.players[0].item = cervelas
    scenario.at(0, 0, INTERACT).run_until(1)
    assert_null(scenario.simulation.stations[1].basket)


func test_order_keys_name_the_dish_and_the_sauce() -> void:
    var fries := SimItem.new(Fryer.FRIES_SOGGY)
    fries.sauce = Menu.ANDALOUSE
    assert_eq(Menu.order_key(fries), &"frites:andalouse")
    assert_eq(Menu.order_key(SimItem.new(Menu.CERVELAS)), &"cervelas_froid:nature")
    assert_eq(Menu.order_key(SimItem.new(Menu.BEER)), &"biere")
    assert_eq(Menu.order_key(SimItem.new(Menu.FRICADELLE_RAW)), &"", "a raw fricadelle can't be served")


## Puts item in CUISSON 2 at tick 0 and lifts it after cook ticks; returns what came out.
func _fried(kind: StringName, cook: int) -> SimItem:
    var scenario := Scenario.new(level, [fryer])
    scenario.simulation.players[0].item = SimItem.new(kind)
    var sim := scenario.at(0, 0, INTERACT).at(cook, 0, INTERACT).run_until(cook + 1)
    return sim.players[0].item
