class_name Lobby
extends CanvasLayer
## Online play over Tube (peer-to-peer WebRTC, sessions shared by code), driven from the
## lobby's TÉLÉPHONE (Night.phone_used): create, join, two on this keyboard, leave. The host
## starts the night at the door; Escape leaves too. The TubeClient is only created on demand,
## because it takes over the scene tree's multiplayer API.

enum State { OFFLINE, HOSTING, TYPING_CODE, JOINING, JOINED }

## Readable when spoken or typed: no O/0, I/1.
const CODE_CHARACTERS := "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
const APP_ID := "X9DO2vGZpLH9ByZ"
const TRACKERS: Array[String] = ["wss://tracker.androodev.com", "wss://tracker.openwebtorrent.com",
        "wss://tracker.files.fm:7073/announce", "wss://tracker.btorrent.xyz/"]
const STUN_SERVERS: Array[String] = ["stun:stun.l.google.com:19302", "stun:stun.cloudflare.com:3478"]
## When the host is lost, everyone tries to rejoin the same code; the next host (Night.host_lost)
## tries NEXT_HOST_ATTEMPTS times, then opens its own session under that code.
const REJOIN_ATTEMPTS := 12
const NEXT_HOST_ATTEMPTS := 2
const REJOIN_DELAY := 2.0


## Tube draws a new code for each session; this one can reuse the last one, so the players
## find a new host under the code they already have.
class ReusableContext extends TubeContext:
    var forced_id := ""

    func generate_session_id() -> String:
        return forced_id if forced_id != "" else super()

@export var night: Night

var state := State.OFFLINE

var _tube: TubeClient
var _status: Label
var _code_field: LineEdit
var _error := ""
## The session's code, kept to reconnect under it.
var _code := ""
## The host is lost and a new one is being found.
var _migrating := false
var _next_host := false
var _attempts := 0
var _context: ReusableContext


func _ready() -> void:
    var box := VBoxContainer.new()
    box.position = Vector2(16, 12)
    add_child(box)
    _status = Label.new()
    _status.add_theme_constant_override("outline_size", 6)
    _status.add_theme_color_override("font_outline_color", Color.BLACK)
    box.add_child(_status)
    _code_field = LineEdit.new()
    _code_field.placeholder_text = "Code de la partie"
    _code_field.custom_minimum_size.x = 220
    _code_field.visible = false
    _code_field.text_submitted.connect(_on_code_submitted)
    box.add_child(_code_field)
    night.began.connect(_refresh)
    night.phone_used.connect(_on_phone)
    _refresh()


func _input(event: InputEvent) -> void:
    # Escape while typing the code: LineEdit would otherwise keep it.
    if state == State.TYPING_CODE and event.is_action_pressed(&"ui_cancel"):
        _leave()
        get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
    var key := event as InputEventKey
    if not key or not key.pressed or key.echo:
        return
    # Escape closes a station menu first; it only leaves the session when no menu is open.
    if key.physical_keycode == KEY_ESCAPE and night.has_open_menu():
        return
    match [state, key.physical_keycode]:
        # Once a night is over, Enter takes everyone back to the lobby (during one, it eats).
        [State.HOSTING, KEY_ENTER], [State.HOSTING, KEY_KP_ENTER]:
            if night.simulation.outcome == &"" or night.role != Night.Role.HOST:
                return
            night.host_lobby()
        [State.HOSTING, KEY_ESCAPE], [State.JOINING, KEY_ESCAPE], [State.JOINED, KEY_ESCAPE]:
            _leave()
        _:
            return
    get_viewport().set_input_as_handled()
    _refresh()


func _on_phone(choice: StringName) -> void:
    match [state, choice]:
        [State.OFFLINE, Menu.PHONE_HOST]:
            _host()
        [State.OFFLINE, Menu.PHONE_JOIN]:
            state = State.TYPING_CODE
            _code_field.text = ""
            _code_field.visible = true
            _code_field.grab_focus()
        [State.OFFLINE, Menu.PHONE_DUO]:
            night.play_lobby(2 if night.local_slots().size() == 1 else 1)
        [_, Menu.PHONE_LEAVE]:
            if state != State.OFFLINE:
                _leave()
    _refresh()


func _host() -> void:
    _ensure_tube()
    _error = ""
    state = State.HOSTING
    _tube.create_session()


func _on_code_submitted(code: String) -> void:
    _ensure_tube()
    _error = ""
    _code_field.visible = false
    _code_field.release_focus()
    state = State.JOINING
    _tube.join_session(code.strip_edges().to_upper())
    _refresh()


## Back to an offline lobby, whatever the current state.
func _leave() -> void:
    _migrating = false
    if _tube and _tube.state != TubeClient.State.IDLE:
        _tube.leave_session()
    _code_field.visible = false
    _code_field.release_focus()
    state = State.OFFLINE
    if night.role != Night.Role.OFFLINE or not night.in_lobby:
        night.play_lobby(1)
    _refresh()


func _ensure_tube() -> void:
    if _tube:
        return
    _context = ReusableContext.new()
    _context.app_id = APP_ID
    _context.session_id_characters_set = CODE_CHARACTERS
    _context.trackers_urls = TRACKERS
    _context.stun_servers_urls = STUN_SERVERS
    _tube = TubeClient.new()
    _tube.context = _context
    add_child(_tube)
    _tube.session_created.connect(_on_session_created)
    _tube.session_joined.connect(_on_session_joined)
    _tube.peer_connected.connect(_on_peer_connected)
    _tube.peer_disconnected.connect(_on_peer_disconnected)
    _tube.session_left.connect(_on_session_left)
    _tube.error_raised.connect(_on_error)


func _on_session_created() -> void:
    _code = _tube.session_id
    if _migrating:
        # Taking over from the host that left: the others rejoin under the same code.
        _migrating = false
        night.become_host()
    else:
        DisplayServer.clipboard_set(_tube.session_id)
        night.host_lobby()
    _refresh()


## Connected to the host: it hears who this is, and puts them in the lobby or the night.
func _on_session_joined() -> void:
    state = State.JOINED
    _code = _tube.session_id
    _migrating = false
    night.say_hello()
    _refresh()


## The host waits for the newcomer's hello (Night.say_hello) to place them.
func _on_peer_connected(_peer_id: int) -> void:
    _refresh()


func _on_peer_disconnected(peer_id: int) -> void:
    if state == State.JOINED and peer_id == 1:
        _host_lost()
    elif state == State.HOSTING:
        night.peer_left(peer_id)
    _refresh()


func _on_session_left() -> void:
    if _migrating:
        return
    if state == State.JOINED:
        _host_lost()
    elif state != State.OFFLINE:
        _leave()


## The host is gone (or this player's connection dropped): try the same code again. If the
## host is still there, this player just gets their slot back; if not, the next host takes over.
func _host_lost() -> void:
    if _migrating:
        return
    _migrating = true
    _next_host = night.host_lost()
    _attempts = 0
    _error = ""
    state = State.JOINING
    _rejoin.call_deferred()
    _refresh()


func _rejoin() -> void:
    if not _migrating:
        return
    if _tube.state != TubeClient.State.IDLE:
        _tube.leave_session()
    _attempts += 1
    _tube.join_session(_code)


func _take_over() -> void:
    if _tube.state != TubeClient.State.IDLE:
        _tube.leave_session()
    state = State.HOSTING
    _context.forced_id = _code
    _tube.create_session()
    _context.forced_id = ""


## Signaling errors only stop new players from joining; the session itself stays open.
func _on_error(code: int, message: String) -> void:
    if _migrating and code == TubeClient.SessionError.JOIN_SESSION_FAILED:
        if _next_host and _attempts >= NEXT_HOST_ATTEMPTS:
            _take_over()
        elif _attempts < REJOIN_ATTEMPTS:
            get_tree().create_timer(REJOIN_DELAY).timeout.connect(_rejoin)
        else:
            _error = "l'hôte est parti"
            _leave()
        _refresh()
        return
    _error = message
    if code in [TubeClient.SessionError.CREATE_SESSION_FAILED, TubeClient.SessionError.JOIN_SESSION_FAILED]:
        _leave()
    _refresh()


func _refresh() -> void:
    var text := ""
    match state:
        State.HOSTING:
            if _tube.state != TubeClient.State.SESSION_CREATED:
                text = "Création de la partie..."
            else:
                var players := _tube.multiplayer_api.get_peers().size() + 1
                text = "Hôte (%s) · %d joueur%s" % [_tube.session_id, players, "s" if players > 1 else ""]
        State.TYPING_CODE:
            text = "Tape le code puis Entrée · Échap : annuler"
        State.JOINING:
            text = "Reconnexion... · Échap : quitter" if _migrating else "Connexion... · Échap : annuler"
        State.JOINED:
            text = "En ligne" if night.role == Night.Role.CLIENT else "Connecté · en attente de l'hôte"
    if _error != "":
        text = "Erreur : %s\n%s" % [_error, text]
    _status.text = text.strip_edges()
