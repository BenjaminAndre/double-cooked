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
## Beyond this, a slow frame drops time instead of stepping the simulation in a burst.
const MAX_STEPS_PER_FRAME := 5
## A client this many ticks behind the host steps faster to catch up.
const CLIENT_LAG_TICKS := 3
## The host sends a state fingerprint this often, so clients notice a desync.
const CHECK_EVERY := Simulation.TICK_RATE
## Restarts an offline night with one or two players on this keyboard.
const TOGGLE_DUO_KEY := KEY_F2
const REPLAY_DIR := "user://replays"
const KEPT_REPLAYS := 20

signal began

## Parent of the level's Anchor nodes.
@export var anchors_root: Node3D
## Where each player slot starts; also the maximum player count.
@export var spawns: Array[Anchor] = []
@export var players_parent: Node3D
## 0 picks a new random seed for each night.
@export var night_seed := 0
## Where the customers line up; its position and line_step become the simulation's queue.
@export var queue: CustomersView

var simulation: Simulation
## How far we are towards the next tick, for views that draw between ticks.
var alpha := 0.0
var role := Role.OFFLINE
## Fingerprint checks where this client differed from the host. Should stay 0.
var desyncs := 0

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
var _replay := {}
## tick, slot, command, tick, slot, command...
var _log := PackedInt32Array()
var _accumulator := 0.0


func _ready() -> void:
    # Update the Player views before their own _process reads them.
    process_priority = -1
    _link.command_received.connect(_on_command_received)
    _link.night_began.connect(_on_night_began)
    _link.tick_received.connect(_on_tick_received)
    play_local(1)


func _exit_tree() -> void:
    _save_replay()


## Offline night with one or two players on this keyboard.
func play_local(local_players: int) -> void:
    var slots := PackedInt32Array()
    for slot in local_players:
        slots.append(slot)
    _begin(local_players, slots, _new_seed(), Role.OFFLINE)


## Host: starts an online night with every connected peer. The host is slot 0, the others
## follow in peer id order.
func host_online() -> void:
    var peers := multiplayer.get_peers()
    peers.sort()
    peers.resize(mini(peers.size(), spawns.size() - 1))
    var seed_value := _new_seed()
    _peer_slots.clear()
    for index in peers.size():
        _peer_slots[peers[index]] = index + 1
    _begin(peers.size() + 1, PackedInt32Array([0]), seed_value, Role.HOST)
    for peer in peers:
        _link.begin_night.rpc_id(peer, peers.size() + 1, _peer_slots[peer], seed_value)


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
    return data


func _unhandled_input(event: InputEvent) -> void:
    var key := event as InputEventKey
    if role == Role.OFFLINE and key and key.pressed and not key.echo:
        var restart := -1
        if key.physical_keycode == TOGGLE_DUO_KEY:
            restart = 2 if _local_slots.size() == 1 else 1
        elif simulation.outcome != &"" and key.physical_keycode in [KEY_ENTER, KEY_KP_ENTER]:
            restart = _local_slots.size()
        if restart != -1:
            play_local(restart)
            get_viewport().set_input_as_handled()
            return
    var command := _input.read(event)
    if not command.is_empty():
        submit(command[0], command[1])


func _process(delta: float) -> void:
    _accumulator += delta
    var due := int(_accumulator / TICK_TIME)
    _accumulator -= due * TICK_TIME
    if role == Role.CLIENT:
        # Follow the host: step what has arrived, a bit faster when lagging behind.
        var backlog := _received.size()
        if backlog > CLIENT_LAG_TICKS:
            due = maxi(due, backlog - CLIENT_LAG_TICKS)
        due = mini(due, backlog)
    if due > MAX_STEPS_PER_FRAME:
        due = MAX_STEPS_PER_FRAME
        _accumulator = 0.0
    for i in due:
        _step()
    _show(_accumulator / TICK_TIME)


func _step() -> void:
    var tick := simulation.tick
    var commands: Array
    var check := 0
    if role == Role.CLIENT:
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
        push_warning("Desync with the host at tick %d" % simulation.tick)
    for event in simulation.events:
        if event.type == &"bump":
            _views[event.target].show_bump()
        elif event.type == &"fattened":
            _views[event.slot].show_fat_change(true)
        elif event.type == &"thinner":
            _views[event.slot].show_fat_change(false)


func _begin(player_count: int, local_slots: PackedInt32Array, seed_value: int, p_role: Role) -> void:
    _save_replay()
    role = p_role
    for view in _views:
        view.queue_free()
    _views.clear()
    var level := LevelReader.read(anchors_root)
    if queue:
        level.queue_front = queue.global_position
        level.queue_step = queue.line_step
    _station_views = LevelReader.stations(anchors_root)
    var spawn_nodes := PackedInt32Array()
    var spawn_names := []
    for slot in player_count:
        spawn_nodes.append(level.find(spawns[slot].name))
        spawn_names.append(String(spawns[slot].name))
    simulation = Simulation.new(level, spawn_nodes, seed_value)
    _replay = {"version": 2, "level": owner.scene_file_path if owner else "", "seed": seed_value,
            "spawns": spawn_names}
    _log.clear()
    _local_slots = local_slots
    _input = LocalInput.new(local_slots.size())
    _pending = _no_commands()
    _received.clear()
    _accumulator = 0.0
    desyncs = 0
    for slot in player_count:
        var view: Player = PLAYER_SCENE.instantiate()
        view.is_local_player = slot in local_slots
        view.level_start_bmi = simulation.rules.start_bmi
        view.hungry_below = simulation.rules.knockout_bmi + 2
        view.pseudo = "You" if player_count == 1 else "P%d" % (slot + 1)
        players_parent.add_child(view)
        _views.append(view)
    _show(0.0)
    began.emit()


func _on_command_received(peer_id: int, command: int) -> void:
    if role == Role.HOST and _peer_slots.has(peer_id):
        _pending[_peer_slots[peer_id]].append(command)


func _on_night_began(player_count: int, slot: int, seed_value: int) -> void:
    _begin(player_count, PackedInt32Array([slot]), seed_value, Role.CLIENT)


func _on_tick_received(tick: int, check: int, commands: PackedInt32Array) -> void:
    if role == Role.CLIENT:
        _received[tick] = [check, commands]


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
        var hint := ""
        if not player.is_moving() and simulation.outcome == &"":
            var station := simulation.level.node_stations[player.node]
            if station != SimLevel.NONE:
                highlighted[station] = true
            var action := simulation.action_for(player)
            if action != &"":
                hint = "%s : %s" % [_input.interact_key_name(local_index), ItemNames.action(action)]
                if action == &"throw" and simulation.players.size() > 1:
                    hint += "  ·  haut : équipier"
            if player.item and player.item.kind == Menu.BEER and player.aim < 0 and not player.down:
                # A beer can always be thrown: hold the key to aim at the line.
                var throw := "%s maintenu : lancer" % _input.interact_key_name(local_index)
                hint = throw if hint == "" else "%s\n%s" % [hint, throw]
        _views[slot].show_hint(hint)
        var options: Array = []
        if player.menu != SimLevel.NONE:
            var menu_station := simulation.stations[player.menu]
            for option: StringName in Menu.STATION_OPTIONS[menu_station.kind]:
                var word := ItemNames.word(option)
                if option == Menu.BEER:
                    word += " ×%d" % menu_station.beers
                options.append(word)
        _views[slot].show_menu(options, player.menu_choice)
    for index in _station_views.size():
        _station_views[index].show_station(simulation.stations[index], simulation.rules)
        _station_views[index].set_highlighted(highlighted.has(index))


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
    if _log.is_empty():
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
