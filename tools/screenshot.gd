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
    await create_timer(seconds).timeout
    await process_frame
    root.get_viewport().get_texture().get_image().save_png(output)
    quit()
