extends GutTest
## Grease fires, the extinguisher, knock-outs, eating, drinking, rescues and the recap
## counters (GDD §5.1, §8).

const INTERACT := Simulation.Command.INTERACT
const RIGHT := Simulation.Command.MOVE_RIGHT
const LEFT := Simulation.Command.MOVE_LEFT
const DAMAGE := Simulation.Command.DEBUG_DAMAGE
const NEVER := 1 << 30

var level: SimLevel
var extinguisher: int
var fryer: int
var sauces: int
var fridge: int
var rules: SimRules
## The tick a CUISSON 1 basket dropped at tick 0 catches fire.
var fire_tick: int


## A row EXTINCTEUR - CUISSON 1 - SAUCES - FRIGO, one unit apart, no customers, short fires.
func before_each() -> void:
    level = SimLevel.new()
    extinguisher = level.add_node(Vector3(0, 0, 0), level.add_station(&"extincteur"), "X")
    fryer = level.add_node(Vector3(1, 0, 0), level.add_station(&"cuisson_1"), "F")
    sauces = level.add_node(Vector3(2, 0, 0), level.add_station(&"sauces"), "S")
    fridge = level.add_node(Vector3(3, 0, 0), level.add_station(&"frigo"), "K")
    for pair in [[extinguisher, fryer], [fryer, sauces], [sauces, fridge]]:
        level.link(pair[0], SimLevel.Direction.RIGHT, pair[1])
        level.link(pair[1], SimLevel.Direction.LEFT, pair[0])
    rules = SimRules.new()
    rules.first_arrival = NEVER
    rules.night_ticks = NEVER
    rules.fire_margin = 20
    fire_tick = Fryer.FIRST_FRY_MAX + rules.fire_margin
    rules.fire_damage_every = 10
    rules.fire_spread_after = 50
    rules.crawl_ticks = 12


func test_a_basket_left_too_long_starts_a_fire() -> void:
    var scenario := _scenario([fryer]).at(0, 0, INTERACT)
    var sim := scenario.run_until(fire_tick + 1)
    var station := sim.stations[1]
    assert_true(station.burning)
    assert_null(station.basket, "the fries are gone")
    assert_true(scenario.events.any(func(e: Dictionary) -> bool: return e.type == &"fire_started"))


func test_a_burning_station_cannot_be_used() -> void:
    var sim := _burning_fryer([sauces]).run_until(fire_tick + 5)
    sim.stations[1].burning = true
    sim.players[0].node = fryer
    sim.step([[INTERACT]])
    assert_null(sim.stations[1].basket, "no new basket in a burning fryer")


func test_standing_at_a_fire_costs_a_heart_every_few_seconds() -> void:
    var scenario := _burning_fryer([sauces])
    var sim := scenario.run_until(fire_tick + 1)
    sim.players[0].node = fryer
    scenario.run_until(sim.tick + rules.fire_damage_every * 2)
    assert_eq(sim.players[0].health, SimPlayer.MAX_HEALTH - 2)


func test_leaving_the_fire_resets_the_exposure() -> void:
    var scenario := _burning_fryer([sauces])
    var sim := scenario.run_until(fire_tick + 1)
    sim.players[0].node = fryer
    var start := sim.tick
    scenario.at(start + rules.fire_damage_every - 2, 0, RIGHT)
    scenario.run_until(start + rules.fire_damage_every * 3)
    assert_eq(sim.players[0].health, SimPlayer.MAX_HEALTH, "left just before it hurt")


func test_a_fire_spreads_to_a_neighbour_but_never_to_the_extinguisher() -> void:
    var sim := _burning_fryer([fridge]).run_until(fire_tick + 1 + rules.fire_spread_after)
    assert_true(sim.stations[2].burning, "SAUCES caught fire")
    assert_false(sim.stations[0].burning, "EXTINCTEUR is fireproof")
    assert_eq(sim.stats.fires, 2)


func test_the_extinguisher_puts_a_fire_out_and_stays_in_hand() -> void:
    var scenario := _burning_fryer([extinguisher])
    var start := fire_tick + 1
    scenario.at(start, 0, INTERACT).at(start + 1, 0, RIGHT).at(start + 6, 0, INTERACT)
    var sim := scenario.run_until(start + 7)
    assert_false(sim.stations[1].burning)
    assert_eq(sim.players[0].item.kind, Simulation.EXTINGUISHER)


func test_the_extinguisher_goes_back_on_its_station() -> void:
    var sim := _scenario([extinguisher]).at(0, 0, INTERACT).at(1, 0, INTERACT).run_until(2)
    assert_null(sim.players[0].item)


func test_zero_hearts_knocks_a_player_out_and_they_crawl() -> void:
    var scenario := _scenario([extinguisher])
    for i in SimPlayer.MAX_HEALTH:
        scenario.at(0, 0, DAMAGE)
    scenario.at(1, 0, RIGHT)
    var sim := scenario.run_until(2)
    assert_true(sim.players[0].down)
    assert_eq(sim.players[0].edge_ticks, rules.crawl_ticks, "crawling is slow")
    assert_eq(sim.stats.knockouts[0], 1)


func test_knocked_out_a_player_can_still_eat_what_they_hold() -> void:
    var scenario := _scenario([sauces])
    var sim := scenario.run_until(1)
    var player := sim.players[0]
    player.item = SimItem.new(Fryer.FRIES_GOOD)
    player.health = 1
    scenario.at(1, 0, DAMAGE).run_until(2)
    assert_true(player.down)
    assert_eq(sim.action_for(player), &"", "no sauce while down")
    assert_eq(sim.eat_action(player), &"eat", "but eating is fine")
    scenario.at(2, 0, Simulation.Command.EAT).run_until(3)
    assert_false(player.down)
    assert_eq(player.health, 1)
    assert_null(player.item)


func test_eating_or_drinking_gives_a_heart_and_fat_even_at_full_health() -> void:
    var scenario := _scenario([extinguisher])
    var sim := scenario.run_until(1)
    var player := sim.players[0]
    player.health = 1
    player.item = SimItem.new(Menu.CERVELAS)
    scenario.at(1, 0, Simulation.Command.EAT).run_until(2)
    assert_eq(player.health, 2)
    player.item = SimItem.new(Menu.COLA)
    scenario.at(2, 0, Simulation.Command.EAT).run_until(3)
    assert_eq(player.health, 3)
    player.item = SimItem.new(Fryer.FRIES_BURNT)
    scenario.at(3, 0, Simulation.Command.EAT).run_until(4)
    assert_eq(player.health, SimPlayer.MAX_HEALTH, "capped")
    assert_eq(player.bmi, 24, "but it all counts")
    assert_true(scenario.events.any(func(e: Dictionary) -> bool: return e.type == &"fattened"))


func test_the_station_comes_before_eating() -> void:
    var scenario := _scenario([sauces])
    var player := scenario.simulation.players[0]
    player.item = SimItem.new(Fryer.FRIES_GOOD)
    assert_eq(scenario.simulation.action_for(player), &"sauce", "SAUCES has a use for fries")
    player.item = SimItem.new(Simulation.EXTINGUISHER)
    assert_eq(scenario.simulation.action_for(player), &"", "an extinguisher isn't food")


func test_every_bite_makes_the_walk_slower() -> void:
    var scenario := _scenario([extinguisher])
    var sim := scenario.run_until(1)
    scenario.at(1, 0, RIGHT).run_until(2)
    var lean := sim.players[0].edge_ticks
    sim.players[0].node = extinguisher
    sim.players[0].path.clear()
    sim.players[0].edge_ticks = 0
    sim.players[0].bmi = 26
    scenario.at(2, 0, RIGHT).run_until(3)
    assert_gt(sim.players[0].edge_ticks, lean)


func test_a_beer_thrown_to_a_knocked_out_teammate_gets_them_up() -> void:
    var scenario := _scenario([sauces, fridge])
    for i in SimPlayer.MAX_HEALTH:
        scenario.at(0, 0, DAMAGE)
    var sim := scenario.run_until(1)
    sim.players[1].item = SimItem.new(Menu.BEER)
    scenario.at(1, 1, INTERACT).at(2, 1, Simulation.Command.MOVE_UP) \
            .at(2 + rules.aim_hold, 1, Simulation.Command.RELEASE)
    scenario.run_until(3)
    assert_eq(sim.players[1].aim_player, 0, "up aims at the teammate")
    scenario.run_until(3 + rules.aim_hold + rules.beer_flight)
    assert_false(sim.players[0].down)
    assert_eq(sim.players[0].health, 1)
    assert_eq(sim.players[0].bmi, 22, "rescue beers count too")
    assert_eq(sim.stats.revives[1], 1)


func test_a_beer_thrown_to_a_teammate_lands_in_an_empty_hand() -> void:
    var scenario := _scenario([sauces, fridge])
    var sim := scenario.run_until(1)
    sim.players[1].item = SimItem.new(Menu.BEER)
    scenario.at(1, 1, INTERACT).at(2, 1, Simulation.Command.MOVE_UP) \
            .at(2 + rules.aim_hold, 1, Simulation.Command.RELEASE)
    scenario.run_until(3 + rules.aim_hold + rules.beer_flight)
    assert_eq(sim.players[0].item.kind, Menu.BEER)
    assert_eq(sim.players[0].bmi, 21, "caught, not drunk")
func test_the_night_is_lost_when_the_whole_crew_is_down() -> void:
    var scenario := _scenario([sauces, extinguisher])
    for slot in 2:
        for i in SimPlayer.MAX_HEALTH:
            scenario.at(0, slot, DAMAGE)
    var sim := scenario.run_until(1)
    assert_eq(sim.outcome, &"lost")
    assert_eq(sim.outcome_reason, &"crew_down")


func test_alone_and_down_the_night_goes_on() -> void:
    var scenario := _scenario([sauces])
    for i in SimPlayer.MAX_HEALTH:
        scenario.at(0, 0, DAMAGE)
    assert_eq(scenario.run_until(5).outcome, &"")


func test_bumps_are_counted_per_player() -> void:
    var sim := _scenario([sauces, fridge]).at(0, 1, LEFT).at(5, 1, LEFT).run_until(6)
    assert_eq(sim.stats.bumps, [0, 2])


func _scenario(spawns: Array) -> Scenario:
    return Scenario.new(level, PackedInt32Array(spawns), 3, rules)


## A basket put in CUISSON 1 at tick 0 by a player standing there, who then walks away.
## It catches fire at fire_tick; the players start where spawns say.
func _burning_fryer(spawns: Array) -> Scenario:
    var scenario := _scenario(spawns)
    scenario.simulation.stations[1].basket = SimItem.new(Fryer.FRIES_RAW)
    scenario.simulation.stations[1].frying = true
    return scenario


func test_the_hint_offers_the_fridge_when_down_and_the_extinguisher() -> void:
    var scenario := _scenario([sauces, fridge])
    var sim := scenario.simulation
    sim.players[1].health = 0
    sim.players[1].down = true
    assert_eq(sim.action_for(sim.players[1]), &"fridge", "down at the FRIGO: a beer")
    sim.players[0].health = 0
    sim.players[0].down = true
    assert_eq(sim.action_for(sim.players[0]), &"", "down at SAUCES with empty hands: nothing")
    assert_eq(sim.action_for(sim.players[0]), &"", "down, and not at SOINS")
    sim.players[0].node = extinguisher
    sim.players[0].down = false
    assert_eq(sim.action_for(sim.players[0]), &"take_extinguisher")
    sim.players[0].item = SimItem.new(Simulation.EXTINGUISHER)
    assert_eq(sim.action_for(sim.players[0]), &"return_extinguisher")
    sim.players[0].node = fryer
    sim.stations[1].burning = true
    assert_eq(sim.action_for(sim.players[0]), &"extinguish")


func test_crawling_keeps_no_queue() -> void:
    var scenario := _scenario([extinguisher])
    for i in SimPlayer.MAX_HEALTH:
        scenario.at(0, 0, DAMAGE)
    scenario.at(1, 0, RIGHT).at(2, 0, RIGHT).at(3, 0, RIGHT)
    var player := scenario.run_until(4).players[0]
    assert_eq(player.path, [fryer] as Array[int], "presses while crawling are ignored")
    scenario.run_until(1 + rules.crawl_ticks + 1)
    assert_eq(player.node, fryer)
    assert_true(player.path.is_empty(), "stops at the first node")


func test_walking_burns_a_bmi_point_every_so_many_nodes() -> void:
    var scenario := _scenario([sauces])
    for step in rules.moves_per_bmi:
        scenario.at(step * 5, 0, RIGHT if step % 2 == 0 else LEFT)
    var sim := scenario.run_until(rules.moves_per_bmi * 5 + 5)
    assert_eq(sim.players[0].bmi, rules.start_bmi - 1)
    assert_eq(sim.players[0].walked, 0)


func test_undernourished_a_player_collapses_and_a_beer_gets_them_up() -> void:
    var scenario := _scenario([sauces])
    var player := scenario.simulation.players[0]
    player.bmi = rules.knockout_bmi + 1
    player.walked = rules.moves_per_bmi - 1
    var sim := scenario.at(0, 0, RIGHT).run_until(6)
    assert_eq(player.bmi, rules.knockout_bmi)
    assert_true(player.down, "starving")
    assert_eq(player.health, SimPlayer.MAX_HEALTH, "hearts have nothing to do with it")
    player.item = SimItem.new(Menu.BEER)
    scenario.at(sim.tick, 0, Simulation.Command.EAT).run_until(sim.tick + 1)
    assert_false(player.down)


func test_being_thin_is_not_faster_but_being_heavy_is_slower() -> void:
    var ticks := {}
    for bmi in [rules.start_bmi, rules.start_bmi - 3, rules.start_bmi + 3]:
        var scenario := _scenario([sauces])
        scenario.simulation.players[0].bmi = bmi
        ticks[bmi] = scenario.at(0, 0, RIGHT).run_until(1).players[0].edge_ticks
    assert_eq(ticks[rules.start_bmi - 3], ticks[rules.start_bmi])
    assert_gt(ticks[rules.start_bmi + 3], ticks[rules.start_bmi])
