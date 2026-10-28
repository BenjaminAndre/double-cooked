extends GutTest
## The game's sound (the artist's DLC 1 pack and guide): every sound has its file and bus, the
## night's events pick the guide's sounds, the sound can be switched off, and Exit goes back to
## the lobby.

const GAME_SCENE := preload("res://game.tscn")
const LOOKS_PATH := "user://test_sound_board.cfg"

var night: Night


func before_each() -> void:
    DirAccess.remove_absolute(LOOKS_PATH)
    var game := GAME_SCENE.instantiate()
    night = game.get_node("Night")
    night.looks_path = LOOKS_PATH
    add_child_autofree(game)


func after_each() -> void:
    AudioServer.set_bus_mute(0, false)
    DirAccess.remove_absolute(LOOKS_PATH)


func test_every_sound_has_its_file_and_a_bus() -> void:
    for sound: StringName in SoundBoard.TABLE:
        assert_true(ResourceLoader.exists(SoundBoard.DIR % sound), String(sound))
        assert_true(AudioServer.get_bus_index(SoundBoard.TABLE[sound][0]) >= 0, "bus of %s" % sound)
    for loop in SoundBoard.LOOPS:
        var stream: AudioStreamWAV = load(SoundBoard.DIR % loop)
        assert_eq(stream.loop_mode, AudioStreamWAV.LOOP_FORWARD, "%s loops" % loop)


func test_events_pick_the_guides_sounds() -> void:
    assert_eq(SoundBoard.for_event({"type": &"served"}), [[&"order_served", 0]])
    assert_eq(SoundBoard.for_event({"type": &"arrival"}), [[&"customer_arrive", 0], [&"order_bubble", 350]])
    assert_eq(SoundBoard.for_event({"type": &"night_event", "kind": NightEvents.AFSCA}),
            [[&"event_announce", 0], [&"afsca_arrive", 1300]])
    assert_eq(SoundBoard.for_event({"type": &"look", "slot": 0}), [], "not every event makes a sound")
    for event in [{"type": &"group_left", "served": true}, {"type": &"inspection_over", "passed": false}]:
        for sound: Array in SoundBoard.for_event(event):
            assert_true(SoundBoard.TABLE.has(sound[0]), String(sound[0]))


func test_the_sound_switches_off_and_stays_off_on_this_browser() -> void:
    var hud: Hud = night.owner.get_node("Hud")
    hud.toggle_sound()
    assert_true(night.sounds.muted)
    assert_true(AudioServer.is_bus_mute(0))
    var config := ConfigFile.new()
    config.load(LOOKS_PATH)
    assert_true(config.get_value("settings", "muted", false))
    hud.toggle_sound()
    assert_false(AudioServer.is_bus_mute(0))


func test_exit_goes_back_to_the_lobby() -> void:
    night.play_local(1, 3)
    assert_false(night.in_lobby)
    night.leave_night()
    assert_true(night.in_lobby)
