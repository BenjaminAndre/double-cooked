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


func test_a_session_that_fails_to_open_goes_back_offline_once() -> void:
    # As if Tube had started creating a session, then found no tracker (no network here).
    lobby._ensure_tube()
    lobby.state = Lobby.State.HOSTING
    lobby._tube.state = TubeClient.State.CREATING_SESSION
    var left := [0]
    lobby._tube.session_left.connect(func() -> void: left[0] += 1)
    lobby._on_error(TubeClient.SessionError.CREATE_SESSION_FAILED, "cannot connect to any tracker")
    assert_eq(lobby.state, Lobby.State.OFFLINE)
    assert_eq(left[0], 1, "left once, not again and again")
    assert_eq(lobby._tube.state, TubeClient.State.IDLE)


func test_a_host_that_lost_its_trackers_reopens_them() -> void:
    var opened := []
    lobby.open_tracker = func(url: String) -> void: opened.append(url)
    lobby._ensure_tube()
    lobby.state = Lobby.State.HOSTING
    lobby._tube.state = TubeClient.State.SESSION_CREATED
    lobby._process(0.1)
    assert_eq(opened, Array(Lobby.TRACKERS), "all of them, none being open")
    opened.clear()
    lobby._process(0.1)
    assert_eq(opened, [], "not again before TRACKER_RETRY")
    assert_eq(Lobby.missing_trackers(PackedStringArray(["wss://tracker.btorrent.xyz", Lobby.TRACKERS[0]])).size(),
            Lobby.TRACKERS.size() - 2, "the open ones, with or without their slash, stay as they are")
    lobby._tube.state = TubeClient.State.IDLE
