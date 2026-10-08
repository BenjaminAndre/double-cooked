extends GutTest
## The host's test tools in the game scene (F4, GDD §9.3): the panel, the replay marked, no
## record, the jump to a campaign night and the speed.

const GAME_SCENE := preload("res://game.tscn")
const RECORD_PATH := "user://test_debug_panel.cfg"

var night: Night
var panel: DebugPanel


func before_each() -> void:
    DirAccess.remove_absolute(RECORD_PATH)
    var game := GAME_SCENE.instantiate()
    night = game.get_node("Night")
    night.looks_path = RECORD_PATH
    add_child_autofree(game)
    panel = game.get_node("Hud").tools


func after_each() -> void:
    DirAccess.remove_absolute(RECORD_PATH)


func test_f4_opens_the_panel_and_a_tool_reaches_the_night_through_the_replay() -> void:
    night.play_local(1)
    panel.toggle()
    assert_true(panel.visible)
    assert_eq(panel.rows()[0].id, &"mood")
    # Mood, three to the right: one walk-out away from the riot.
    for step in 3:
        panel.press(KEY_RIGHT)
    panel.press(KEY_SPACE)
    await wait_until(func() -> bool: return night.simulation.crowd.level() == SimCrowd.Level.EMEUTE, 2.0)
    assert_true(night.debug_used)
    var replay := night.replay()
    assert_true(replay.debug_used)
    assert_true(Array(replay.commands).has(Simulation.debug_command(Simulation.DebugTool.MOOD, 3)))
    panel.press(KEY_ESCAPE)
    assert_false(panel.visible)


func test_the_lobby_offers_only_the_campaign_and_the_speed() -> void:
    var ids := panel.rows().map(func(row: Dictionary) -> StringName: return row.id)
    assert_eq(ids, [&"campaign", &"speed"])


func test_jumping_to_a_campaign_night_sets_no_record() -> void:
    panel.toggle()
    panel.press(KEY_RIGHT)
    panel.press(KEY_RIGHT)
    panel.press(KEY_SPACE)
    assert_false(night.in_lobby)
    assert_eq(night.campaign_night, 3)
    assert_eq(night.simulation.rules.menu, Campaign.menu_for(3))
    assert_false(panel.visible, "the panel closes on the new night")
    night.simulation.crowd.mood = night.simulation.rules.riot
    await wait_until(func() -> bool: return night.simulation.outcome == &"lost", 2.0)
    await wait_process_frames(1)
    assert_false(night.new_record)
    assert_eq(night.campaign_record().night, 0)
    night.continue_after_night()
    assert_true(night.in_lobby)
    assert_false(night.debug_used, "a new run starts clean")


func test_a_tested_campaign_stays_tested_from_one_night_to_the_next() -> void:
    night.jump_to_night(2)
    night.simulation._end(&"won", &"closing")
    night.continue_after_night()
    assert_eq(night.campaign_night, 3)
    assert_true(night.debug_used)
    assert_true(night.replay().debug_used)


func test_the_speed_steps_more_ticks_in_the_same_time() -> void:
    night.play_local(1)
    night.set_process(false)
    var ticks := []
    for times in [1, 4]:
        night.speed = times
        var before := night.simulation.tick
        # A tenth of a second has gone by.
        night._last_usec = Time.get_ticks_usec() - 100_000
        night._accumulator = 0.0
        night._advance()
        ticks.append(night.simulation.tick - before)
    assert_eq(ticks[0], 3)
    assert_eq(ticks[1], 12)
    assert_false(night.debug_used, "faster isn't easier: it doesn't count as a tool")
