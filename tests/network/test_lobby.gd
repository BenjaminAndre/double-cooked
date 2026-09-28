extends GutTest
## The online flow from the lobby's TÉLÉPHONE, without reaching the internet.

const GAME_SCENE := preload("res://game.tscn")

var lobby: Lobby


func before_each() -> void:
    var game: Node = add_child_autofree(GAME_SCENE.instantiate())
    lobby = game.get_node("Lobby")


func test_the_game_opens_in_the_lobby_offline_with_nothing_over_it() -> void:
    assert_eq(lobby.state, Lobby.State.OFFLINE)
    assert_true(lobby.night.in_lobby)
    assert_eq(_status(), "")


func test_the_phone_puts_two_players_on_this_keyboard_and_back() -> void:
    lobby._on_phone(Menu.PHONE_DUO)
    assert_eq(lobby.night.local_slots().size(), 2)
    assert_true(lobby.night.in_lobby)
    lobby._on_phone(Menu.PHONE_DUO)
    assert_eq(lobby.night.local_slots().size(), 1)


func test_joining_opens_the_code_field_and_escape_closes_it() -> void:
    lobby._on_phone(Menu.PHONE_JOIN)
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
    lobby._on_phone(Menu.PHONE_HOST)
    await wait_process_frames(5)
    assert_eq(lobby.state, Lobby.State.OFFLINE)
    assert_string_contains(_status(), "Erreur")
    assert_eq(lobby.night.role, Night.Role.OFFLINE)
    # Godot warns the first time WebRTC availability is checked, in whichever test that is.
    for error in get_errors():
        error.handled = true


func _status() -> String:
    return lobby._status.text
