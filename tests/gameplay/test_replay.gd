extends GutTest
## A night played through the real game scene can be replayed exactly by a Scenario.

const GAME_SCENE := preload("res://game.tscn")


func test_a_played_night_replays_to_the_same_state() -> void:
    var game: Node = add_child_autofree(GAME_SCENE.instantiate())
    var night: Night = game.get_node("Night")
    night.play_local(2)
    night.submit(0, Simulation.Command.DEBUG_DAMAGE)
    night.submit(0, Simulation.Command.MOVE_RIGHT)
    night.submit(1, Simulation.Command.MOVE_DOWN)
    await wait_seconds(0.3)
    night.submit(0, Simulation.Command.MOVE_RIGHT)
    night.submit(1, Simulation.Command.FOCUS_RIGHT)
    await wait_seconds(0.3)
    var replay: Dictionary = JSON.parse_string(JSON.stringify(night.replay()))
    var level := LevelReader.read(game.get_node("DemoLevel/Anchors"))
    var replayed := Scenario.from_replay(level, replay).run_until(int(replay.ticks))
    assert_eq(replay.level, "res://game.tscn")
    assert_eq(replay.commands.size(), 5 * 3)
    assert_eq(replayed.state_hash(), night.simulation.state_hash())
