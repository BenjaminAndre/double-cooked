class_name Lobby
extends CanvasLayer
## Keyboard-only online lobby over Tube (peer-to-peer WebRTC, sessions shared by code).
## H hosts, J joins, Enter starts the night (host), Escape leaves. The TubeClient is only
## created on demand, because it takes over the scene tree's multiplayer API.

enum State { OFFLINE, HOSTING, TYPING_CODE, JOINING, JOINED }

## Readable when spoken or typed: no O/0, I/1.
const CODE_CHARACTERS := "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
const APP_ID := "X9DO2vGZpLH9ByZ"
const TRACKERS: Array[String] = ["wss://tracker.androodev.com", "wss://tracker.openwebtorrent.com",
        "wss://tracker.files.fm:7073/announce", "wss://tracker.btorrent.xyz/"]
const STUN_SERVERS: Array[String] = ["stun:stun.l.google.com:19302", "stun:stun.cloudflare.com:3478"]

@export var night: Night

var state := State.OFFLINE

var _tube: TubeClient
var _status: Label
var _code_field: LineEdit
var _error := ""


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
    match [state, key.physical_keycode]:
        [State.OFFLINE, KEY_H]:
            _host()
        [State.OFFLINE, KEY_J]:
            state = State.TYPING_CODE
            _code_field.text = ""
            _code_field.visible = true
            _code_field.grab_focus()
        [State.HOSTING, KEY_ENTER], [State.HOSTING, KEY_KP_ENTER]:
            if _tube.state == TubeClient.State.SESSION_CREATED:
                night.host_online()
        [State.HOSTING, KEY_ESCAPE], [State.JOINING, KEY_ESCAPE], [State.JOINED, KEY_ESCAPE]:
            _leave()
        _:
            return
    get_viewport().set_input_as_handled()
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


## Back to an offline night, whatever the current state.
func _leave() -> void:
    if _tube and _tube.state != TubeClient.State.IDLE:
        _tube.leave_session()
    _code_field.visible = false
    _code_field.release_focus()
    state = State.OFFLINE
    if night.role != Night.Role.OFFLINE:
        night.play_local(1)
    _refresh()


func _ensure_tube() -> void:
    if _tube:
        return
    var context := TubeContext.new()
    context.app_id = APP_ID
    context.session_id_characters_set = CODE_CHARACTERS
    context.trackers_urls = TRACKERS
    context.stun_servers_urls = STUN_SERVERS
    _tube = TubeClient.new()
    _tube.context = context
    add_child(_tube)
    _tube.session_created.connect(_on_session_created)
    _tube.session_joined.connect(_on_session_joined)
    _tube.peer_connected.connect(_on_peers_changed)
    _tube.peer_disconnected.connect(_on_peer_disconnected)
    _tube.session_left.connect(_on_session_left)
    _tube.error_raised.connect(_on_error)


func _on_session_created() -> void:
    DisplayServer.clipboard_set(_tube.session_id)
    _refresh()


func _on_session_joined() -> void:
    state = State.JOINED
    _refresh()


func _on_peers_changed(_peer_id: int) -> void:
    _refresh()


func _on_peer_disconnected(peer_id: int) -> void:
    if state == State.JOINED and peer_id == 1:
        _error = "l'hôte est parti"
        _leave()
    _refresh()


func _on_session_left() -> void:
    if state != State.OFFLINE:
        _leave()


## Signaling errors only stop new players from joining; the session itself stays open.
func _on_error(code: int, message: String) -> void:
    _error = message
    if code in [TubeClient.SessionError.CREATE_SESSION_FAILED, TubeClient.SessionError.JOIN_SESSION_FAILED]:
        _leave()
    _refresh()


func _refresh() -> void:
    var text := ""
    match state:
        State.OFFLINE:
            text = "H : créer une partie en ligne · J : rejoindre · F2 : deux joueurs sur ce clavier"
        State.HOSTING:
            if _tube.state != TubeClient.State.SESSION_CREATED:
                text = "Création de la partie…"
            else:
                var players := _tube.multiplayer_api.get_peers().size() + 1
                var action := "relancer" if night.role == Night.Role.HOST else "lancer"
                text = "Code : %s (copié) · %d joueur%s · Entrée : %s la nuit · Échap : quitter" \
                        % [_tube.session_id, players, "s" if players > 1 else "", action]
        State.TYPING_CODE:
            text = "Tape le code puis Entrée · Échap : annuler"
        State.JOINING:
            text = "Connexion… · Échap : annuler"
        State.JOINED:
            text = "En ligne · Joueur %d · Échap : quitter" % (_slot() + 1) \
                    if night.role == Night.Role.CLIENT else "Connecté · en attente de l'hôte · Échap : quitter"
    if _error != "":
        text = "Erreur : %s\n%s" % [_error, text]
    _status.text = text


func _slot() -> int:
    return night.local_slots()[0]
