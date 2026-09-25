class_name Simulation
extends RefCounted
## The whole game state and its rules, advanced one tick at a time (GDD §9.1).
## Deterministic: the same level, spawns, seed and commands always give the same result.
## Nothing here reads Input, the clock or the scene tree.

const TICK_RATE := 30
## Walking speed in world units per second. Neighbouring anchors are about one unit apart.
const WALK_SPEED := 10.0

## What a player can do in one tick. The move values match SimLevel.Direction.
enum Command { MOVE_UP, MOVE_DOWN, MOVE_LEFT, MOVE_RIGHT, FOCUS_LEFT, FOCUS_RIGHT, INTERACT, DEBUG_DAMAGE }

var tick := 0
var level: SimLevel
var players: Array[SimPlayer] = []
## One per level station, in the same order.
var stations: Array[SimStation] = []
## What happened during the last step, for the display, e.g. {"type": &"bump", "by": 0, "target": 1}.
var events: Array[Dictionary] = []
## The only source of randomness, so that a seed replays the same night.
var rng := RandomNumberGenerator.new()
var rules: SimRules
var crowd: SimCrowd
## &"won" at closing time, &"lost" when the room riots; &"" while the night goes on.
var outcome := &""


## spawns[slot] is the node where that player starts; its size is the player count.
func _init(p_level: SimLevel, spawns: PackedInt32Array, p_seed: int, p_rules: SimRules = null) -> void:
    level = p_level
    rng.seed = p_seed
    rules = p_rules if p_rules else SimRules.new()
    crowd = SimCrowd.new(rules)
    for slot in spawns.size():
        players.append(SimPlayer.new(slot, spawns[slot]))
    for kind in level.station_kinds:
        stations.append(SimStation.new(kind))


## Minutes since 18:00 on the night's clock.
func clock_minutes() -> int:
    return mini(tick, rules.night_ticks) * 600 / rules.night_ticks


## Advances one tick. commands[slot] lists that player's commands for this tick, in press order.
## Players are resolved in slot order, which is the tie-break for simultaneous moves.
## Once the night is over, nothing changes any more.
func step(commands: Array) -> void:
    events.clear()
    if outcome != &"":
        tick += 1
        return
    for slot in mini(commands.size(), players.size()):
        for command: int in commands[slot]:
            _apply(players[slot], command)
    for player in players:
        _advance(player)
    for station in stations:
        Fryer.advance(station)
    for player in players:
        for item in player.hands:
            Fryer.advance_item(item)
    crowd.advance(tick, players.size(), rng, events)
    tick += 1
    if crowd.mood >= rules.riot:
        _end(&"lost")
    elif tick >= rules.night_ticks:
        _end(&"won")


## Fingerprint of the state, to check that two runs (or host and client) agree.
func state_hash() -> int:
    var state: Array = [tick, rng.state]
    for p in players:
        state.append(p.fingerprint())
    for station in stations:
        state.append(station.fingerprint())
    state.append(crowd.fingerprint())
    state.append(outcome)
    return hash(state)


func _apply(player: SimPlayer, command: int) -> void:
    match command:
        Command.MOVE_UP, Command.MOVE_DOWN, Command.MOVE_LEFT, Command.MOVE_RIGHT:
            _queue_move(player, command)
        Command.FOCUS_LEFT:
            player.focus = SimPlayer.Hand.LEFT
        Command.FOCUS_RIGHT:
            player.focus = SimPlayer.Hand.RIGHT
        Command.INTERACT:
            _interact(player)
        Command.DEBUG_DAMAGE:
            player.health = maxi(player.health - 1, 0)


## Extends the planned path from its last node. Heading back to a node already planned
## cuts the loop instead, so the path never doubles back on itself.
func _queue_move(player: SimPlayer, direction: int) -> void:
    var from: int = player.node if player.path.is_empty() else player.path.back()
    var to := level.neighbour(from, direction)
    if to == SimLevel.NONE:
        return
    var index := player.path.find(to)
    if index != -1:
        player.path.resize(index + 1)
    else:
        player.path.append(to)


## Walks along the current edge, then sets off towards the next planned node.
## A player who tries to enter an occupied node bumps its occupant and stops (GDD §5.3).
func _advance(player: SimPlayer) -> void:
    if player.is_moving():
        player.progress += 1
        if player.progress < player.edge_ticks:
            return
        player.node = player.path.pop_front()
        player.progress = 0
        player.edge_ticks = 0
    if player.path.is_empty():
        return
    var target: int = player.path[0]
    var occupant := _occupant(target)
    if occupant:
        player.path.clear()
        events.append({"type": &"bump", "by": player.slot, "target": occupant.slot})
        var dropped := occupant.drop_unfocused()
        if dropped:
            events.append({"type": &"drop", "slot": occupant.slot, "item": dropped.kind})
        return
    player.edge_ticks = _walk_ticks(player.node, target)


## Uses the station at the player's last reached node with the focused hand (GDD §5.4).
func _interact(player: SimPlayer) -> void:
    var index := level.node_stations[player.node]
    if index == SimLevel.NONE:
        return
    var station := stations[index]
    var held := player.focused_item()
    match station.kind:
        &"soins":
            player.health = SimPlayer.MAX_HEALTH
        &"cuisson_1":
            Fryer.use_first(station, player)
        &"cuisson_2":
            Fryer.use_second(station, player)
        &"sauces":
            if held and held.kind in Fryer.FINISHED:
                held.sauce = true
        &"poubelle":
            player.set_focused_item(null)
        &"caisse":
            if crowd.serve(held, events):
                player.set_focused_item(null)


func _end(result: StringName) -> void:
    outcome = result
    events.append({"type": &"night_over", "outcome": result})


func _occupant(node: int) -> SimPlayer:
    for other in players:
        if other.occupied_node() == node:
            return other
    return null


func _walk_ticks(from: int, to: int) -> int:
    var distance := level.positions[from].distance_to(level.positions[to])
    return maxi(1, roundi(distance * TICK_RATE / WALK_SPEED))
