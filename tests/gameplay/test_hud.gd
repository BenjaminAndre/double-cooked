extends GutTest
## The end-of-night stars (docs/ART_PLAN.md): held until closing, the room still in the green,
## every order of the boss served.


func test_a_lost_night_has_no_stars() -> void:
    var sim := _night()
    sim.outcome = &"lost"
    assert_eq(Hud.stars(sim), [false, false, false])


func test_one_star_for_holding_the_night_one_for_a_calm_room_one_for_the_boss() -> void:
    var sim := _night()
    sim.outcome = &"won"
    sim.crowd.mood = sim.rules.riot / 2
    assert_eq(Hud.stars(sim), [true, false, false], "held, but the room is past half")
    sim.crowd.mood = sim.rules.riot / 2 - 1
    assert_eq(Hud.stars(sim), [true, true, false], "in the green, no boss served")
    sim.stats.boss_came = true
    sim.stats.boss_served = sim.rules.boss_orders
    assert_eq(Hud.stars(sim), [true, true, true])
    sim.stats.boss_served -= 1
    assert_eq(Hud.stars(sim)[2], false, "one of his orders missed")


func _night() -> Simulation:
    var level := SimLevel.new()
    var till := level.add_node(Vector3.ZERO, level.add_station(&"caisse"), "C")
    return Simulation.new(level, PackedInt32Array([till]), 1)
