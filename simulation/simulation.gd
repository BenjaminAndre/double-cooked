class_name Simulation
extends RefCounted
## The whole game state and its rules, advanced one tick at a time (GDD §9.1).
## Deterministic: the same level, spawns, seed and commands always give the same result.
## Nothing here reads Input, the clock or the scene tree.

const TICK_RATE := 30
## Walking speed in world units per second. Neighbouring anchors are about one unit apart.
const WALK_SPEED := 10.0

## What a player can do in one tick. The move values match SimLevel.Direction.
## New commands go at the end, so saved replays keep their meaning.
## RELEASE is the interact key going up, for throwing (GDD §8).
## EAT eats or drinks what is held, on its own key so it never happens by accident (GDD §5.1).
enum Command { MOVE_UP, MOVE_DOWN, MOVE_LEFT, MOVE_RIGHT, INTERACT, DEBUG_DAMAGE, CANCEL, RELEASE, EAT }

const EXTINGUISHER := &"extincteur"
## Cans leave a hand at this height and are caught at that one.
const THROW_HEIGHT := 1.0
const CATCH_HEIGHT := 0.6

var tick := 0
var level: SimLevel
var players: Array[SimPlayer] = []
## One per level station, in the same order.
var stations: Array[SimStation] = []
## Cans in the air.
var projectiles: Array[SimProjectile] = []
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
        players[slot].bmi = rules.start_bmi
    for kind in level.station_kinds:
        stations.append(SimStation.new(kind))
        if kind == &"frigo":
            stations[-1].beers = rules.fridge_beers
    var per_player := []
    per_player.resize(players.size())
    per_player.fill(0)
    stats = {"served": 0, "angry": 0, "walk_outs": 0, "beers": 0, "fires": 0, "cans_hit": 0,
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
        if station.kind == &"frigo" and station.beers < rules.fridge_beers:
            station.restock += 1
            if station.restock >= rules.fridge_restock:
                station.restock = 0
                station.beers += 1
    _advance_fires()
    for player in players:
        _check_menu(player)
        _check_aim(player)
    crowd.advance(tick, players.size(), rng, events)
    _customers_throw()
    _advance_projectiles()
    tick += 1
    _count(events)
    if players.size() > 1 and players.all(func(p: SimPlayer) -> bool: return p.down):
        _end(&"lost", &"crew_down")
    elif crowd.mood >= rules.riot:
        _end(&"lost", &"riot")
    elif tick >= rules.night_ticks and crowd.line.is_empty():
        _end(&"won", &"closing")


## Fingerprint of the state, to check that two runs (or host and client) agree.
func state_hash() -> int:
    var state: Array = [tick, rng.state]
    for p in players:
        state.append(p.fingerprint())
    for station in stations:
        state.append(station.fingerprint())
    for projectile in projectiles:
        state.append(projectile.fingerprint())
    state.append(crowd.fingerprint())
    state.append(outcome)
    state.append(stats)
    return hash(state)


func _apply(player: SimPlayer, command: int) -> void:
    if player.stun > 0:
        return
    if player.aim >= 0 and _use_aim(player, command):
        return
    if command == Command.INTERACT and player.item and player.item.kind == Menu.BEER \
            and not player.down and player.menu == SimLevel.NONE:
        # Holding a beer: aim first; a quick release still uses the station (see _use_aim).
        player.aim = 0
        player.aim_ticks = 0
        return
    if player.menu != SimLevel.NONE and _use_menu(player, command):
        return
    match command:
        Command.MOVE_UP, Command.MOVE_DOWN, Command.MOVE_LEFT, Command.MOVE_RIGHT:
            _queue_move(player, command)
        Command.INTERACT:
            _interact(player)
        Command.DEBUG_DAMAGE:
            _hurt(player)
        Command.EAT:
            if Menu.edible(player.item):
                _consume(player)


## While a station menu is open, the arrows move the selection instead of the player,
## interact takes the selected option and cancel closes the menu (GDD §5.4).
## Returns whether the command was used by the menu.
func _use_menu(player: SimPlayer, command: int) -> bool:
    var options: Array = Menu.STATION_OPTIONS[stations[player.menu].kind]
    match command:
        Command.MOVE_UP, Command.MOVE_LEFT:
            player.menu_choice = posmod(player.menu_choice - 1, options.size())
        Command.MOVE_DOWN, Command.MOVE_RIGHT:
            player.menu_choice = posmod(player.menu_choice + 1, options.size())
        Command.INTERACT:
            var station := stations[player.menu]
            var option: StringName = options[player.menu_choice]
            player.menu = SimLevel.NONE
            if _menu_action(station, player) == &"":
                return true
            match station.kind:
                &"sauces":
                    player.item.sauce = option
                &"frigo":
                    if option == Menu.BEER:
                        if station.beers == 0:
                            return true
                        station.beers -= 1
                    player.item = SimItem.new(option)
                &"viandes":
                    player.item = SimItem.new(option)
        Command.CANCEL:
            player.menu = SimLevel.NONE
        _:
            return false
    return true


## A menu closes if its player falls (except at the FRIGO, where a beer gets them back up),
## moves away or the station catches fire.
func _check_menu(player: SimPlayer) -> void:
    if player.menu == SimLevel.NONE:
        return
    var station := stations[player.menu]
    if (player.down and station.kind != &"frigo") or player.is_moving() \
            or level.node_stations[player.node] != player.menu or station.burning:
        player.menu = SimLevel.NONE


## While a beer is held down, the arrows aim instead of moving: left and right pick a customer
## in line; up switches to the teammates (left and right then pick one), down goes back to the
## line. Releasing early uses the station as a tap would; releasing after SimRules.aim_hold
## throws the beer. Escape stops aiming and keeps the beer. Returns whether the command was
## used by the aim.
func _use_aim(player: SimPlayer, command: int) -> bool:
    var mates := players.filter(func(p: SimPlayer) -> bool: return p != player)
    match command:
        Command.MOVE_UP:
            if player.aim_player < 0 and not mates.is_empty():
                player.aim_player = mates[0].slot
        Command.MOVE_DOWN:
            player.aim_player = -1
        Command.MOVE_LEFT, Command.MOVE_RIGHT:
            var step := 1 if command == Command.MOVE_RIGHT else -1
            if player.aim_player >= 0:
                var index := mates.find(players[player.aim_player])
                player.aim_player = mates[posmod(index + step, mates.size())].slot
            else:
                player.aim = clampi(player.aim + step, 0, maxi(crowd.line.size() - 1, 0))
        Command.RELEASE:
            var held_long := player.aim_ticks >= rules.aim_hold
            var target := player.aim
            var mate := player.aim_player
            player.aim = -1
            player.aim_player = -1
            if held_long:
                _throw_beer(player, target, mate)
            else:
                _interact(player)
        Command.CANCEL:
            player.aim = -1
            player.aim_player = -1
        Command.INTERACT:
            pass
        _:
            return false
    return true


## Aiming counts up while held, and stops if the player falls, is stunned or loses the beer.
func _check_aim(player: SimPlayer) -> void:
    if player.aim < 0:
        return
    if player.down or player.stun > 0 or not player.item or player.item.kind != Menu.BEER:
        player.aim = -1
        player.aim_player = -1
    else:
        player.aim_ticks += 1


## To the customer at place target in line, or to teammate mate (a slot) if mate >= 0, aimed
## where they stand now.
func _throw_beer(player: SimPlayer, target: int, mate: int) -> void:
    var to := level.queue_position(target) + Vector3.UP * CATCH_HEIGHT
    if mate >= 0:
        to = player_position(players[mate]) + Vector3.UP * CATCH_HEIGHT
    var can := SimProjectile.new(SimProjectile.BEER, player_position(player) + Vector3.UP * THROW_HEIGHT,
            to, tick, rules.beer_flight)
    can.by = player.slot
    can.at_player = mate
    projectiles.append(can)
    player.item = null
    events.append({"type": &"beer_thrown", "by": player.slot, "target": target, "mate": mate})


## A beer landing on the crew: whoever stands close enough catches it. Knocked out, they drink
## it and get back up; otherwise it goes to an empty hand, or falls if their hand is full.
func _beer_to_mate(can: SimProjectile) -> void:
    var landing := Vector3(can.to.x, 0, can.to.z)
    for player in players:
        if player.slot == can.by or player_position(player).distance_to(landing) > rules.can_radius:
            continue
        if player.down:
            player.item = SimItem.new(Menu.BEER)
            _consume(player)
            events.append({"type": &"revived", "slot": player.slot, "by": can.by})
            return
        if not player.item:
            player.item = SimItem.new(Menu.BEER)
            events.append({"type": &"beer_caught", "slot": player.slot})
            return
    events.append({"type": &"beer_missed"})


## Customers who leave angry throw a can on the way out, at whoever served them badly; past
## SimRules.can_mood waiting customers throw at random, more often the worse the mood. Without
## a culprit, the can goes to the player closest to the counter (GDD §8).
func _customers_throw() -> void:
    for event in events.duplicate():
        if event.type in [&"angry", &"walk_out"]:
            _throw_can(event.index, event.by)
    var anger := (float(crowd.mood) / rules.riot - rules.can_mood) / (1.0 - rules.can_mood)
    if anger > 0.0 and not crowd.line.is_empty() and rng.randf() < anger / rules.can_every:
        _throw_can(rng.randi_range(0, crowd.line.size() - 1), -1)


## A can from the customer at index, aimed where the target stands now. target is a slot,
## or -1 for the standing player closest to the counter.
func _throw_can(index: int, target: int) -> void:
    var aimed: SimPlayer = players[target] if target >= 0 and not players[target].down else null
    if not aimed:
        for player in players:
            if not player.down and (not aimed or player_position(player).distance_to(level.queue_front)
                    < player_position(aimed).distance_to(level.queue_front)):
                aimed = player
    if not aimed:
        return
    var from := level.queue_position(index) + Vector3.UP * THROW_HEIGHT
    projectiles.append(SimProjectile.new(SimProjectile.CAN, from, player_position(aimed), tick, rules.can_flight))
    events.append({"type": &"can_thrown", "at": aimed.slot})


## Cans land when their time is up: a beer goes to whoever stands where it falls, an empty can
## costs a heart to every player close to where it falls (no bump).
func _advance_projectiles() -> void:
    for can in projectiles.duplicate():
        if tick + 1 < can.lands_at():
            continue
        projectiles.erase(can)
        if can.kind == SimProjectile.BEER and can.at_player >= 0:
            _beer_to_mate(can)
        elif can.kind == SimProjectile.BEER:
            var index := level.queue_index_at(can.to)
            if index >= 0 and index < crowd.line.size():
                crowd.give_beer(index, can.by, events)
            else:
                events.append({"type": &"beer_missed"})
        else:
            var landing := Vector3(can.to.x, 0, can.to.z)
            for player in players:
                if player_position(player).distance_to(landing) <= rules.can_radius:
                    _hurt(player)
                    events.append({"type": &"can_hit", "slot": player.slot})


## Where a player is on the floor, between two nodes while walking.
func player_position(player: SimPlayer) -> Vector3:
    var at := level.positions[player.node]
    if player.is_moving():
        at = at.lerp(level.positions[player.path[0]], float(player.progress) / player.edge_ticks)
    return at


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
## A player who tries to enter an occupied node stops, and stuns its occupant (GDD §5.3).
## A stunned player stands frozen, even halfway along an edge.
func _advance(player: SimPlayer) -> void:
    if player.stun > 0:
        player.stun -= 1
        return
    if player.is_moving():
        player.progress += 1
        if player.progress < player.edge_ticks:
            return
        player.node = player.path.pop_front()
        _burn(player)
        player.progress = 0
        player.edge_ticks = 0
    if player.path.is_empty():
        return
    var target: int = player.path[0]
    var occupant := _occupant(target)
    if occupant:
        player.path.clear()
        events.append({"type": &"bump", "by": player.slot, "target": occupant.slot})
        occupant.stun = rules.bump_stun
        return
    # Every BMI point over a healthy start makes the walk slower (GDD §5.1); thinner isn't faster.
    player.edge_ticks = rules.crawl_ticks if player.down \
            else roundi(_walk_ticks(player.node, target) * (1.0 + maxi(player.bmi - rules.start_bmi, 0) * rules.bmi_slowdown))


## What interacting would do right now, for the on-screen hint; &"" when it would do nothing.
## One of: throw, choose (a menu is open), extinguish, fry, lift, take, sauce, fridge, meat,
## trash, serve, take_extinguisher, return_extinguisher. _interact() only acts when this isn't
## empty, so the two always agree. A knocked-out player can only use the FRIGO. Eating and
## drinking have their own key and hint (eat_action).
func action_for(player: SimPlayer) -> StringName:
    if player.aim >= 0:
        return &"throw" if player.aim_ticks >= rules.aim_hold else &""
    if player.menu != SimLevel.NONE:
        return &"choose"
    return _station_action(player)


## What the eat key would do: &"eat", &"drink", or &"" with nothing edible in hand.
func eat_action(player: SimPlayer) -> StringName:
    if not Menu.edible(player.item):
        return &""
    return &"drink" if player.item.kind in Menu.DRINKS else &"eat"


func _station_action(player: SimPlayer) -> StringName:
    var index := level.node_stations[player.node]
    if index == SimLevel.NONE:
        return &""
    var station := stations[index]
    var held := player.item
    if station.burning:
        return &"extinguish" if held and held.kind == EXTINGUISHER and not player.down else &""
    if player.down and station.kind != &"frigo":
        return &""
    match station.kind:
        &"cuisson_1":
            if not station.basket:
                return &"fry"
            if station.frying:
                var in_time := station.cook >= Fryer.FIRST_FRY_MIN and station.cook <= Fryer.FIRST_FRY_MAX
                return &"lift" if in_time or not held else &""
            return &"take" if not held else &""
        &"cuisson_2":
            if not station.basket:
                return &"fry" if Fryer.can_second_fry(held) else &""
            return &"lift" if not held else &""
        &"sauces", &"frigo", &"viandes":
            return _menu_action(station, player)
        &"poubelle":
            return &"trash" if held else &""
        &"caisse":
            var front := crowd.front()
            return &"serve" if held and front else &""
        &"extincteur":
            if not held:
                return &"take_extinguisher"
            return &"return_extinguisher" if held.kind == EXTINGUISHER else &""
    return &""


## Whether a menu station can serve the player's hand: SAUCES needs a food without sauce,
## FRIGO and VIANDES an empty hand.
func _menu_action(station: SimStation, player: SimPlayer) -> StringName:
    var held := player.item
    match station.kind:
        &"sauces":
            return &"sauce" if Menu.takes_sauce(held) else &""
        &"frigo":
            return &"fridge" if not held else &""
        &"viandes":
            return &"meat" if not held else &""
    return &""


## Uses the station at the player's last reached node with what they hold (GDD §5.4). Menu
## stations open their menu; the choice is made in _use_menu().
func _interact(player: SimPlayer) -> void:
    var action := action_for(player)
    if action == &"":
        return
    var index := level.node_stations[player.node]
    var station := stations[index]
    var held := player.item
    if station.burning:
        station.burning = false
        station.burn_ticks = 0
        events.append({"type": &"fire_out", "station": index, "by": player.slot})
        return
    match station.kind:
        &"cuisson_1":
            Fryer.use_first(station, player)
        &"cuisson_2":
            Fryer.use_second(station, player)
        &"sauces", &"frigo", &"viandes":
            player.menu = index
            player.menu_choice = 0
        &"poubelle":
            player.item = null
        &"caisse":
            if crowd.serve(held, player.slot, events):
                player.item = null
        &"extincteur":
            if not held:
                player.item = SimItem.new(EXTINGUISHER)
            elif held.kind == EXTINGUISHER:
                player.item = null


## Eating or drinking what is held: a heart back and a BMI point (back on their feet if that
## was what they lacked), even at full health (GDD §5.1).
func _consume(player: SimPlayer) -> void:
    player.item = null
    player.health = mini(player.health + 1, SimPlayer.MAX_HEALTH)
    player.bmi += 1
    # Back up once they have a heart and aren't starving any more.
    player.down = player.health == 0 or player.bmi <= rules.knockout_bmi
    events.append({"type": &"fattened", "slot": player.slot})


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
        _knock_out(player)


func _knock_out(player: SimPlayer) -> void:
    if player.down:
        return
    player.down = true
    # A falling player finishes the step under way, and nothing more.
    player.path.resize(1 if player.is_moving() else 0)
    events.append({"type": &"knocked_out", "slot": player.slot})


## Every SimRules.moves_per_bmi nodes walked burn a BMI point; at knockout_bmi the player
## collapses, undernourished (GDD §5.1). Crawling burns nothing.
func _burn(player: SimPlayer) -> void:
    if player.down:
        return
    player.walked += 1
    if player.walked < rules.moves_per_bmi:
        return
    player.walked = 0
    player.bmi -= 1
    events.append({"type": &"thinner", "slot": player.slot})
    if player.bmi <= rules.knockout_bmi:
        _knock_out(player)


func _count(step_events: Array[Dictionary]) -> void:
    for event in step_events:
        match event.type:
            &"served":
                stats.served += 1
            &"angry":
                stats.angry += 1
            &"can_hit":
                stats.cans_hit += 1
            &"beer_gift":
                stats.beers += 1
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
