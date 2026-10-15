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
    scenario = Scenario.new(level, PackedInt32Array([nodes[&"cuisson_1"]]), 3, Campaign.rules_for(Campaign.TUTORIAL))


func test_the_door_offers_the_tutorial() -> void:
    assert_true(Menu.DOOR_TUTORIAL in Menu.options(&"porte"))
    var rules := Campaign.rules_for(Campaign.TUTORIAL)
    assert_true(rules.tutorial)
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


## A key press, then waits this many ticks.
func _press(command: int, wait: int) -> void:
    var tick := scenario.simulation.tick
    scenario.at(tick, 0, command).run_until(tick + 1 + wait)


## Walks this many nodes one way, waiting until arrived.
func _walk(command: int, count: int) -> void:
    for step in count:
        _press(command, 4)
