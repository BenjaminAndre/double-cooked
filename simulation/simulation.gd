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

const EXTINGUISHER := &"extincteur"

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
## &"won" at closing time, &"lost" otherwise; &"" while the night goes on.
var outcome := &""
## Why the night ended: &"closing", &"riot" or &"crew_down".
var outcome_reason := &""
## Counters for the end-of-night recap. Per-player lists are indexed by slot.
var stats := {}


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
    var per_player := []
    per_player.resize(players.size())
    per_player.fill(0)
    stats = {"dishes": 0, "bad_dishes": 0, "orders": 0, "walk_outs": 0, "fires": 0,
            "bumps": per_player.duplicate(), "knockouts": per_player.duplicate(),
            "revives": per_player.duplicate()}


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
    _advance_fires()
    crowd.advance(tick, players.size(), rng, events)
    tick += 1
    _count(events)
    if players.size() > 1 and players.all(func(p: SimPlayer) -> bool: return p.down):
        _end(&"lost", &"crew_down")
    elif crowd.mood >= rules.riot:
        _end(&"lost", &"riot")
    elif tick >= rules.night_ticks:
        _end(&"won", &"closing")


## Fingerprint of the state, to check that two runs (or host and client) agree.
func state_hash() -> int:
    var state: Array = [tick, rng.state]
    for p in players:
        state.append(p.fingerprint())
    for station in stations:
        state.append(station.fingerprint())
    state.append(crowd.fingerprint())
    state.append(outcome)
    state.append(stats)
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
            _hurt(player)


## Extends the planned path from its last node. Heading back to a node already planned
## cuts the loop instead, so the path never doubles back on itself.
func _queue_move(player: SimPlayer, direction: int) -> void:
    if player.down:
        # Crawling is slow, so no queue: one node at a time, chosen once the last one is reached.
        if not player.is_moving():
            var next := level.neighbour(player.node, direction)
            player.path.assign([next] if next != SimLevel.NONE else [])
        return
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
    player.edge_ticks = rules.crawl_ticks if player.down else _walk_ticks(player.node, target)


## What interacting would do right now, for the on-screen hint; &"" when it would do nothing.
## One of: revive, extinguish, heal, fry, lift, take, sauce, trash, serve, take_extinguisher,
## return_extinguisher. _interact() only acts when this isn't empty, so the two always agree.
func action_for(player: SimPlayer) -> StringName:
    if not player.down and _fallen_neighbour(player.node):
        return &"revive"
    var index := level.node_stations[player.node]
    if index == SimLevel.NONE:
        return &""
    var station := stations[index]
    var held := player.focused_item()
    if station.burning:
        return &"extinguish" if held and held.kind == EXTINGUISHER and not player.down else &""
    if player.down and station.kind != &"soins":
        return &""
    match station.kind:
        &"soins":
            return &"heal" if player.down or player.health < SimPlayer.MAX_HEALTH else &""
        &"cuisson_1":
            if not station.basket:
                return &"fry"
            if station.frying:
                var rests := station.cook >= Fryer.FIRST_FRY_MIN and station.cook <= Fryer.FIRST_FRY_MAX
                return &"lift" if rests or not held else &""
            return &"take" if not held else &""
        &"cuisson_2":
            if not station.basket:
                return &"fry" if held and held.kind == Fryer.FRIES_BLANCHED else &""
            return &"lift" if not held else &""
        &"sauces":
            return &"sauce" if held and held.kind in Fryer.FINISHED and not held.sauce else &""
        &"poubelle":
            return &"trash" if held else &""
        &"caisse":
            var front := crowd.front()
            return &"serve" if held and front and SimCrowd.dish_of(held) in front.order else &""
        &"extincteur":
            if not held:
                return &"take_extinguisher"
            return &"return_extinguisher" if held.kind == EXTINGUISHER else &""
    return &""


## Getting a knocked-out neighbour back up comes first; otherwise the player uses the station
## at their last reached node with the focused hand (GDD §5.4). A knocked-out player can
## only use SOINS.
func _interact(player: SimPlayer) -> void:
    if action_for(player) == &"":
        return
    if not player.down:
        var fallen := _fallen_neighbour(player.node)
        if fallen:
            fallen.down = false
            fallen.health = rules.revive_health
            events.append({"type": &"revived", "slot": fallen.slot, "by": player.slot})
            return
    var index := level.node_stations[player.node]
    if index == SimLevel.NONE:
        return
    var station := stations[index]
    var held := player.focused_item()
    if station.burning:
        if held and held.kind == EXTINGUISHER and not player.down:
            station.burning = false
            station.burn_ticks = 0
            events.append({"type": &"fire_out", "station": index, "by": player.slot})
        return
    if player.down and station.kind != &"soins":
        return
    match station.kind:
        &"soins":
            player.health = SimPlayer.MAX_HEALTH
            player.down = false
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
        &"extincteur":
            if not held:
                player.set_focused_item(SimItem.new(EXTINGUISHER))
            elif held.kind == EXTINGUISHER:
                player.set_focused_item(null)


## Fryers left in the oil too long catch fire; fires burn whoever stands at them and spread
## to a neighbouring station if left alone (GDD §8).
func _advance_fires() -> void:
    for index in stations.size():
        var station := stations[index]
        if station.frying and station.cook > Fryer.window(station).y + rules.fire_margin:
            station.basket = null
            station.frying = false
            station.cook = 0
            _ignite(index, &"fire_started")
    for index in stations.size():
        var station := stations[index]
        if not station.burning:
            continue
        station.burn_ticks += 1
        if station.burn_ticks >= rules.fire_spread_after:
            station.burn_ticks = 0
            var candidates := _spread_candidates(index)
            if not candidates.is_empty():
                _ignite(candidates[rng.randi_range(0, candidates.size() - 1)], &"fire_spread")
    for player in players:
        var index := level.node_stations[player.node]
        if player.is_moving() or index == SimLevel.NONE or not stations[index].burning:
            player.exposure = 0
            continue
        player.exposure += 1
        if player.exposure >= rules.fire_damage_every:
            player.exposure = 0
            _hurt(player)


func _ignite(index: int, event_type: StringName) -> void:
    var station := stations[index]
    station.burning = true
    station.burn_ticks = 0
    station.basket = null
    station.frying = false
    events.append({"type": event_type, "station": index})


## Stations reachable from a node linked to one of this station's nodes, in index order.
func _spread_candidates(index: int) -> Array[int]:
    var found: Array[int] = []
    for node in level.positions.size():
        if level.node_stations[node] != index:
            continue
        for neighbour in level.links[node]:
            if neighbour == SimLevel.NONE:
                continue
            var other := level.node_stations[neighbour]
            if other != SimLevel.NONE and other != index and not other in found \
                    and not stations[other].burning and not stations[other].kind in rules.fireproof:
                found.append(other)
    found.sort()
    return found


func _hurt(player: SimPlayer) -> void:
    if player.health == 0:
        return
    player.health -= 1
    events.append({"type": &"hurt", "slot": player.slot})
    if player.health == 0:
        player.down = true
        # A falling player finishes the step under way, and nothing more.
        player.path.resize(1 if player.is_moving() else 0)
        events.append({"type": &"knocked_out", "slot": player.slot})


func _fallen_neighbour(node: int) -> SimPlayer:
    for neighbour in level.links[node]:
        if neighbour == SimLevel.NONE:
            continue
        var other := _occupant(neighbour)
        if other and other.down and not other.is_moving():
            return other
    return null


func _count(step_events: Array[Dictionary]) -> void:
    for event in step_events:
        match event.type:
            &"served":
                stats.dishes += 1
                if not event.good:
                    stats.bad_dishes += 1
            &"order_done":
                stats.orders += 1
            &"walk_out":
                stats.walk_outs += 1
            &"fire_started", &"fire_spread":
                stats.fires += 1
            &"bump":
                stats.bumps[event.by] += 1
            &"knocked_out":
                stats.knockouts[event.slot] += 1
            &"revived":
                stats.revives[event.by] += 1


func _end(result: StringName, reason: StringName) -> void:
    outcome = result
    outcome_reason = reason
    events.append({"type": &"night_over", "outcome": result, "reason": reason})


func _occupant(node: int) -> SimPlayer:
    for other in players:
        if other.occupied_node() == node:
            return other
    return null


func _walk_ticks(from: int, to: int) -> int:
    var distance := level.positions[from].distance_to(level.positions[to])
    return maxi(1, roundi(distance * TICK_RATE / WALK_SPEED))
