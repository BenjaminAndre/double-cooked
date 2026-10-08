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
## A new host waits this long (seconds) for the others to come back, then goes on without them.
const RECONNECT_TIMEOUT := 15.0
## Over the head of a player who left.
const GONE := "(parti)"

signal began
## A short message for the HUD, e.g. once a replay is saved.
signal notice(text: String)
## A big announcement, e.g. the boss walking in.
signal announced(text: String)
## A player at this keyboard used the lobby's TÉLÉPHONE (Menu.PHONE).
signal phone_used(choice: StringName)

## The kitchen for one or two players (the artist's base layout), and the bigger ones (GDD §5.2):
## a night is played in the first one with a spawn for everyone.
@export var kitchen_room: GridRoom
@export var bigger_kitchens: Array[GridRoom] = []
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
## Who this player is across connections, kept with their looks: a dropped player gets their
## slot back when they rejoin.
var player_id := ""
## The host is gone and a new one is taking over: the night stands still meanwhile.
var reconnecting := false
## Which night of a campaign this is (GDD §4.2), 0 for a single night or the lobby.
var campaign_night := 0
## The campaign just ended on a night further than any before, on this browser.
var new_record := false

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
## Each slot's player_id ("" when unknown), as the host shares it.
var _slot_ids := PackedStringArray()
## Host: what each peer said in hello(): [player_id, look].
var _hellos := {}
## How the night started (count, seed, looks), to replay it for someone joining late.
var _start := {}
## Players who joined during the night, as [tick, node, colour, hat], and those still to be
## added, by tick.
var _joins: Array = []
var _pending_joins := {}
## New host: the slots expected back, and how long it still waits for them.
var _expected := {}
var _reconnect_left := 0.0
## The room being played: the kitchen or the lobby.
var _room: GridRoom
## Nodes at a station with nothing to do tonight: their floor squares are dark.
var _idle_nodes := {}
var _web_page: WebPage
## campaign_record(), read once from looks_path.
var _record := {}


func _ready() -> void:
    # Update the Player views before their own _process reads them.
    process_priority = -1
    _link.command_received.connect(_on_command_received)
    _link.night_began.connect(_on_night_began)
    _link.tick_received.connect(_on_tick_received)
    _link.player_left.connect(_on_player_left)
    _link.player_back.connect(_on_player_back)
    _link.hello_received.connect(_on_hello)
    _link.caught_up.connect(_on_caught_up)
    _link.player_joined.connect(_on_player_joined)
    _link.night_full.connect(func() -> void: notice.emit("Partie pleine : prochaine nuit"))
    player_id = _load_player_id()
    _web_page = WebPage.new()
    _web_page.hidden_beat.connect(_on_hidden_beat)
    add_child(_web_page)
    play_lobby(1)


func _exit_tree() -> void:
    _save_replay()


## Offline lobby with one or two players on this keyboard.
func play_lobby(local_players: int) -> void:
    _play_offline(local_players, true)


## Offline night with one or two players on this keyboard; campaign_night 0 for a single night.
func play_local(local_players: int, p_campaign_night := 0) -> void:
    _play_offline(local_players, false, p_campaign_night)


## Host: everyone connected into the lobby, e.g. when someone joins.
func host_lobby() -> void:
    _host_begin(true)


## Host: starts an online night with every connected peer.
func host_online(p_campaign_night := 0) -> void:
    _host_begin(false, p_campaign_night)


## Once a night is over (Enter, or the host's Enter online): a campaign goes on to its next
## night when this one was held; otherwise everyone goes back to the lobby.
func continue_after_night() -> void:
    var next := campaign_night + 1 if campaign_night > 0 and simulation.outcome == &"won" else 0
    if role == Role.HOST:
        if next > 0:
            host_online(next)
        else:
            host_lobby()
    elif next > 0:
        play_local(_local_slots.size(), next)
    else:
        play_lobby(_local_slots.size())


func _play_offline(local_players: int, lobby: bool, p_campaign_night := 0) -> void:
    var slots := PackedInt32Array()
    for slot in local_players:
        slots.append(slot)
    _begin(local_players, slots, _new_seed(), Role.OFFLINE, lobby, _current_looks(), p_campaign_night)


## The host is slot 0. The others keep their slot from one night to the next, and newcomers
## follow in peer id order; each keeps their looks (a newcomer's from their hello).
func _host_begin(lobby: bool, p_campaign_night := 0) -> void:
    var by_peer := {1: _look_of(_local_slots[0] if not _local_slots.is_empty() else 0)}
    for peer in _peer_slots:
        by_peer[peer] = _look_of(_peer_slots[peer])
    var connected := multiplayer.get_peers()
    connected.sort()
    _peer_order = _peer_order.filter(func(peer: int) -> bool: return peer in connected)
    for peer in connected:
        if not peer in _peer_order:
            _peer_order.append(peer)
    _peer_order.resize(mini(_peer_order.size(), _max_players(lobby) - 1))
    _peer_slots.clear()
    var looks := PackedInt32Array(by_peer[1])
    var ids := PackedStringArray([player_id])
    for index in _peer_order.size():
        var peer := _peer_order[index]
        _peer_slots[peer] = index + 1
        var hello: Array = _hellos.get(peer, ["", PackedInt32Array()])
        var look: Array = by_peer.get(peer, Array(hello[1]) if hello[1].size() == 2 else [-1, -1])
        looks.append_array(look)
        ids.append(hello[0])
    var seed_value := _new_seed()
    var count := _peer_order.size() + 1
    _begin(count, PackedInt32Array([0]), seed_value, Role.HOST, lobby, looks, p_campaign_night)
    _slot_ids = ids
    for peer in _peer_order:
        _link.begin_night.rpc_id(peer, count, _peer_slots[peer], seed_value, lobby, campaign_night, looks,
                ids)


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
    if lobby and lobby_room:
        return lobby_room.spawn_names().size()
    var most := 0
    for kitchen in kitchens():
        most = maxi(most, kitchen.spawn_names().size())
    return most


## Every kitchen, smallest first.
func kitchens() -> Array[GridRoom]:
    var all: Array[GridRoom] = [kitchen_room]
    all.append_array(bigger_kitchens)
    return all


## The kitchen sized for this many players (GDD §5.2): the artist's layout for one or two, an
## extra lane for three, an extra column for four.
func kitchen_for(player_count: int) -> GridRoom:
    var all := kitchens()
    return all[clampi(player_count - 2, 0, all.size() - 1)]


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


## Host: a peer left. In the lobby, it starts over without them; in a night their player stays,
## idle, marked as gone for everyone, until they come back.
func peer_left(peer_id: int) -> void:
    _hellos.erase(peer_id)
    if role != Role.HOST or not _peer_slots.has(peer_id):
        return
    var slot: int = _peer_slots[peer_id]
    _peer_slots.erase(peer_id)
    if in_lobby:
        host_lobby()
        return
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
        if slot < simulation.players.size() and simulation.players[slot].menu != SimLevel.NONE:
            return true
    return false


## The night so far, in the shape Scenario.from_replay() reads.
func replay() -> Dictionary:
    var data := _replay.duplicate()
    data.ticks = simulation.tick
    data.commands = Array(_log)
    if not _joins.is_empty():
        data.joins = _joins.duplicate(true)
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
    # Once a night is over, Enter goes on (online, the host's Lobby does it).
    if role == Role.OFFLINE and key and key.pressed and not key.echo and simulation.outcome != &"" \
            and key.physical_keycode in [KEY_ENTER, KEY_KP_ENTER]:
        continue_after_night()
        get_viewport().set_input_as_handled()
        return
    var command := _input.read(event)
    if not command.is_empty():
        submit(command[0], command[1])


func _process(delta: float) -> void:
    if reconnecting and role == Role.HOST:
        _reconnect_left -= delta
        if _reconnect_left <= 0.0:
            _give_up_waiting()
    _advance()
    _show(_accumulator / TICK_TIME)


## Steps the ticks that are due by the wall clock, within STEP_BUDGET_USEC. Nothing moves while
## a new host is taking over.
func _advance() -> void:
    var now := Time.get_ticks_usec()
    _accumulator += (now - _last_usec) / 1_000_000.0
    _last_usec = now
    if reconnecting:
        _accumulator = 0.0
        return
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
        _apply_joins(tick)
        commands = _unflatten(data[1])
    else:
        # Joining before this tick: their key presses count from the next one.
        commands = _pending
        _apply_joins(tick)
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
            announced.emit("Le boss arrive !")
        elif event.type == &"look" and _local_slots.size() > 0 and event.slot == _local_slots[0]:
            _save_looks(simulation.players[event.slot])
        elif event.type == &"phone" and event.slot in _local_slots:
            # Deferred: the lobby may start over, which replaces this simulation.
            phone_used.emit.call_deferred(event.choice)
        elif event.type == &"start_night" and role != Role.CLIENT:
            var first := 1 if event.get("campaign", false) else 0
            if role == Role.HOST:
                host_online.call_deferred(first)
            else:
                play_local.call_deferred(_local_slots.size(), first)
        elif event.type == &"night_over" and campaign_night > 0 and event.outcome == &"lost":
            new_record = _save_record()
    return true


## looks: colour, hat per slot (-1 keeps the default), carried from the lobby to the night.
## p_campaign_night: which night of a campaign, 0 for a single night (ignored in the lobby).
func _begin(player_count: int, local_slots: PackedInt32Array, seed_value: int, p_role: Role,
        lobby := false, looks := PackedInt32Array(), p_campaign_night := 0) -> void:
    _save_replay()
    role = p_role
    in_lobby = lobby and lobby_room != null
    for view in _views:
        view.queue_free()
    _views.clear()
    var room := lobby_room if in_lobby else kitchen_for(player_count)
    _room = room
    var root := room.anchors_root()
    var level := LevelReader.read(root)
    if queue and not in_lobby:
        if room.queue_front_position() != Vector3.INF:
            queue.global_position = room.queue_front_position()
        level.queue_front = queue.global_position
        level.queue_step = queue.line_step
        for point in queue.line_points:
            level.queue_points.append(queue.global_transform * point)
    _station_views = LevelReader.stations(root)
    var spawn_names := room.spawn_names().slice(0, player_count)
    var spawn_nodes := PackedInt32Array()
    for spawn_name: String in spawn_names:
        spawn_nodes.append(level.find(spawn_name))
    campaign_night = 0 if in_lobby else p_campaign_night
    new_record = false
    var rules := Campaign.rules_for(campaign_night)
    rules.lobby = in_lobby
    simulation = Simulation.new(level, spawn_nodes, seed_value, rules)
    simulation.apply_looks(looks)
    _idle_nodes.clear()
    for node in level.node_stations.size():
        var station := level.node_stations[node]
        if station != SimLevel.NONE and not Menu.station_in_use(level.station_kinds[station], rules.menu):
            _idle_nodes[node] = true
    room.camera.current = true
    _replay = {"version": 2, "level": owner.scene_file_path if owner else "", "seed": seed_value,
            "spawns": spawn_names, "looks": Array(looks), "lobby": in_lobby, "night": campaign_night,
            "room": String(room.name)}
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
    _start = {"count": player_count, "seed": seed_value, "looks": looks, "night": campaign_night}
    _joins.clear()
    _pending_joins.clear()
    _expected.clear()
    reconnecting = false
    _slot_ids = PackedStringArray()
    _slot_ids.resize(player_count)
    if role != Role.CLIENT and not local_slots.is_empty():
        _slot_ids[local_slots[0]] = player_id
    for slot in player_count:
        _add_view(slot)
    _show(0.0)
    began.emit()
    if in_lobby and _local_slots.size() > 0:
        var saved := _saved_looks()
        if not saved.is_empty():
            submit(0, Looks.command(saved[0], saved[1]))


func _on_command_received(peer_id: int, command: int) -> void:
    # A player catching up may press keys before they are in the night: those are dropped.
    if role == Role.HOST and _peer_slots.has(peer_id) and _peer_slots[peer_id] < _pending.size():
        _pending[_peer_slots[peer_id]].append(command)


func _on_night_began(player_count: int, slot: int, seed_value: int, lobby: bool, p_campaign_night: int,
        looks: PackedInt32Array, ids: PackedStringArray) -> void:
    _begin(player_count, PackedInt32Array([slot]), seed_value, Role.CLIENT, lobby, looks, p_campaign_night)
    _slot_ids = ids


func _on_tick_received(tick: int, check: int, commands: PackedInt32Array) -> void:
    if role == Role.CLIENT:
        _received[tick] = [check, commands]
        _last_tick_usec = Time.get_ticks_usec()


func _on_player_left(slot: int) -> void:
    if _left.has(slot) or slot >= _views.size():
        return
    _left[slot] = true
    _views[slot].pseudo = GONE
    notice.emit("%s est parti" % Looks.player_name(simulation.players[slot].color))


func _on_player_back(slot: int) -> void:
    if not _left.has(slot):
        return
    _left.erase(slot)
    if slot < _views.size():
        _views[slot].pseudo = ""
        notice.emit("%s est revenu" % Looks.player_name(simulation.players[slot].color))


## A view for this slot's player.
func _add_view(slot: int) -> void:
    var view: Player = PLAYER_SCENE.instantiate()
    view.is_local_player = slot in _local_slots
    view.level_start_bmi = simulation.rules.start_bmi
    view.rules = simulation.rules
    view.hungry_below = simulation.rules.knockout_bmi + 2
    # The colour stands for the player: no name over their head.
    view.pseudo = GONE if _left.has(slot) else ""
    players_parent.add_child(view)
    _views.append(view)


# Online sessions (GDD §9.1): someone joining a night under way plays at once (the host sends
# how it started and every command since, which they replay); a dropped player gets their slot
# back; if the host leaves, the player with the lowest slot still there takes over.

## Client, once connected: tells the host who this player is.
func say_hello() -> void:
    var look := PackedInt32Array()
    if simulation and not _local_slots.is_empty() and _local_slots[0] < simulation.players.size():
        var player := simulation.players[_local_slots[0]]
        look = PackedInt32Array([player.color, player.hat])
    else:
        look = PackedInt32Array(_saved_looks())
    _link.hello.rpc_id(1, player_id, look)


## Host: a player said hello. In the lobby everyone starts over together; during a night a
## returning player gets their slot back, a new one joins on a free spawn, if there is one.
func _on_hello(peer: int, id: String, look: PackedInt32Array) -> void:
    if role != Role.HOST:
        return
    _hellos[peer] = [id, look]
    if in_lobby:
        host_lobby()
        return
    var slot := _slot_ids.find(id) if id != "" else -1
    if slot >= 0 and slot not in _peer_slots.values() and slot not in _local_slots:
        _peer_slots[peer] = slot
        _expected.erase(slot)
        var was_left := _left.has(slot)
        _on_player_back(slot)
        _send_catch_up(peer, slot)
        if was_left:
            for other in _peer_slots:
                if other != peer:
                    _link.mark_back.rpc_id(other, slot)
        _check_reconnected()
        return
    if _slot_ids.size() >= _max_players(false):
        _link.full.rpc_id(peer)
        return
    # Before the next tick, on every peer.
    var join := [simulation.tick, _free_spawn(), look[0] if look.size() == 2 else -1,
            look[1] if look.size() == 2 else -1]
    for other in _peer_slots:
        _link.join_player.rpc_id(other, join[0], join[1], join[2], join[3], id)
    _peer_slots[peer] = _slot_ids.size()
    _add_join(join, id)
    _send_catch_up(peer, _peer_slots[peer])


func _send_catch_up(peer: int, slot: int) -> void:
    var start := _start.duplicate()
    start.log = _log
    start.joins = _joins
    start.tick = simulation.tick
    _link.catch_up.rpc_id(peer, start, slot, _slot_ids, PackedInt32Array(_left.keys()))


## Client joining or rejoining a night under way: replays it from the start, as fast as the
## step budget allows, then follows the host from its current tick.
func _on_caught_up(start: Dictionary, slot: int, ids: PackedStringArray, left: PackedInt32Array) -> void:
    _begin(int(start.count), PackedInt32Array([slot]), int(start.seed), Role.CLIENT, false,
            PackedInt32Array(start.looks), int(start.get("night", 0)))
    _slot_ids = ids
    for gone in left:
        _left[gone] = true
        if gone < _views.size():
            _views[gone].pseudo = GONE
    for join: Array in start.joins:
        _add_join(join)
    var by_tick := {}
    var log: PackedInt32Array = start.log
    for index in range(0, log.size(), 3):
        if not by_tick.has(log[index]):
            by_tick[log[index]] = PackedInt32Array()
        by_tick[log[index]].append_array([log[index + 1], log[index + 2]])
    for tick in int(start.tick):
        _received[tick] = [0, by_tick.get(tick, PackedInt32Array())]


func _on_player_joined(tick: int, node: int, color: int, hat: int, id: String) -> void:
    if role != Role.CLIENT:
        return
    _add_join([tick, node, color, hat])
    _slot_ids.append(id)


## join: [tick, node, colour, hat]. id: known only by whoever adds the slot's player id.
func _add_join(join: Array, id := "") -> void:
    _joins.append(join)
    if not _pending_joins.has(join[0]):
        _pending_joins[join[0]] = []
    _pending_joins[join[0]].append(join)
    if id != "":
        _slot_ids.append(id)


func _apply_joins(tick: int) -> void:
    for join: Array in _pending_joins.get(tick, []):
        var slot := simulation.add_player(join[1], join[2], join[3])
        _add_view(slot)
        if _slot_ids.size() <= slot:
            _slot_ids.resize(slot + 1)
    _pending_joins.erase(tick)


## Where a player joining now starts: the first spawn nobody stands on.
func _free_spawn() -> int:
    var occupied := {}
    for player in simulation.players:
        occupied[player.occupied_node()] = true
    for joining: Array in _joins:
        occupied[joining[1]] = true
    for spawn_name in _room.spawn_names():
        var node := simulation.level.find(spawn_name)
        if not occupied.has(node):
            return node
    for node in simulation.level.positions.size():
        if not occupied.has(node):
            return node
    return 0


## Client: the host is gone. The night stands still; the player with the lowest slot still
## here takes over. Returns whether that's this peer.
func host_lost() -> bool:
    if role != Role.CLIENT:
        return false
    reconnecting = true
    # Whatever the host had sent is played first, so the new host keeps as much as it can.
    while _received.has(simulation.tick):
        _step()
    if not _left.has(0):
        _on_player_left(0)
    for slot in simulation.players.size():
        if not _left.has(slot):
            return slot in _local_slots
    return true


## The new host, once its session is open: keeps the night where it stands and waits for the
## others (see RECONNECT_TIMEOUT), who say hello again and catch up with it.
func become_host() -> void:
    role = Role.HOST
    _peer_slots.clear()
    _hellos.clear()
    _received.clear()
    _pending = _no_commands()
    if in_lobby:
        host_lobby()
        return
    _expected.clear()
    for slot in simulation.players.size():
        if not _left.has(slot) and slot not in _local_slots:
            _expected[slot] = true
    _reconnect_left = RECONNECT_TIMEOUT
    _check_reconnected()


func _check_reconnected() -> void:
    if reconnecting and _expected.is_empty():
        reconnecting = false
        _last_usec = Time.get_ticks_usec()


func _give_up_waiting() -> void:
    for slot: int in _expected.keys():
        _on_player_left(slot)
        _link.mark_left.rpc(slot)
    _expected.clear()
    _check_reconnected()


## This player's id, made once and kept with the looks; a new one each time without a file.
func _load_player_id() -> String:
    var config := ConfigFile.new()
    var loaded := looks_path != "" and config.load(looks_path) == OK
    var id: String = config.get_value("player", "id", "") if loaded else ""
    if id == "":
        id = "%08x%08x" % [randi(), randi()]
        if looks_path != "":
            config.set_value("player", "id", id)
            config.save(looks_path)
    return id


## alpha: how far we are towards the next tick, to keep walking smooth between ticks.
func _show(p_alpha: float) -> void:
    alpha = p_alpha
    for slot in _views.size():
        _views[slot].show_state(simulation.players[slot], simulation.level, p_alpha)
    # Each player at this keyboard sees the station they stand at highlighted, and what their
    # interact key would do there.
    var highlighted := {}
    # Station -> the hints of the player standing at it, shown in its bubble (a fryer's).
    var bubble_hints := {}
    for local_index in _local_slots.size():
        var slot := _local_slots[local_index]
        if slot >= simulation.players.size():
            # Catching up: not in the night yet.
            continue
        var player := simulation.players[slot]
        # [key, verb] rows.
        var hints: Array = []
        var interact_key := _input.interact_key_name(local_index)
        if not player.is_moving() and simulation.outcome == &"":
            var station := simulation.level.node_stations[player.node]
            if station != SimLevel.NONE:
                highlighted[station] = true
            var action := simulation.action_for(player)
            if action in [&"door_wait", &"door_host", &"asleep"]:
                # Nothing to press: only why nothing happens (the door shut, a customer asleep).
                hints.append(["", ItemNames.action(action)])
            elif action == &"choose":
                pass  # In the menu's bubble.
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
        # At a fryer showing its bubble, the hints go in it: over the head, the bubble hides them.
        var at := simulation.level.node_stations[player.node] if not player.is_moving() else SimLevel.NONE
        if at != SimLevel.NONE and _station_views[at].has_bubble():
            bubble_hints[at] = hints
            hints = []
        _views[slot].show_hint(hints)
        var options: Array = []
        var disabled: Array = []
        if player.menu != SimLevel.NONE:
            var menu_station := simulation.stations[player.menu]
            var menu_options: Array = Menu.options(menu_station.kind, simulation.rules.menu)
            for index in menu_options.size():
                var option: StringName = menu_options[index]
                if menu_station.kind == &"peinture":
                    # The characters' faces; a teammate's is greyed out.
                    options.append(PaperFigure.portrait(Looks.character(index)))
                    if not simulation.color_free(index, player):
                        disabled.append(index)
                    continue
                var picture := ItemIcons.picture(option)
                if option == Menu.BEER:
                    options.append([picture, "×%d" % menu_station.beers])
                    if menu_station.beers == 0:
                        disabled.append(index)
                    continue
                if picture:
                    options.append(picture)
                    continue
                var word := ItemNames.word(option)
                if option == Menu.PHONE_DUO:
                    word = "seul" if _local_slots.size() > 1 else "à deux"
                elif option == Menu.PHONE_LEAVE and role == Role.OFFLINE:
                    disabled.append(index)
                options.append(word)
        var menu_at: Vector3 = _station_views[player.menu].centre() if player.menu != SimLevel.NONE else Vector3.ZERO
        _views[slot].show_menu(options, player.menu_choice, disabled, menu_at, interact_key)
    var taken := {}
    for player in simulation.players:
        taken[player.node] = true
    _room.show_squares(taken, _idle_nodes)
    var open_menus := {}
    for player in simulation.players:
        open_menus[player.menu] = true
    for index in _station_views.size():
        _station_views[index].show_station(simulation.stations[index], simulation.rules)
        _station_views[index].show_bubble_hints(bubble_hints.get(index, []))
        # The floor squares show where everyone stands, where the room has them.
        _station_views[index].set_highlighted(highlighted.has(index) and not _room.squares)
        _station_views[index].set_menu_open(open_menus.has(index))
    # Neighbouring fryers' bubbles never hide one another.
    var bubbles := []
    for view in _station_views:
        if view.bubble():
            bubbles.append(view.bubble())
    CookingBubble.separate(bubbles)


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


func _save_looks(player: SimPlayer) -> void:
    if looks_path == "":
        return
    var config := ConfigFile.new()
    # Keeps what else is saved there, like the player id.
    config.load(looks_path)
    config.set_value("looks", "color", player.color)
    config.set_value("looks", "hat", player.hat)
    config.save(looks_path)


## [colour, hat] saved by this player last time, [] if none.
func _saved_looks() -> Array:
    var config := ConfigFile.new()
    if looks_path == "" or config.load(looks_path) != OK:
        return []
    return [int(config.get_value("looks", "color", 0)), int(config.get_value("looks", "hat", Looks.DEFAULT_HAT))]


## The team's best campaign on this browser (GDD §4.2): {"night": the night it fell on, 0 if
## none yet, "colors": the colours of that crew}.
func campaign_record() -> Dictionary:
    if not _record.is_empty():
        return _record
    var config := ConfigFile.new()
    _record = {"night": 0, "colors": []}
    if looks_path != "" and config.load(looks_path) == OK:
        _record = {"night": int(config.get_value("campaign", "best", 0)),
                "colors": Array(config.get_value("campaign", "colors", []))}
    return _record


## Keeps this campaign if it went further than the record. Returns whether it did.
func _save_record() -> bool:
    if looks_path == "" or campaign_night <= campaign_record().night:
        return false
    var config := ConfigFile.new()
    config.load(looks_path)
    config.set_value("campaign", "best", campaign_night)
    var colors := []
    for player in simulation.players:
        colors.append(player.color)
    config.set_value("campaign", "colors", colors)
    config.save(looks_path)
    _record = {"night": campaign_night, "colors": colors}
    return true
