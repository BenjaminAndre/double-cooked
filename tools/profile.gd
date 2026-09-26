extends SceneTree
## Measures how long a frame takes to process in a few situations, to find what slows the game
## down (the Web build is several times slower, but the same things cost the same share):
##     godot --path . --resolution 64x64 -s res://tools/profile.gd
## Like the screenshot tool, the window is tiny and off-screen and the game renders into a
## SubViewport.

const FRAMES := 240

var _game: Node
var _night: Night


func _initialize() -> void:
    DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true)
    DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)
    DisplayServer.window_set_size(Vector2i.ONE)
    DisplayServer.window_set_position(Vector2i(-32000, -32000))
    # Unthrottled, so a frame takes as long as its work.
    DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
    Engine.max_fps = 0
    var viewport := SubViewport.new()
    viewport.size = Vector2i(1280, 720)
    viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
    root.add_child(viewport)
    _game = load("res://game.tscn").instantiate()
    viewport.add_child(_game)
    _night = _game.get_node("Night")
    await process_frame
    await _measure("calm")
    _setup_crowd()
    await _measure("full line")
    _setup_fryers()
    await _measure("line + 3 fryers")
    _setup_fire()
    await _measure("line + fire on 3 stations")
    quit()


func _measure(label: String) -> void:
    for i in 30:
        await process_frame
    var process := 0.0
    var start := Time.get_ticks_usec()
    var worst := 0.0
    for i in FRAMES:
        await process_frame
        var ms := Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
        process += ms
        worst = maxf(worst, ms)
    var frame := (Time.get_ticks_usec() - start) / 1000.0 / FRAMES
    print("PROFILE %-28s frame %6.2f ms, process %6.2f ms avg, %6.2f ms worst" % [label, frame,
            process / FRAMES, worst])


func _setup_crowd() -> void:
    var sim := _night.simulation
    sim.rules.arrival_min = 1
    sim.rules.arrival_max = 1
    sim.crowd.next_arrival = sim.tick + 1


func _setup_fryers() -> void:
    var sim := _night.simulation
    for anchor in ["Anchor2", "Anchor4", "Anchor5"]:
        var station := sim.stations[sim.level.node_stations[sim.level.find(anchor)]]
        station.basket = SimItem.new(Fryer.FRIES_BLANCHED)
        station.frying = true
        station.cook = 0


func _setup_fire() -> void:
    var sim := _night.simulation
    sim.rules.fire_spread_after = 1 << 30
    for anchor in ["Anchor2", "Anchor4", "Anchor9"]:
        var station := sim.stations[sim.level.node_stations[sim.level.find(anchor)]]
        station.basket = null
        station.frying = false
        station.burning = true
