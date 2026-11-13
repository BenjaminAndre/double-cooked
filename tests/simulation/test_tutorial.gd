extends GutTest
## The tutorial (GDD §4.4): steps that end only once done, played here from the first key press
## to the last.

const C := Simulation.Command

var level: SimLevel
## A row CUISSON 1 - CUISSON 2 - SAUCES - CAISSE - FRIGO - EXTINCTEUR, one unit apart.
var nodes := {}
var scenario: Scenario


func before_each() -> void:
    level = SimLevel.new()
    var previous := -1
    for kind: StringName in [&"cuisson_1", &"cuisson_2", &"sauces", &"caisse", &"frigo", &"extincteur"]:
        nodes[kind] = level.add_node(Vector3(nodes.size(), 0, 0), level.add_station(kind), String(kind))
        if previous >= 0:
            level.link(previous, SimLevel.Direction.RIGHT, nodes[kind])
            level.link(nodes[kind], SimLevel.Direction.LEFT, previous)
        previous = nodes[kind]
    # The line, in front of the counter.
    level.queue_front = Vector3(3, 0, -2)
    level.queue_step = Vector3(0.5, 0, 0)
    scenario = Scenario.new(level, PackedInt32Array([nodes[&"cuisson_1"]]), 3, Campaign.rules_for(Campaign.TUTORIAL))


func test_the_door_offers_the_tutorial() -> void:
    assert_true(Menu.DOOR_TUTORIAL in Menu.options(&"porte"))
    var rules := Campaign.rules_for(Campaign.TUTORIAL)
    assert_eq(rules.tutorial, 1)
    assert_true(Menu.DOOR_TUTORIAL_2 in Menu.options(&"porte"))
    assert_eq(Campaign.rules_for(Campaign.TUTORIAL_2).tutorial, 2)
    assert_eq(Campaign.rules_for(1).tutorial, 0)
    assert_false(rules.score_attack)
    assert_eq(rules.menu, Campaign.TUTORIAL_MENU)


func test_the_first_customer_waits_for_the_fries_without_losing_patience() -> void:
    var sim := scenario.run_until(600)
    assert_eq(sim.crowd.line.size(), 1)
    assert_eq(sim.crowd.line[0].order, &"frites:mayo")
    assert_eq(sim.crowd.line[0].patience, sim.crowd.line[0].full_patience)
    assert_eq(sim.tutorial.step, 0, "nothing done, nothing moves on")
    assert_eq(sim.outcome, &"")


func test_the_whole_tutorial_played_through() -> void:
    var sim := scenario.simulation
    _press(C.INTERACT, Fryer.FIRST_FRY_MIN + 1)  # drop the batch, wait for the green
    assert_eq(sim.tutorial.current().id, &"lift")
    _press(C.INTERACT, 1)  # lift it
    _press(C.INTERACT, 1)  # a portion
    assert_eq(sim.tutorial.current().id, &"second")
    _walk(C.MOVE_RIGHT, 1)
    _press(C.INTERACT, Fryer.SECOND_FRY_MIN + 1)  # second fry
    _press(C.INTERACT, 1)  # golden
    assert_eq(sim.tutorial.current().id, &"sauce")
    _walk(C.MOVE_RIGHT, 1)
    _press(C.INTERACT, 1)  # the menu: mayo is the only sauce tonight
    _press(C.INTERACT, 1)
    assert_eq(sim.tutorial.current().id, &"serve")
    _walk(C.MOVE_RIGHT, 1)
    _press(C.INTERACT, 1)
    assert_eq(sim.tutorial.current().id, &"beer")
    assert_eq(sim.crowd.line.size(), 1, "the beer customer came")
    _walk(C.MOVE_RIGHT, 1)
    _press(C.INTERACT, 1)  # the FRIGO's menu: beer
    _press(C.INTERACT, 1)
    _walk(C.MOVE_LEFT, 1)
    _press(C.INTERACT, 1)  # a tap at the CAISSE serves it
    _press(C.RELEASE, 1)
    assert_eq(sim.tutorial.current().id, &"extinguisher")
    assert_true(sim.stations[1].burning, "CUISSON 2 caught fire")
    _walk(C.MOVE_RIGHT, 2)
    _press(C.INTERACT, 1)
    _walk(C.MOVE_LEFT, 4)
    _press(C.INTERACT, sim.rules.spray_ticks + 2)
    assert_eq(sim.outcome, &"won")
    assert_eq(sim.outcome_reason, &"tutorial")


func test_the_second_part_played_through() -> void:
    scenario = Scenario.new(level, PackedInt32Array([nodes[&"frigo"]]), 3, Campaign.rules_for(Campaign.TUTORIAL_2))
    var sim := scenario.simulation
    var player := sim.players[0]
    scenario.run_until(1)
    assert_eq(sim.tutorial.current().id, &"take_drink")
    assert_eq(sim.crowd.line.size(), 1, "a customer to throw the drink at")
    _press(C.INTERACT, 1)  # the FRIGO's menu: beer
    _press(C.INTERACT, 1)
    _press(C.RELEASE, 1)
    assert_eq(sim.tutorial.current().id, &"throw")
    _press(C.INTERACT, sim.rules.aim_hold + 1)  # held down: aiming at the customer
    _press(C.RELEASE, sim.rules.beer_flight + 2)
    assert_eq(sim.tutorial.current().id, &"knocked")
    assert_true(player.down, "knocked out")
    _press(C.INTERACT, 1)  # still at the FRIGO
    _press(C.INTERACT, 1)
    _press(C.RELEASE, 1)
    _press(C.EAT, 1)
    assert_false(player.down, "back up")
    assert_eq(player.health, SimPlayer.MAX_HEALTH, "with all their hearts")
    assert_eq(sim.tutorial.current().id, &"slip")
    assert_true(sim.grease.has(nodes[&"sauces"]), "a puddle in front of the SAUCES")
    _walk(C.MOVE_LEFT, 2)
    assert_eq(sim.tutorial.current().id, &"shoo")
    assert_true(sim.grease.is_empty(), "mopped, for the inspector")
    # Back on their feet after the slide, and the pigeon landed.
    scenario.run_until(sim.tick + maxi(sim.rules.slip_stun + 10, sim.rules.pigeon_flight + 1))
    assert_eq(player.stun, 0)
    assert_eq(sim.pigeons.size(), 1, "a pigeon came")
    _stand_at(level.node_stations.find(sim.pigeons[0].station))
    _press(C.INTERACT, 1)
    _press(C.RELEASE, 1)
    assert_eq(sim.tutorial.current().id, &"gun")
    _stand_at(nodes[&"caisse"])
    _press(C.INTERACT, 1)
    _press(C.RELEASE, 1)
    assert_eq(sim.tutorial.current().id, &"shoot")
    scenario.run_until(sim.tick + sim.rules.pigeon_flight + 1)
    _press(C.INTERACT, sim.rules.aim_hold + 1)
    _press(C.RELEASE, 1)
    assert_eq(sim.tutorial.current().id, &"afsca")
    assert_gt(sim.night_events.inspection, 0, "the inspector is in")
    scenario.run_until(sim.tick + sim.rules.inspection_ticks + 1)
    assert_eq(sim.outcome, &"won")
    assert_eq(sim.outcome_reason, &"tutorial")


func test_the_puddle_and_the_pigeon_stay_until_dealt_with() -> void:
    scenario = Scenario.new(level, PackedInt32Array([nodes[&"frigo"]]), 3, Campaign.rules_for(Campaign.TUTORIAL_2))
    var sim := scenario.simulation
    scenario.run_until(1)
    sim.tutorial.step = sim.tutorial.steps().find_custom(func(step: Dictionary) -> bool: return step.id == &"slip")
    scenario.run_until(sim.tick + 1)
    assert_true(sim.grease.has(nodes[&"sauces"]), "the puddle is there")
    sim.grease.clear()
    scenario.run_until(sim.tick + 1)
    assert_true(sim.grease.has(nodes[&"sauces"]), "and back once dried")
    sim.tutorial.step += 1
    scenario.run_until(sim.tick + 1)
    assert_eq(sim.pigeons.size(), 1)
    sim._pigeon_leaves(sim.pigeons[0], &"stole")
    scenario.run_until(sim.tick + 1)
    assert_eq(sim.pigeons.size(), 1, "another one comes")


func test_a_failed_inspection_throws_nothing_away_in_the_tutorial() -> void:
    scenario = Scenario.new(level, PackedInt32Array([nodes[&"frigo"]]), 3, Campaign.rules_for(Campaign.TUTORIAL_2))
    var sim := scenario.simulation
    scenario.run_until(1)
    sim.players[0].item = SimItem.new(Menu.BEER)
    sim.tutorial.step = sim.tutorial.steps().size() - 1
    sim.night_events.inspect_now(sim.events)
    sim._grease(nodes[&"caisse"])
    scenario.run_until(sim.tick + sim.rules.inspection_ticks + 1)
    assert_eq(sim.outcome_reason, &"tutorial", "done all the same, not closed")
    assert_not_null(sim.players[0].item, "nothing thrown away")


## Puts the player in front of this node's station (where a pigeon landed).
func _stand_at(node: int) -> void:
    var player := scenario.simulation.players[0]
    player.node = node
    player.path.clear()

## A key press, then waits this many ticks.
func _press(command: int, wait: int) -> void:
    var tick := scenario.simulation.tick
    scenario.at(tick, 0, command).run_until(tick + 1 + wait)


## Walks this many nodes one way, waiting until arrived.
func _walk(command: int, count: int) -> void:
    for step in count:
        _press(command, 4)
