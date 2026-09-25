extends GutTest
## The lobby's keyboard flow, without reaching the internet.

const GAME_SCENE := preload("res://game.tscn")

var lobby: Lobby


func before_each() -> void:
    var game: Node = add_child_autofree(GAME_SCENE.instantiate())
    lobby = game.get_node("Lobby")


func test_offline_it_shows_the_keys() -> void:
    assert_eq(lobby.state, Lobby.State.OFFLINE)
    assert_string_contains(_status(), "H : créer")


func test_j_opens_the_code_field_and_escape_closes_it() -> void:
    _press(KEY_J)
    assert_eq(lobby.state, Lobby.State.TYPING_CODE)
    assert_true(lobby._code_field.visible)
    var escape := InputEventAction.new()
    escape.action = &"ui_cancel"
    escape.pressed = true
    lobby._input(escape)
    assert_eq(lobby.state, Lobby.State.OFFLINE)
    assert_false(lobby._code_field.visible)


## Desktop builds need the webrtc-native extension, which the tests don't install.
func test_hosting_without_webrtc_reports_an_error_and_stays_offline() -> void:
    if TubeClient.is_webrtc_available():
        pending("WebRTC is available here")
        return
    _press(KEY_H)
    await wait_process_frames(5)
    assert_eq(lobby.state, Lobby.State.OFFLINE)
    assert_string_contains(_status(), "Erreur")
    assert_eq(lobby.night.role, Night.Role.OFFLINE)
    # Godot warns the first time WebRTC availability is checked, in whichever test that is.
    for error in get_errors():
        error.handled = true


func _press(keycode: Key) -> void:
    var key := InputEventKey.new()
    key.physical_keycode = keycode
    key.pressed = true
    lobby._unhandled_input(key)


func _status() -> String:
    return lobby._status.text
