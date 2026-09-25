extends SceneTree
## Renders the game for a moment and saves a screenshot, to check layouts without the editor:
##     godot --path . --resolution 64x64 -s res://tools/screenshot.gd -- out.png [seconds] [setup]
## setup names one of the views prepared below, e.g. "crowd".
##
## Godot only renders while a window can draw (not headless, not minimized), so the window is
## shrunk, made unfocusable and pushed off-screen, and the game renders into a SubViewport.

const SIZE := Vector2i(1280, 720)


func _initialize() -> void:
    DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true)
    DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)
    DisplayServer.window_set_size(Vector2i.ONE)
    DisplayServer.window_set_position(Vector2i(-32000, -32000))
    var args := OS.get_cmdline_user_args()
    var output := args[0] if args.size() > 0 else "user://screenshot.png"
    var seconds := float(args[1]) if args.size() > 1 else 1.0
    var viewport := SubViewport.new()
    viewport.size = SIZE
    viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
    root.add_child(viewport)
    var game: Node = load("res://game.tscn").instantiate()
    viewport.add_child(game)
    await process_frame
    print("screenshot window at %s, size %s" % [DisplayServer.window_get_position(), DisplayServer.window_get_size()])
    var night: Night = game.get_node("Night")
    match args[2] if args.size() > 2 else "":
        "crowd":
            # A full line and a tense room, customers arriving every half second.
            night.simulation.rules.arrival_min = 15
            night.simulation.rules.arrival_max = 15
            night.simulation.crowd.next_arrival = 1
            night.simulation.crowd.mood = 420
        "duo":
            night.play_local(2)
        "won":
            night.simulation.rules.night_ticks = 20
        "lost":
            night.simulation.crowd.mood = night.simulation.rules.riot
        "danger":
            # Two players, CUISSON 1 on fire, P2 knocked out.
            night.play_local(2)
            var sim := night.simulation
            sim.stations[sim.level.node_stations[sim.level.find("Anchor2")]].burning = true
            sim.players[1].health = 0
            sim.players[1].down = true
            sim.players[0].hands[0] = SimItem.new(Simulation.EXTINGUISHER)
        "recap":
            night.play_local(2)
            var sim := night.simulation
            sim.stats.merge({"orders": 9, "dishes": 12, "bad_dishes": 3, "walk_outs": 2, "fires": 1,
                    "bumps": [5, 2], "knockouts": [0, 2], "revives": [2, 0]}, true)
            sim.players[0].health = 0
            sim.players[0].down = true
            sim.players[1].health = 0
            sim.players[1].down = true
        "fryers":
            # CUISSON 1 in its window, one CUISSON 2 undercooked, the other too late.
            var sim := night.simulation
            var fry := func(anchor: String, cook: int) -> void:
                var station := sim.stations[sim.level.node_stations[sim.level.find(anchor)]]
                station.basket = SimItem.new(Fryer.FRIES_RAW)
                station.frying = true
                station.cook = cook
            fry.call("Anchor2", Fryer.FIRST_FRY_MIN + 60)
            fry.call("Anchor4", Fryer.SECOND_FRY_MIN / 2)
            fry.call("Anchor5", Fryer.SECOND_FRY_MAX + 120)
        "hints":
            # P1 at CUISSON 1 with an empty fryer, P2 next to it holding resting fries.
            night.play_local(2)
            var sim := night.simulation
            sim.players[0].node = sim.level.find("Anchor2")
            sim.players[1].node = sim.level.find("Anchor4")
            sim.players[1].hands[0] = SimItem.new(Fryer.FRIES_BLANCHED)
    await create_timer(seconds).timeout
    await process_frame
    viewport.get_texture().get_image().save_png(output)
    quit()
