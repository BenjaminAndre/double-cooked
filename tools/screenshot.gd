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
    var setup: String = args[2] if args.size() > 2 else ""
    night.looks_path = ""
    # The game opens in the lobby; the other setups are in the kitchen.
    if not setup.begins_with("lobby"):
        night.play_local(1)
    if setup.begins_with("view_"):
        # view_<pitch>_<yaw>[_<distance>]: tries another camera on the kitchen, e.g. view_40_31.
        var parts := setup.split("_")
        var room: GridRoom = game.get_node("Restaurant/Kitchen")
        room.camera_pitch = float(parts[1])
        room.camera_yaw = float(parts[2])
        if parts.size() > 3:
            room.camera_distance = float(parts[3])
        room.place_camera()
        night.play_local(2)
        night.simulation.rules.arrival_min = 15
        night.simulation.rules.arrival_max = 15
        night.simulation.crowd.next_arrival = 1
    match setup:
        "lobby":
            # Two players: one choosing a colour, the other at the hat stand in a beer helmet.
            night.play_lobby(2)
            var sim := night.simulation
            sim.players[0].node = sim.level.find("Cell0_0")
            sim.players[1].node = sim.level.find("Cell0_1")
            sim.players[1].hat = 2
            sim.players[1].color = 3
            night.submit(0, Simulation.Command.INTERACT)
            night.submit(0, Simulation.Command.MOVE_LEFT)
        "eject":
            # Both CUISSON 2 baskets halfway through tipping out, about 1 s in.
            var views := LevelReader.stations(game.get_node("Restaurant/Kitchen").anchors_root())
            for view: Interactible in views:
                if view.kind == &"cuisson_2":
                    create_timer(0.75).timeout.connect(view._lift_basket)
        "lobby_record":
            # The best campaign so far, under the logo.
            night._record = {"night": 7, "colors": [1, 3]}
            night.play_lobby(1)
        "lobby_door":
            # The host at the door while a teammate isn't ready yet.
            night.play_lobby(2)
            var sim := night.simulation
            sim.players[0].node = sim.level.find("Cell0_4")
        "crowd":
            # A full line and a tense room, customers arriving every half second.
            night.simulation.rules.arrival_min = 15
            night.simulation.rules.arrival_max = 15
            night.simulation.crowd.next_arrival = 1
            night.simulation.crowd.mood = 420
        "duo":
            night.play_local(2)
        "campaign":
            # Night 2 of a campaign: sauces are new, FRIGO, VIANDES and PAIN are greyed out.
            night.play_local(2, 2)
        "campaign_lost":
            # A campaign lost on its 4th night, with each player's stats.
            night.play_local(2, 4)
            var sim := night.simulation
            sim.stats.merge({"served": 14, "angry": 3, "served_by": [9, 5], "missed_by": [1, 2],
                    "beers_by": [0, 2], "bumps": [5, 2], "knockouts": [0, 2], "revives": [2, 0]}, true)
            sim.crowd.mood = sim.rules.riot
        "won":
            night.simulation.rules.night_ticks = 20
            night.simulation.rules.boss_orders = 0
        "lost":
            night.simulation.crowd.mood = night.simulation.rules.riot
        "danger":
            # Two players, CUISSON 1 on fire, P2 knocked out.
            night.play_local(2)
            var sim := night.simulation
            sim.stations[sim.level.node_stations[sim.level.find("Anchor2")]].burning = true
            sim.players[1].health = 0
            sim.players[1].down = true
            sim.players[0].item = SimItem.new(Simulation.EXTINGUISHER)
        "desync":
            # What a client sees once it drifted from the host, just after pressing F3.
            night.desyncs = 2
            night.notice.emit("Replay téléchargé")
        "boss":
            # The boss at the counter with his drink, a full line behind him.
            var sim := night.simulation
            sim.rules.boss_at = 0.0
            sim.rules.boss_drink_again = 15
            sim.rules.arrival_min = 15
            sim.rules.arrival_max = 15
            sim.crowd.next_arrival = 1
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
        "menu":
            # The SAUCES menu open on andalouse, and a line of three-line orders.
            var sim := night.simulation
            var player := sim.players[0]
            player.node = sim.level.find("Anchor9")
            player.item = SimItem.new(Fryer.FRIES_GOOD)
            player.menu = sim.level.node_stations[player.node]
            player.menu_choice = 1
            sim.rules.arrival_min = 15
            sim.rules.arrival_max = 15

            sim.crowd.next_arrival = 1
        "throws":
            # P1 aims a beer at the second customer, P2 has thrown one, a can flies at P1.
            night.play_local(2)
            var sim := night.simulation
            sim.rules.arrival_min = 5
            sim.rules.arrival_max = 5
            sim.crowd.next_arrival = 1
            var p1 := sim.players[0]
            p1.node = sim.level.find("Anchor9")
            p1.item = SimItem.new(Menu.BEER)
            p1.aim = 1
            p1.aim_ticks = 100
            sim.players[1].node = sim.level.find("Anchor11")
            await create_timer(0.6).timeout
            p1.aim = 1
            var can := SimProjectile.new(SimProjectile.CAN, sim.level.queue_position(0) + Vector3.UP,
                    sim.player_position(p1), sim.tick - 20, 90)
            var beer := SimProjectile.new(SimProjectile.BEER, sim.player_position(sim.players[1]) + Vector3.UP,
                    sim.level.queue_position(2) + Vector3.UP * 0.6, sim.tick - 30, 90)
            sim.projectiles.append_array([can, beer])
        "can":
            # A close-up of the can model, in front of its own camera.
            for turn in 3:
                var can := BeerCan.new()
                can.position = Vector3(1000 + (turn - 1) * 0.2, 0, 0)
                can.rotation.y = turn * 2.1
                viewport.add_child(can)
            var camera := Camera3D.new()
            camera.position = Vector3(1000, 0.25, 1.6)
            camera.rotation.x = -0.15
            camera.fov = 22
            viewport.add_child(camera)
            camera.make_current()
        "fat":
            # P1 has eaten a lot (and just ate again); P2 aims a beer at P1.
            night.play_local(2)
            var sim := night.simulation
            sim.players[0].bmi = 25
            sim.players[0].node = sim.level.find("Anchor3")
            night._views[0].show_fat_change(true)
            var p2 := sim.players[1]
            p2.node = sim.level.find("Anchor11")
            p2.bmi = 17
            p2.item = SimItem.new(Menu.BEER)
            p2.aim = 0
            p2.aim_player = 0
            p2.aim_ticks = 100
        "hints":
            # P1 at CUISSON 1 with an empty fryer, P2 next to it holding resting fries.
            night.play_local(2)
            var sim := night.simulation
            sim.players[0].node = sim.level.find("Anchor2")
            sim.players[1].node = sim.level.find("Anchor4")
            sim.players[1].item = SimItem.new(Fryer.FRIES_BLANCHED)
    await create_timer(seconds).timeout
    await process_frame
    viewport.get_texture().get_image().save_png(output)
    quit()
