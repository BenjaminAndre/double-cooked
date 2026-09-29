class_name Night
extends Node
## Runs one night: owns the Simulation, feeds it commands tick by tick, and shows its state
## through the Player scenes.
##
## Offline, the commands come from this keyboard. Online, the host also takes the clients'
## commands, decides which tick they apply on and relays that stream to the clients, who run
## the same deterministic simulation from it (GDD §9.1). The stream is also the replay.

enum Role { OFFLINE, HOST, CLIENT }

const PLAYER_SCENE := preload("res://gameplay/player.tscn")
const TICK_TIME := 1.0 / Simulation.TICK_RATE
## How long one call to _advance() may spend stepping. Beyond it, the host drops time instead
## of stepping in a burst, and a client catches up over the next frames.
const STEP_BUDGET_USEC := 8000
## A client this many ticks behind the host steps faster to catch up.
const CLIENT_LAG_TICKS := 3
## The host sends a state fingerprint this often, so clients notice a desync.
const CHECK_EVERY := Simulation.TICK_RATE
## Saves the night so far as a replay file: downloaded on the web, where user:// is out of reach.
const REPLAY_KEY := KEY_F3
const REPLAY_DIR := "user://replays"
const KEPT_REPLAYS := 20

signal began
## A short message for the HUD, e.g. once a replay is saved.
signal notice(text: String)
## A player at this keyboard used the lobby's TÉLÉPHONE (Menu.PHONE).
signal phone_used(choice: StringName)

## The kitchen the nights are played in; its spawns are also the maximum player count.
@export var kitchen_room: GridRoom
@export var players_parent: Node3D
## 0 picks a new random seed for each night.
@export var night_seed := 0
## Where the customers line up; its position and line_step become the simulation's queue.
@export var queue: CustomersView
## The waiting room players meet in before a night (GDD §4.1).
@export var lobby_room: GridRoom
## Where each player's saved looks are kept, "" not to keep them (tests).
@export var looks_path := "user://looks.cfg"

var simulation: Simulation
## How far we are towards the next tick, for views that draw between ticks.
var alpha := 0.0
var role := Role.OFFLINE
## Fingerprint checks where this client differed from the host. Should stay 0.
var desyncs := 0
## The ticks of those checks, kept in the replay.
var desync_ticks := PackedInt32Array()
## Whether this is the lobby rather than a night in the kitchen.
var in_lobby := false

@onready var _link: NightLink = $Link

var _input: LocalInput
## The slot of each player at this keyboard.
var _local_slots := PackedInt32Array()
var _views: Array[Player] = []
## One per simulation station, in the same order.
var _station_views: Array[Interactible] = []
## Offline and host: commands per slot, waiting for the next tick.
var _pending: Array = []
## Client: tick -> [check, flattened commands], as relayed by the host.
var _received := {}
## Host: peer id -> slot.
var _peer_slots := {}
## Host: the peers in slot order (slot 1 first), kept from one night to the next.
var _peer_order: Array[int] = []
var _replay := {}
## tick, slot, command, tick, slot, command...
var _log := PackedInt32Array()
var _accumulator := 0.0
## Wall clock of the last _advance(): time is measured, not summed from frame deltas, so the
## hidden-tab heartbeat and the frames share the same clock.
var _last_usec := 0
## Client: wall clock of the last tick relayed by the host.
var _last_tick_usec := 0
## Slots whose player left the online night.
var _left := {}
var _web_page: WebPage


func _ready() -> void:
    # Update the Player views before their own _process reads them.
    process_priority = -1
    _link.command_received.connect(_on_command_received)
    _link.night_began.connect(_on_night_began)
    _link.tick_received.connect(_on_tick_received)
    _link.player_left.connect(_on_player_left)
    _web_page = WebPage.new()
    _web_page.hidden_beat.connect(_on_hidden_beat)
    add_child(_web_page)
    play_lobby(1)


func _exit_tree() -> void:
    _save_replay()


## Offline lobby with one or two players on this keyboard.
func play_lobby(local_players: int) -> void:
    _play_offline(local_players, true)


## Offline night with one or two players on this keyboard.
func play_local(local_players: int) -> void:
    _play_offline(local_players, false)


## Host: everyone connected into the lobby, e.g. when someone joins.
func host_lobby() -> void:
    _host_begin(true)


## Host: starts an online night with every connected peer.
func host_online() -> void:
    _host_begin(false)


func _play_offline(local_players: int, lobby: bool) -> void:
    var slots := PackedInt32Array()
    for slot in local_players:
        slots.append(slot)
    _begin(local_players, slots, _new_seed(), Role.OFFLINE, lobby, _current_looks())


## The host is slot 0. The others keep their slot from one night to the next, and newcomers
## follow in peer id order; each keeps their looks.
func _host_begin(lobby: bool) -> void:
    var by_peer := {1: _look_of(0)}
    for index in _peer_order.size():
        by_peer[_peer_order[index]] = _look_of(index + 1)
    var connected := multiplayer.get_peers()
    connected.sort()
    _peer_order = _peer_order.filter(func(peer: int) -> bool: return peer in connected)
    for peer in connected:
        if not peer in _peer_order:
            _peer_order.append(peer)
    _peer_order.resize(mini(_peer_order.size(), _max_players(lobby) - 1))
    _peer_slots.clear()
    var looks := PackedInt32Array(by_peer[1])
    for index in _peer_order.size():
        _peer_slots[_peer_order[index]] = index + 1
        looks.append_array(by_peer.get(_peer_order[index], [-1, -1]))
    var seed_value := _new_seed()
    var count := _peer_order.size() + 1
    _begin(count, PackedInt32Array([0]), seed_value, Role.HOST, lobby, looks)
    for peer in _peer_order:
        _link.begin_night.rpc_id(peer, count, _peer_slots[peer], seed_value, lobby, looks)


## [colour, hat] of this slot in the current simulation, [-1, -1] if there is none.
func _look_of(slot: int) -> Array:
    if simulation and slot < simulation.players.size():
        return [simulation.players[slot].color, simulation.players[slot].hat]
    return [-1, -1]


## Everyone's looks so far, flattened: colour, hat, colour, hat...
func _current_looks() -> PackedInt32Array:
    var looks := PackedInt32Array()
    if simulation:
        for player in simulation.players:
            looks.append_array([player.color, player.hat])
    return looks


func _max_players(lobby: bool) -> int:
    return lobby_room.spawn_names().size() if lobby and lobby_room else kitchen_room.spawn_names().size()


## Queues a command from a player at this keyboard, as if their key was pressed.
## local_index is 0 for the only (or left) player, 1 for the right one.
func submit(local_index: int, command: int) -> void:
    if role == Role.CLIENT:
        _link.send_command.rpc_id(1, command)
    else:
        _pending[_local_slots[local_index]].append(command)


## The slot of each player at this keyboard.
func local_slots() -> PackedInt32Array:
    return _local_slots


## Host: a peer left. Its player stays in the night, idle, marked as gone for everyone.
func peer_left(peer_id: int) -> void:
    if role != Role.HOST or not _peer_slots.has(peer_id):
        return
    var slot: int = _peer_slots[peer_id]
    _peer_slots.erase(peer_id)
    _on_player_left(slot)
    _link.mark_left.rpc(slot)


## Client: seconds since the host last relayed a tick, 0 elsewhere.
func host_silence() -> float:
    if role != Role.CLIENT:
        return 0.0
    return (Time.get_ticks_usec() - _last_tick_usec) / 1_000_000.0


## Whether a player at this keyboard has a station menu open (Escape then closes it).
func has_open_menu() -> bool:
    for slot in _local_slots:
        if simulation.players[slot].menu != SimLevel.NONE:
            return true
    return false


## The night so far, in the shape Scenario.from_replay() reads.
func replay() -> Dictionary:
    var data := _replay.duplicate()
    data.ticks = simulation.tick
    data.commands = Array(_log)
    if not desync_ticks.is_empty():
        data.desync_ticks = Array(desync_ticks)
    return data


## Saves the night so far without ending it: a download on the web, a file in REPLAY_DIR
## elsewhere. Returns what happened, for the HUD.
func export_replay() -> String:
    var file_name := "double-cooked-%d.json" % Time.get_unix_time_from_system()
    var text := JSON.stringify(replay())
    if OS.has_feature("web"):
        JavaScriptBridge.download_buffer(text.to_utf8_buffer(), file_name, "application/json")
        return "Replay téléchargé"
    DirAccess.make_dir_recursive_absolute(REPLAY_DIR)
    var path := "%s/%s" % [REPLAY_DIR, file_name]
    var file := FileAccess.open(path, FileAccess.WRITE)
    if not file:
        return "Replay non enregistré"
    file.store_string(text)
    return "Replay enregistré : %s" % ProjectSettings.globalize_path(path)


func _unhandled_input(event: InputEvent) -> void:
    var key := event as InputEventKey
    if key and key.pressed and not key.echo and key.physical_keycode == REPLAY_KEY:
        notice.emit(export_replay())
        get_viewport().set_input_as_handled()
        return
    # Once a night is over, Enter goes back to the lobby (online, the host's Lobby does it).
    if role == Role.OFFLINE and key and key.pressed and not key.echo and simulation.outcome != &"" \
            and key.physical_keycode in [KEY_ENTER, KEY_KP_ENTER]:
        play_lobby(_local_slots.size())
        get_viewport().set_input_as_handled()
        return
    var command := _input.read(event)
    if not command.is_empty():
        submit(command[0], command[1])


func _process(_delta: float) -> void:
    _advance()
    _show(_accumulator / TICK_TIME)


## Steps the ticks that are due by the wall clock, within STEP_BUDGET_USEC.
func _advance() -> void:
    var now := Time.get_ticks_usec()
    _accumulator += (now - _last_usec) / 1_000_000.0
    _last_usec = now
    var due := int(_accumulator / TICK_TIME)
    _accumulator -= due * TICK_TIME
    if role == Role.CLIENT:
        # Follow the host: step what has arrived, all at once when lagging behind.
        var backlog := _received.size()
        if backlog > CLIENT_LAG_TICKS:
            due = maxi(due, backlog - CLIENT_LAG_TICKS)
        due = mini(due, backlog)
    var stepped := 0
    while stepped < due and Time.get_ticks_usec() - now < STEP_BUDGET_USEC:
        if not _step():
            break
        stepped += 1
    if stepped < due and role != Role.CLIENT:
        _accumulator = 0.0


## In a hidden browser tab there are no frames: keep the network and the night going.
func _on_hidden_beat() -> void:
    multiplayer.poll()
    _advance()


## One tick. Returns false when a client doesn't have the host's next tick yet.
func _step() -> bool:
    var tick := simulation.tick
    var commands: Array
    var check := 0
    if role == Role.CLIENT:
        if not _received.has(tick):
            return false
        var data: Array = _received[tick]
        _received.erase(tick)
        check = data[0]
        commands = _unflatten(data[1])
    else:
        commands = _pending
        _pending = _no_commands()
    simulation.step(commands)
    var flat := _flatten(commands)
    for index in range(0, flat.size(), 2):
        _log.append_array([tick, flat[index], flat[index + 1]])
    if role == Role.HOST:
        if simulation.tick % CHECK_EVERY == 0:
            check = simulation.state_hash()
        _link.receive_tick.rpc(tick, check, flat)
    elif role == Role.CLIENT and simulation.tick % CHECK_EVERY == 0 \
            and check != simulation.state_hash():
        desyncs += 1
        desync_ticks.append(simulation.tick)
        push_warning("Desync with the host at tick %d" % simulation.tick)
    for event in simulation.events:
        if event.type == &"bump":
            _views[event.target].show_bump()
        elif event.type == &"fattened":
            _views[event.slot].show_fat_change(true)
        elif event.type == &"thinner":
            _views[event.slot].show_fat_change(false)
        elif event.type == &"trashed":
            _station_views[event.station].pulse()
        elif event.type == &"boss_arrived":
            notice.emit("Le boss arrive !")
        elif event.type == &"look" and _local_slots.size() > 0 and event.slot == _local_slots[0]:
            _save_looks(simulation.players[event.slot])
        elif event.type == &"phone" and event.slot in _local_slots:
            # Deferred: the lobby may start over, which replaces this simulation.
            phone_used.emit.call_deferred(event.choice)
        elif event.type == &"start_night" and role != Role.CLIENT:
            (host_online if role == Role.HOST else play_local.bind(_local_slots.size())).call_deferred()
    return true


## looks: colour, hat per slot (-1 keeps the default), carried from the lobby to the night.
func _begin(player_count: int, local_slots: PackedInt32Array, seed_value: int, p_role: Role,
        lobby := false, looks := PackedInt32Array()) -> void:
    _save_replay()
    role = p_role
    in_lobby = lobby and lobby_room != null
    for view in _views:
        view.queue_free()
    _views.clear()
    var room := lobby_room if in_lobby else kitchen_room
    var root := room.anchors_root()
    var level := LevelReader.read(root)
    if queue and not in_lobby:
        level.queue_front = queue.global_position
        level.queue_step = queue.line_step
    _station_views = LevelReader.stations(root)
    var spawn_names := room.spawn_names().slice(0, player_count)
    var spawn_nodes := PackedInt32Array()
    for spawn_name: String in spawn_names:
        spawn_nodes.append(level.find(spawn_name))
    var rules := SimRules.new()
    rules.lobby = in_lobby
    simulation = Simulation.new(level, spawn_nodes, seed_value, rules)
    _apply_looks(looks)
    room.camera.current = true
    _replay = {"version": 2, "level": owner.scene_file_path if owner else "", "seed": seed_value,
            "spawns": spawn_names, "looks": Array(looks), "lobby": in_lobby}
    _log.clear()
    _local_slots = local_slots
    _input = LocalInput.new(local_slots.size())
    _pending = _no_commands()
    _received.clear()
    _accumulator = 0.0
    _last_usec = Time.get_ticks_usec()
    _last_tick_usec = _last_usec
    _left.clear()
    desyncs = 0
    desync_ticks = PackedInt32Array()
    for slot in player_count:
        var view: Player = PLAYER_SCENE.instantiate()
        view.is_local_player = slot in local_slots
        view.level_start_bmi = simulation.rules.start_bmi
        view.hungry_below = simulation.rules.knockout_bmi + 2
        # The colour stands for the player: no name over their head.
        view.pseudo = ""
        players_parent.add_child(view)
        _views.append(view)
    _show(0.0)
    began.emit()
    if in_lobby and _local_slots.size() > 0:
        var saved := _saved_looks()
        if not saved.is_empty():
            submit(0, Looks.command(saved[0], saved[1]))


func _on_command_received(peer_id: int, command: int) -> void:
    if role == Role.HOST and _peer_slots.has(peer_id):
        _pending[_peer_slots[peer_id]].append(command)


func _on_night_began(player_count: int, slot: int, seed_value: int, lobby: bool,
        looks: PackedInt32Array) -> void:
    _begin(player_count, PackedInt32Array([slot]), seed_value, Role.CLIENT, lobby, looks)


func _on_tick_received(tick: int, check: int, commands: PackedInt32Array) -> void:
    if role == Role.CLIENT:
        _received[tick] = [check, commands]
        _last_tick_usec = Time.get_ticks_usec()


func _on_player_left(slot: int) -> void:
    if _left.has(slot) or slot >= _views.size():
        return
    _left[slot] = true
    _views[slot].pseudo = (_views[slot].pseudo + " (parti)").strip_edges()
    notice.emit("%s est parti" % Looks.player_name(simulation.players[slot].color))


## alpha: how far we are towards the next tick, to keep walking smooth between ticks.
func _show(p_alpha: float) -> void:
    alpha = p_alpha
    for slot in _views.size():
        _views[slot].show_state(simulation.players[slot], simulation.level, p_alpha)
    # Each player at this keyboard sees the station they stand at highlighted, and what their
    # interact key would do there.
    var highlighted := {}
    for local_index in _local_slots.size():
        var slot := _local_slots[local_index]
        var player := simulation.players[slot]
        # [key, verb] rows.
        var hints: Array = []
        var interact_key := _input.interact_key_name(local_index)
        if not player.is_moving() and simulation.outcome == &"":
            var station := simulation.level.node_stations[player.node]
            if station != SimLevel.NONE:
                highlighted[station] = true
            var action := simulation.action_for(player)
            if action in [&"door_wait", &"door_host"]:
                # Nothing to press: only why the door stays shut.
                hints.append(["", ItemNames.action(action)])
            elif action != &"":
                hints.append([interact_key, ItemNames.action(action)])
                if action == &"throw" and simulation.players.size() > 1:
                    hints.append(["Haut", "équipier"])
            if player.item and player.item.kind == Menu.BEER and player.aim < 0 and not player.down:
                # A beer can always be thrown: hold the key to aim at the line.
                hints.append([interact_key, "maintenir : lancer"])
        var eat := simulation.eat_action(player) if simulation.outcome == &"" else &""
        if eat != &"":
            hints.append([_input.eat_key_name(local_index), ItemNames.action(eat)])
        _views[slot].show_hint(hints)
        var options: Array = []
        var disabled: Array = []
        if player.menu != SimLevel.NONE:
            var menu_station := simulation.stations[player.menu]
            var menu_options: Array = Menu.STATION_OPTIONS[menu_station.kind]
            for index in menu_options.size():
                var option: StringName = menu_options[index]
                if menu_station.kind == &"peinture":
                    # The characters' faces; a teammate's is greyed out.
                    options.append(PaperFigure.portrait(Looks.character(index)))
                    if not simulation.color_free(index, player):
                        disabled.append(index)
                    continue
                var word := ItemNames.word(option)
                if option == Menu.BEER:
                    word += " ×%d" % menu_station.beers
                elif option == Menu.PHONE_DUO:
                    word = "seul" if _local_slots.size() > 1 else "à deux"
                elif option == Menu.PHONE_LEAVE and role == Role.OFFLINE:
                    disabled.append(index)
                options.append(word)
        _views[slot].show_menu(options, player.menu_choice, disabled)
    var open_menus := {}
    for player in simulation.players:
        open_menus[player.menu] = true
    for index in _station_views.size():
        _station_views[index].show_station(simulation.stations[index], simulation.rules)
        _station_views[index].set_highlighted(highlighted.has(index))
        _station_views[index].set_menu_open(open_menus.has(index))


func _no_commands() -> Array:
    var commands := []
    for slot in simulation.players.size():
        commands.append([])
    return commands


func _flatten(commands: Array) -> PackedInt32Array:
    var flat := PackedInt32Array()
    for slot in commands.size():
        for command: int in commands[slot]:
            flat.append_array([slot, command])
    return flat


func _unflatten(flat: PackedInt32Array) -> Array:
    var commands := _no_commands()
    for index in range(0, flat.size(), 2):
        commands[flat[index]].append(flat[index + 1])
    return commands


func _new_seed() -> int:
    return night_seed if night_seed != 0 else randi()


func _save_replay() -> void:
    if _log.is_empty() or _replay.get("lobby", false):
        _log.clear()
        return
    DirAccess.make_dir_recursive_absolute(REPLAY_DIR)
    var file := FileAccess.open("%s/night-%d.json" % [REPLAY_DIR, Time.get_unix_time_from_system()],
            FileAccess.WRITE)
    if file:
        file.store_string(JSON.stringify(replay()))
    var names := Array(DirAccess.get_files_at(REPLAY_DIR))
    names.sort()
    for index in names.size() - KEPT_REPLAYS:
        DirAccess.remove_absolute("%s/%s" % [REPLAY_DIR, names[index]])
    _log.clear()


## Carries looks into a new simulation. Should two players end up in the same colour (a
## newcomer's default), the later slot takes the first free one; every peer resolves it the
## same way.
func _apply_looks(looks: PackedInt32Array) -> void:
    for slot in simulation.players.size():
        var player := simulation.players[slot]
        if looks.size() >= slot * 2 + 2:
            if looks[slot * 2] >= 0:
                player.color = looks[slot * 2]
            if looks[slot * 2 + 1] >= 0:
                player.hat = looks[slot * 2 + 1]
    for slot in simulation.players.size():
        var player := simulation.players[slot]
        for earlier in slot:
            if simulation.players[earlier].color == player.color:
                for color in Looks.COLORS.size():
                    if simulation.color_free(color, player):
                        player.color = color
                        break
                break


func _save_looks(player: SimPlayer) -> void:
    if looks_path == "":
        return
    var config := ConfigFile.new()
    config.set_value("looks", "color", player.color)
    config.set_value("looks", "hat", player.hat)
    config.save(looks_path)


## [colour, hat] saved by this player last time, [] if none.
func _saved_looks() -> Array:
    var config := ConfigFile.new()
    if looks_path == "" or config.load(looks_path) != OK:
        return []
    return [int(config.get_value("looks", "color", 0)), int(config.get_value("looks", "hat", Looks.DEFAULT_HAT))]
