extends SceneTree
## Renders the game for a moment and saves a screenshot, to check layouts without the editor:
##     godot --path . --resolution 1280x720 -s res://tools/screenshot.gd -- out.png [seconds] [setup]
## setup names one of the views prepared below, e.g. "crowd".

func _initialize() -> void:
    var args := OS.get_cmdline_user_args()
    var output := args[0] if args.size() > 0 else "user://screenshot.png"
    var seconds := float(args[1]) if args.size() > 1 else 1.0
    var game: Node = load("res://game.tscn").instantiate()
    root.add_child(game)
    await process_frame
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
    await create_timer(seconds).timeout
    await process_frame
    root.get_viewport().get_texture().get_image().save_png(output)
    quit()
