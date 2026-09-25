class_name Night
extends Node
## Runs one night: owns the Simulation, feeds it the local players' key presses tick by tick,
## and shows its state through the Player scenes.

const PLAYER_SCENE := preload("res://gameplay/player.tscn")
const TICK_TIME := 1.0 / Simulation.TICK_RATE
## Beyond this, a slow frame drops time instead of stepping the simulation in a burst.
const MAX_STEPS_PER_FRAME := 5
## Restarts the night with one or two players on this keyboard (GDD §10, local multiplayer).
const TOGGLE_DUO_KEY := KEY_F2

## Parent of the level's Anchor nodes.
@export var anchors_root: Node3D
## Where each player slot starts.
@export var spawns: Array[Anchor] = []
@export var players_parent: Node3D
@export var night_seed := 0

var simulation: Simulation

var _input: LocalInput
var _views: Array[Player] = []
## Commands per slot, waiting for the next tick.
var _pending: Array = []
var _accumulator := 0.0


func _ready() -> void:
    # Update the Player views before their own _process reads them.
    process_priority = -1
    start(1)


func start(local_players: int) -> void:
    for view in _views:
        view.queue_free()
    _views.clear()
    var level := LevelReader.read(anchors_root)
    var spawn_nodes := PackedInt32Array()
    for slot in local_players:
        spawn_nodes.append(level.find(spawns[slot].name))
    simulation = Simulation.new(level, spawn_nodes, night_seed)
    _input = LocalInput.new(local_players)
    _pending = _no_commands()
    _accumulator = 0.0
    for slot in local_players:
        var view: Player = PLAYER_SCENE.instantiate()
        view.pseudo = "You" if local_players == 1 else "P%d" % (slot + 1)
        players_parent.add_child(view)
        _views.append(view)
    _show(0.0)


func _unhandled_input(event: InputEvent) -> void:
    var key := event as InputEventKey
    if key and key.pressed and not key.echo and key.physical_keycode == TOGGLE_DUO_KEY:
        start(2 if simulation.players.size() == 1 else 1)
        return
    var command := _input.read(event)
    if not command.is_empty():
        _pending[command[0]].append(command[1])


func _process(delta: float) -> void:
    _accumulator += delta
    var steps := 0
    while _accumulator >= TICK_TIME:
        _accumulator -= TICK_TIME
        simulation.step(_pending)
        _pending = _no_commands()
        for event in simulation.events:
            if event.type == &"bump":
                _views[event.target].show_bump()
        steps += 1
        if steps == MAX_STEPS_PER_FRAME:
            _accumulator = 0.0
    _show(_accumulator / TICK_TIME)


## alpha: how far we are towards the next tick, to keep walking smooth between ticks.
func _show(alpha: float) -> void:
    for slot in _views.size():
        _views[slot].show_state(simulation.players[slot], simulation.level, alpha)


func _no_commands() -> Array:
    var commands := []
    for slot in simulation.players.size():
        commands.append([])
    return commands
