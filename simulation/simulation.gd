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
## Commands from LOOK up choose a colour and a hat (see Looks.command), e.g. when a player's
## saved looks are applied as they enter the lobby.
const LOOK := 100
## Commands from DEBUG up are the host's test tools (F4, GDD §9.3), see debug_command(): they
## go through the command stream like any key, so guests and replays follow them.
const DEBUG := 1000
const DEBUG_SPAN := 100
## The test tools. MOOD's argument is a SimCrowd.Level; CLOCK's a ClockJump; KNOCK_OUT, HUNGRY
## and FAT take a slot. New tools go at the end, so saved replays keep their meaning.
enum DebugTool { MOOD, CLOCK, BOSS, FILL_LINE, FRIDGE, FIRES_OUT, FIRE, HEAL, KNOCK_OUT, HUNGRY, FAT, GREASE,
        INSPECTION, PIGEON, CAR }
enum ClockJump { HALF_HOUR, BOSS, CLOSING }

const EXTINGUISHER := &"extincteur"
## The yellow BB gun kept under each CAISSE (GDD §8).
const GUN := &"carabine"
## The stations with hot oil: sliding into one burns (GDD §8).
const FRYERS: Array[StringName] = [&"cuisson_1", &"cuisson_2", &"cuisson_viande"]
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
## Tonight's events: the fridge breaking down, and so on (GDD §6.4).
var night_events: NightEvents
## &"won" at closing time, &"lost" otherwise; &"" while the night goes on.
var outcome := &""
## Why the night ended: &"closing", &"riot", &"crew_down", &"afsca" (closed by a surprise
## inspection) or &"tutorial" (its last step done).
var outcome_reason := &""
## Counters for the end-of-night recap. Per-player lists are indexed by slot.
var stats := {}
## Ticks the night's clock was moved forward by (DebugTool.CLOCK): the night runs on
## night_tick(), while tick keeps counting the steps.
var clock_skip := 0
## Grease on the floor (GDD §8): node -> ticks before it dries.
var grease := {}
## Pigeons in the kitchen (GDD §8), when the next one comes (a night tick, -1 not drawn yet),
## and how many came so far tonight.
var pigeons: Array[SimPigeon] = []
var next_pigeon := -1
var _pigeons_seen := 0
## Rubble left by the car (GDD §6.4): nodes nobody can walk onto any more.
var blocked := {}
## The tutorial's steps (SimRules.tutorial), null in any other night.
var tutorial: Tutorial


## spawns[slot] is the node where that player starts; its size is the player count.
func _init(p_level: SimLevel, spawns: PackedInt32Array, p_seed: int, p_rules: SimRules = null) -> void:
    level = p_level
    rng.seed = p_seed
    rules = p_rules if p_rules else SimRules.new()
    crowd = SimCrowd.new(rules, p_seed)
    night_events = NightEvents.new(rules, crowd)
    crowd.registers = maxi(1, level.station_kinds.count(&"caisse"))
    if rules.tutorial:
        tutorial = Tutorial.new()
    for slot in spawns.size():
        players.append(SimPlayer.new(slot, spawns[slot]))
        players[slot].bmi = rules.start_bmi
        players[slot].color = Looks.default_color(slot)
    for kind in level.station_kinds:
        stations.append(SimStation.new(kind))
        if kind == &"frigo":
            for drink in Menu.DRINKS:
                stations[-1].stock[drink] = rules.fridge_beers
        stations[-1].gun = kind == &"caisse"
    var per_player := []
    per_player.resize(players.size())
    per_player.fill(0)
    stats = {"served": 0, "angry": 0, "walk_outs": 0, "beers": 0, "fires": 0, "cans_hit": 0,
            "boss_came": false, "boss_served": 0,
            "bumps": per_player.duplicate(), "knockouts": per_player.duplicate(),
            "revives": per_player.duplicate(), "served_by": per_player.duplicate(),
            "missed_by": per_player.duplicate(), "beers_by": per_player.duplicate()}


## A player joining the night under way (GDD §9.1), standing at node, in this colour (taken
## as close as possible if a teammate wears it) and hat. Returns their slot. Every peer adds
## them before the same tick, so the nights stay the same.
func add_player(node: int, color: int, hat: int) -> int:
    var player := SimPlayer.new(players.size(), node)
    player.bmi = rules.start_bmi
    player.color = Looks.default_color(player.slot)
    players.append(player)
    apply_looks(PackedInt32Array([color, hat]), player.slot)
    for key in [&"bumps", &"knockouts", &"revives", &"served_by", &"missed_by", &"beers_by"]:
        stats[key].append(0)
    return player.slot


## Colour and hat per player from first (looks holds colour, hat, colour, hat...; -1 keeps
## the default). Should two players end up in the same colour, the later one takes the first
## free one, the same on every peer.
func apply_looks(looks: PackedInt32Array, first := 0) -> void:
    for index in range(0, looks.size() - 1, 2):
        var slot := first + index / 2
        if slot >= players.size():
            break
        if looks[index] >= 0:
            players[slot].color = looks[index]
        if looks[index + 1] >= 0:
            players[slot].hat = looks[index + 1]
    for slot in range(first, players.size()):
        var player := players[slot]
        for earlier in slot:
            if players[earlier].color == player.color:
                for color in Looks.COLORS.size():
                    if color_free(color, player):
                        player.color = color
                        break
                break


## The command for a test tool (DebugTool) with its argument.
static func debug_command(tool: DebugTool, arg := 0) -> int:
    return DEBUG + tool * DEBUG_SPAN + arg


## Where the night's clock stands, in ticks since 18:00: the steps so far, plus the clock moved
## forward by the test tools.
func night_tick() -> int:
    return tick + clock_skip


## Minutes since 18:00 on the night's clock.
func clock_minutes() -> int:
    return mini(night_tick(), rules.night_ticks) * 600 / rules.night_ticks


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
        # Broken down, the FRIGO gets nothing back.
        var short := _shortest_drink(station) if station.kind == &"frigo" else &""
        if short != &"" and night_events.fridge_down == 0:
            # Twice as fast while the colleagues are on their way.
            station.restock += 2 if night_events.group_coming > 0 else 1
            if station.restock >= rules.fridge_restock:
                station.restock = 0
                station.stock[short] += 1
    _advance_fires()
    _dry_grease()
    for player in players:
        _check_menu(player)
        _check_aim(player)
    if not rules.lobby:
        # A fire, grease on the floor, a pigeon: what the AFSCA inspector looks for.
        night_events.advance(night_tick(), events, not grease.is_empty()
                or pigeons.any(func(pigeon: SimPigeon) -> bool: return pigeon.landed())
                or stations.any(func(station: SimStation) -> bool: return station.burning))
        if events.any(func(event: Dictionary) -> bool: return event.type == &"car_crash"):
            _crash()
        if events.any(func(event: Dictionary) -> bool:
                return event.type == &"inspection_over" and not event.passed and not event.closed):
            _spoil()
        crowd.advance(night_tick(), players.size(), rng, events)
        _advance_pigeons()
        if tutorial:
            tutorial.advance(self, events)
        _customers_throw()
    _advance_projectiles()
    tick += 1
    _count(events)
    if rules.lobby:
        return
    if players.size() > 1 and players.all(func(p: SimPlayer) -> bool: return p.down):
        _end(&"lost", &"crew_down")
    elif night_events.closed:
        _end(&"lost", &"afsca")
    elif tutorial and tutorial.finished():
        _end(&"won", &"tutorial")
    elif crowd.mood >= rules.riot:
        _end(&"lost", &"riot")
    elif night_tick() >= rules.night_ticks and crowd.line.is_empty():
        _end(&"won", &"closing")


## Fingerprint of the state, to check that two runs (or host and client) agree.
func state_hash() -> int:
    var state: Array = [tick, clock_skip, rng.state, grease, next_pigeon, _pigeons_seen, blocked, rules.menu]
    for p in players:
        state.append(p.fingerprint())
    for station in stations:
        state.append(station.fingerprint())
    for projectile in projectiles:
        state.append(projectile.fingerprint())
    for pigeon in pigeons:
        state.append(pigeon.fingerprint())
    state.append(crowd.fingerprint())
    state.append(night_events.fingerprint())
    state.append(tutorial.fingerprint() if tutorial else null)
    state.append(outcome)
    state.append(stats)
    return hash(state)


func _apply(player: SimPlayer, command: int) -> void:
    if command >= DEBUG:
        _debug(player, ((command - DEBUG) / DEBUG_SPAN) as DebugTool, (command - DEBUG) % DEBUG_SPAN)
        return
    if command >= LOOK:
        _set_look(player, (command - LOOK) / Looks.HATS.size(), (command - LOOK) % Looks.HATS.size())
        return
    if player.stun > 0 or player.spraying > 0 or player.sliding:
        return
    if player.aim >= 0 and _use_aim(player, command):
        return
    if command == Command.INTERACT and player.item and player.item.kind in Menu.DRINKS + [GUN] \
            and not player.down and player.menu == SimLevel.NONE:
        # Holding a beer or the gun: aim first; a quick release still uses the station (see
        # _use_aim).
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
## interact takes the selected option and cancel closes the menu (GDD §5.4). The options sit on
## a grid (Menu.CELLS): an arrow moves to the neighbouring option, if there is one that way.
## Returns whether the command was used by the menu.
func _use_menu(player: SimPlayer, command: int) -> bool:
    var kind := stations[player.menu].kind
    # Only what tonight's menu needs (Menu.options).
    var options: Array = Menu.options(kind, rules.menu)
    match command:
        Command.MOVE_UP, Command.MOVE_DOWN, Command.MOVE_LEFT, Command.MOVE_RIGHT:
            var step: Vector2i = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT][command]
            var next := Menu.option_at(Menu.CELLS[player.menu_choice] + step, options.size())
            if next >= 0:
                player.menu_choice = next
        Command.INTERACT:
            var station := stations[player.menu]
            var option: StringName = options[player.menu_choice]
            if kind == &"peinture" and not color_free(player.menu_choice, player):
                # Taken by a teammate: greyed out, the menu stays open.
                return true
            player.menu = SimLevel.NONE
            if _menu_action(station, player) == &"":
                return true
            match station.kind:
                &"peinture":
                    _set_look(player, player.menu_choice, player.hat)
                &"casquette":
                    _set_look(player, player.color, Looks.HATS.find(option))
                &"telephone":
                    events.append({"type": &"phone", "choice": option, "slot": player.slot})
                &"porte":
                    events.append({"type": &"start_night", "by": player.slot,
                            "night": {Menu.DOOR_CAMPAIGN: 1, Menu.DOOR_TUTORIAL: Campaign.TUTORIAL}.get(option, 0)})
                &"sauces":
                    player.item.sauce = option
                &"frigo":
                    if option in Menu.DRINKS:
                        if station.left(option) == 0:
                            return true
                        station.stock[option] -= 1
                    player.item = SimItem.new(option)
                &"viandes":
                    player.item = SimItem.new(option)
                &"pain":
                    # A bread, or the one chosen around what is held; one it doesn't go in: nothing.
                    var bread := SimItem.new(option) if not player.item else Recipes.wrap(player.item, option)
                    if bread:
                        player.item = bread
        Command.CANCEL:
            player.menu = SimLevel.NONE
        _:
            return false
    return true


## Whether no other player wears this colour.
func color_free(color: int, player: SimPlayer) -> bool:
    return players.all(func(p: SimPlayer) -> bool: return p == player or p.color != color)


## A new colour (kept if a teammate already wears it) and hat.
func _set_look(player: SimPlayer, color: int, hat: int) -> void:
    if color >= 0 and color < Looks.COLORS.size() and color_free(color, player):
        player.color = color
    if hat >= 0 and hat < Looks.HATS.size():
        player.hat = hat
    events.append({"type": &"look", "slot": player.slot})


## A test tool (F4, GDD §9.3) used by player, with its argument. Only in the kitchen.
## {"type": &"debug", "tool": tool} lets the night know its replay used one.
func _debug(player: SimPlayer, tool: DebugTool, arg: int) -> void:
    if rules.lobby:
        return
    events.append({"type": &"debug", "tool": tool, "by": player.slot})
    var target: SimPlayer = players[arg] if arg < players.size() else null
    match tool:
        DebugTool.MOOD:
            # Calm, tense, hot (the middle of each band), or one walk-out away from the riot.
            var moods := [0, rules.riot * 3 / 8, rules.riot * 5 / 8, rules.riot * 9 / 10]
            crowd.mood = moods[clampi(arg, 0, moods.size() - 1)]
        DebugTool.CLOCK:
            # Forward only: half an hour (the night lasts ten), the boss's time, or closing.
            var to := night_tick() + rules.night_ticks / 20
            if arg == ClockJump.BOSS:
                to = rules.boss_tick()
            elif arg == ClockJump.CLOSING:
                to = rules.night_ticks
            clock_skip += maxi(to - night_tick(), 0)
        DebugTool.BOSS:
            crowd.boss_now(events)
        DebugTool.FILL_LINE:
            crowd.fill_line(events)
        DebugTool.FRIDGE:
            for station in stations:
                if station.kind == &"frigo":
                    for drink in Menu.DRINKS:
                        station.stock[drink] = rules.fridge_beers
                    station.restock = 0
        DebugTool.FIRES_OUT:
            for index in stations.size():
                if stations[index].burning:
                    stations[index].burning = false
                    stations[index].burn_ticks = 0
                    events.append({"type": &"fire_out", "station": index, "by": player.slot})
        DebugTool.FIRE:
            _debug_fire(player)
        DebugTool.HEAL:
            for healed in players:
                healed.health = SimPlayer.MAX_HEALTH
                healed.stun = 0
                if healed.bmi <= rules.knockout_bmi:
                    healed.bmi = rules.start_bmi
                healed.down = false
        DebugTool.KNOCK_OUT when target != null:
            target.health = 0
            _knock_out(target)
        DebugTool.HUNGRY when target != null:
            # One walk more and they collapse.
            target.bmi = rules.knockout_bmi + 1
            events.append({"type": &"thinner", "slot": target.slot})
        DebugTool.FAT when target != null:
            target.bmi = rules.start_bmi + rules.fat_stages[-1]
            events.append({"type": &"fattened", "slot": target.slot})
        DebugTool.GREASE:
            _grease(player.node)
        DebugTool.INSPECTION:
            night_events.surprise_now(events)
        DebugTool.PIGEON:
            _pigeon_arrives()
        DebugTool.CAR:
            night_events.car_now(events)


## A fire at the player's station if it can burn, otherwise at the first CUISSON 1.
func _debug_fire(player: SimPlayer) -> void:
    var index := level.node_stations[player.node]
    if index == SimLevel.NONE or stations[index].burning or stations[index].kind in rules.fireproof:
        index = stations.find_custom(func(station: SimStation) -> bool:
            return station.kind == &"cuisson_1" and not station.burning)
    if index >= 0:
        _ignite(index, &"fire_started")


## Which register the CAISSE station at this index is (SimCrowd.at_register): the one closest
## to the front of the line serves the first customer, the next one the second.
func register_of(station_index: int) -> int:
    var front := level.queue_position(0)
    var distance := func(index: int) -> float:
        var closest := INF
        for node in level.positions.size():
            if level.node_stations[node] == index:
                closest = minf(closest, level.positions[node].distance_to(front))
        return closest
    var own: float = distance.call(station_index)
    var rank := 0
    for other in stations.size():
        if other != station_index and stations[other].kind == &"caisse":
            var theirs: float = distance.call(other)
            if theirs < own or (theirs == own and other < station_index):
                rank += 1
    return rank


## Whether every player but this one stands on a PRÊT tile (GDD §4.1).
func others_ready(player: SimPlayer) -> bool:
    return players.all(func(p: SimPlayer) -> bool:
        return p == player or (not p.is_moving() and level.station_kind_at(p.node) == &"pret"))


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
    if player.item and player.item.kind == GUN:
        return _use_gun_aim(player, command)
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
    if player.down or player.stun > 0 or not player.item or not player.item.kind in Menu.DRINKS + [GUN]:
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
    can.drink = player.item.kind
    can.at_player = mate
    projectiles.append(can)
    player.item = null
    events.append({"type": &"beer_thrown", "by": player.slot, "target": target, "mate": mate})


## A beer landing on the crew: whoever stands close enough drinks it on the spot, keeping what
## they hold: a heart back and fatter (the artist's troll). Knocked out, it gets them back up.
func _beer_to_mate(can: SimProjectile) -> void:
    var landing := Vector3(can.to.x, 0, can.to.z)
    for player in players:
        if player.slot == can.by or player_position(player).distance_to(landing) > rules.can_radius:
            continue
        if player.down:
            player.item = SimItem.new(can.drink)
            _consume(player)
            events.append({"type": &"revived", "slot": player.slot, "by": can.by})
            return
        # Drunk on the spot, whatever they hold: a heart back, and fatter (the artist's troll).
        _drink(player)
        events.append({"type": &"beer_drunk", "slot": player.slot, "by": can.by})
        return
    events.append({"type": &"beer_missed"})


## Customers who leave angry throw a can on the way out, at whoever served them badly; past
## SimRules.can_mood waiting customers throw at random, more often the worse the mood. Without
## a culprit, the can goes to the player closest to the counter (GDD §8).
func _customers_throw() -> void:
    for event in events.duplicate():
        if event.type in [&"angry", &"walk_out"]:
            _throw_can(event.index, event.by)
        elif event.type == &"boss_missed":
            # The boss is always at the counter: a salvo at the crew.
            for can in rules.boss_cans:
                _throw_can(0, _random_standing())
        elif event.type == &"boss_throws":
            _throw_can(0, _random_standing())
    var anger := (float(crowd.mood) / rules.riot - rules.can_mood) / (1.0 - rules.can_mood)
    if anger > 0.0 and not crowd.line.is_empty() and rng.randf() < anger / rules.can_every:
        _throw_can(rng.randi_range(0, crowd.line.size() - 1), -1)


## A standing player's slot picked at random, -1 if the whole crew is down.
func _random_standing() -> int:
    var standing := players.filter(func(p: SimPlayer) -> bool: return not p.down)
    if standing.is_empty():
        return -1
    return standing[rng.randi_range(0, standing.size() - 1)].slot


## A can from the customer at index, aimed where the target stands now. target is a slot,
## or -1 for the standing player closest to the counter.
func _throw_can(index: int, target: int) -> void:
    var aimed: SimPlayer = players[target] if target >= 0 and not players[target].down else null
    if not aimed:
        for player in players:
            if not player.down and (not aimed or player_position(player).distance_to(level.queue_position(0))
                    < player_position(aimed).distance_to(level.queue_position(0))):
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
                crowd.give_drink(index, can.drink, can.by, events)
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
            player.path.assign([next] if next != SimLevel.NONE and not blocked.has(next) else [])
        return
    var from: int = player.node if player.path.is_empty() else player.path.back()
    var to := level.neighbour(from, direction)
    # Rubble (the car crash) is like a wall.
    if to == SimLevel.NONE or blocked.has(to):
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
    if player.spraying > 0:
        player.spraying -= 1
        if player.spraying == 0:
            _put_out(player)
        return
    if player.is_moving():
        player.progress += 1
        if player.progress < player.edge_ticks:
            return
        var from := player.node
        player.node = player.path.pop_front()
        if not rules.lobby:
            _burn(player)
        player.progress = 0
        player.edge_ticks = 0
        _on_floor(player, from)
    if player.path.is_empty():
        return
    var target: int = player.path[0]
    var occupant := _occupant(target)
    if occupant:
        player.path.clear()
        events.append({"type": &"bump", "by": player.slot, "target": occupant.slot})
        occupant.stun = rules.bump_stun
        if player.sliding:
            # Slid into them: both are stunned.
            player.sliding = false
            player.stun = rules.slip_stun
        return
    # A fatter player walks slower, by stages (GDD §5.1); thinner isn't faster. Sliding is fast.
    player.edge_ticks = rules.crawl_ticks if player.down \
            else roundi(_walk_ticks(player.node, target) / rules.walk_speed(player.bmi))
    if player.sliding:
        player.edge_ticks = maxi(1, player.edge_ticks / 2)


## A player just reached a node, from another (GDD §8): the end of a slide hurts at a fryer or
## a fire; grease sends them on (see _slip).
func _on_floor(player: SimPlayer, from: int) -> void:
    var slid := player.sliding
    player.sliding = false
    if slid:
        var index := level.node_stations[player.node]
        if index != SimLevel.NONE and (stations[index].burning or stations[index].kind in FRYERS):
            events.append({"type": &"slid_into", "slot": player.slot, "station": index})
            _hurt(player)
    if grease.has(player.node) and not player.down and not rules.lobby:
        _slip(player, from)
    elif slid:
        player.stun = rules.slip_stun


## Grease underfoot: whatever is held falls (and is lost), and the player slides on to the next
## node the way they were going, if there is one.
func _slip(player: SimPlayer, from: int) -> void:
    events.append({"type": &"slipped", "slot": player.slot, "dropped": player.item.kind if player.item else &""})
    _drop(player)
    player.menu = SimLevel.NONE
    player.aim = -1
    player.aim_player = -1
    player.path.clear()
    var next := SimLevel.NONE
    for direction in 4:
        if level.neighbour(from, direction) == player.node:
            next = level.neighbour(player.node, direction)
    if next == SimLevel.NONE or blocked.has(next):
        player.stun = rules.slip_stun
        return
    player.path.append(next)
    player.sliding = true


## Whether this item was left too long in the oil (the last of its Menu.SECOND_FRY results).
static func _burnt(item: SimItem) -> bool:
    return Menu.SECOND_FRY.values().any(func(results: Array) -> bool: return results[-1] == item.kind)


## A puddle of grease on this node, fresh (GDD §8).
func _grease(node: int) -> void:
    if rules.lobby:
        return
    grease[node] = rules.grease_ticks
    events.append({"type": &"grease", "node": node})


func _dry_grease() -> void:
    for node: int in grease.keys():
        grease[node] -= 1
        if grease[node] <= 0:
            grease.erase(node)


## What interacting would do right now, for the on-screen hint; &"" when it would do nothing.
## One of: throw, choose (a menu is open), extinguish, fry, lift, take, sauce, fridge, meat,
## trash, serve, take_extinguisher, return_extinguisher; in the lobby paint, hat, phone,
## open (the door), and door_wait / door_host, which only explain why the door stays shut.
## _interact() only acts when this isn't empty, so the two always agree. A knocked-out player
## can only use the FRIGO. Eating and drinking have their own key and hint (eat_action).
func action_for(player: SimPlayer) -> StringName:
    if player.spraying > 0:
        return &"spraying"
    if player.aim >= 0:
        if player.aim_ticks < rules.aim_hold:
            return &""
        return &"shoot" if player.item and player.item.kind == GUN else &"throw"
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
    if index == SimLevel.NONE or stations[index].destroyed:
        return &""
    if pigeon_at(index) and not player.down:
        # A pigeon squats the station: shoo it first.
        return &"shoo"
    var station := stations[index]
    var held := player.item
    if station.burning:
        return &"extinguish" if held and held.kind == EXTINGUISHER and not player.down else &""
    if player.down and station.kind != &"frigo":
        return &""
    # A knocked-out player can still crawl to a beer, drinks on the menu or not.
    if not player.down and not Menu.station_in_use(station.kind, rules.menu):
        return &""
    match station.kind:
        &"cuisson_1":
            if not station.basket:
                return &"fry"
            if station.frying:
                var in_time := station.cook >= Fryer.FIRST_FRY_MIN and station.cook <= Fryer.FIRST_FRY_MAX
                return &"lift" if in_time or not held else &""
            return &"take" if not held else &""
        &"cuisson_2", &"cuisson_viande":
            if not station.basket:
                return &"fry" if Fryer.can_second_fry(held, station.kind) else &""
            if Fryer.can_fill(station, held):
                return &"fill"
            return &"lift" if not held else &""
        &"sauces", &"frigo", &"viandes", &"pain", &"peinture", &"casquette", &"telephone":
            return _menu_action(station, player)
        &"porte":
            # Only the host (slot 0) opens the door, once everyone else is ready.
            if player.slot != 0:
                return &"door_host"
            return &"open" if others_ready(player) else &"door_wait"
        &"poubelle":
            return &"trash" if held else &""
        &"caisse":
            # Each CAISSE serves its own customer: two serve the first two in line.
            # The BB gun is kept under it (GDD §8).
            if not held and station.gun:
                return &"take_gun"
            if held and held.kind == GUN:
                return &"return_gun" if not station.gun else &""
            var front := crowd.at_register(register_of(index))
            if front and front.asleep > 0 and not front.boss:
                # Only explains why nothing happens.
                return &"asleep"
            # Only what can be served: a dish or a drink.
            return &"serve" if held and front and Menu.order_key(held) != &"" else &""
        &"extincteur":
            if not held:
                return &"take_extinguisher"
            return &"return_extinguisher" if held.kind == EXTINGUISHER else &""
    return &""


## Whether a menu station can serve the player's hand: SAUCES needs a food without sauce,
## FRIGO and VIANDES an empty hand.
func _menu_action(station: SimStation, player: SimPlayer) -> StringName:
    var held := player.item
    # A menu with nothing in it tonight never opens.
    if Menu.options(station.kind, rules.menu).is_empty():
        return &""
    match station.kind:
        &"sauces":
            return &"sauce" if Menu.takes_sauce(held) else &""
        &"frigo":
            return &"fridge" if not held else &""
        &"viandes":
            if held and Recipes.takes_veg(held) and Menu.veg_on_menu(held.kind, rules.menu):
                return &"veg"
            return &"meat" if not held else &""
        &"pain":
            # A bread; or, holding a good meat or fries, the bread around it (Recipes.wrap).
            if not held:
                return &"bread"
            var options := Menu.options(&"pain", rules.menu)
            var fits := options.any(func(bread: StringName) -> bool: return Recipes.wrap(held, bread) != null)
            return &"wrap" if fits else &""
        &"peinture":
            return &"paint"
        &"casquette":
            return &"hat"
        &"telephone":
            return &"phone"
        &"porte":
            return &"open" if player.slot == 0 and others_ready(player) else &""
    return &""


## Uses the station at the player's last reached node with what they hold (GDD §5.4). Menu
## stations open their menu; the choice is made in _use_menu().
func _interact(player: SimPlayer) -> void:
    var action := action_for(player)
    if action == &"":
        return
    if action == &"shoo":
        _pigeon_leaves(pigeon_at(level.node_stations[player.node]), &"shooed")
        return
    var index := level.node_stations[player.node]
    var station := stations[index]
    var held := player.item
    if station.burning:
        # Spraying takes a while (see _advance).
        player.spraying = rules.spray_ticks
        events.append({"type": &"spraying", "station": index, "by": player.slot})
        return
    match station.kind:
        &"cuisson_1":
            Fryer.use_first(station, player)
        &"cuisson_2", &"cuisson_viande":
            if action == &"fill":
                Fryer.fill(station, held)
            else:
                Fryer.use_second(station, player)
                # Burnt food out of the oil drips grease where the player stands.
                if player.item and player.item != held and _burnt(player.item):
                    _grease(player.node)
        &"viandes" when action == &"veg":
            held.veg = true
        &"sauces", &"frigo", &"viandes", &"pain", &"peinture", &"casquette", &"telephone":
            player.menu = index
            player.menu_choice = 0
        &"porte":
            # A campaign or a single night: its menu decides.
            if action == &"open":
                player.menu = index
                player.menu_choice = 0
        &"poubelle":
            _drop(player)
            events.append({"type": &"trashed", "station": index})
        &"caisse":
            if action == &"take_gun":
                station.gun = false
                player.item = SimItem.new(GUN)
            elif action == &"return_gun":
                station.gun = true
                player.item = null
            elif crowd.serve(held, player.slot, events, register_of(index)):
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
    _drink(player)


## Eating or drinking: a heart back, a BMI point more (GDD §5.1).
func _drink(player: SimPlayer) -> void:
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
        # Spraying it, they don't get burnt.
        if player.is_moving() or player.spraying > 0 or index == SimLevel.NONE or not stations[index].burning:
            player.exposure = 0
            continue
        player.exposure += 1
        if player.exposure >= rules.fire_damage_every:
            player.exposure = 0
            _hurt(player)


## The spray is over: the fire at the player's station is out, and the extinguisher goes back to
## its station by itself (the artist's rule).
func _put_out(player: SimPlayer) -> void:
    var index := level.node_stations[player.node]
    if index != SimLevel.NONE and stations[index].burning:
        stations[index].burning = false
        stations[index].burn_ticks = 0
        events.append({"type": &"fire_out", "station": index, "by": player.slot})
        # The foam and the oil stay on the floor.
        _grease(player.node)
    if player.item and player.item.kind == EXTINGUISHER:
        player.item = null


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
                    and not stations[other].burning and not stations[other].kind in rules.fireproof \
                    and not stations[other].destroyed:
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
    player.spraying = 0
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
                _count_by(&"served_by", event.by)
            &"angry":
                stats.angry += 1
                _count_by(&"missed_by", event.by)
            &"can_hit":
                stats.cans_hit += 1
            &"beer_gift":
                stats.beers += 1
                _count_by(&"beers_by", event.by)
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
            &"boss_arrived":
                stats.boss_came = true
            &"boss_served":
                stats.boss_served += 1
                _count_by(&"served_by", event.by)
            &"boss_missed":
                _count_by(&"missed_by", event.by)


## Counts one for a player, when the event has one (by is -1 for a customer who walked out).
func _count_by(key: StringName, by: int) -> void:
    if by >= 0 and by < stats[key].size():
        stats[key][by] += 1


## The Nuit unique's score (SimRules.score_attack): what was scored so far, nothing once the
## night is lost (GDD §4.3).
func score() -> int:
    return 0 if outcome == &"lost" else crowd.score


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


## Pigeons (GDD §8): one comes now and then; landed on the fries waiting on CUISSON 1, it pecks,
## then flies off with a portion; anywhere else it squats until shooed. A fire chases it off.
func _advance_pigeons() -> void:
    if rules.pigeon_every_min > 0:
        if next_pigeon < 0:
            next_pigeon = night_tick() + _pigeon_delay()
        if night_tick() >= next_pigeon and night_tick() < rules.night_ticks:
            next_pigeon = night_tick() + _pigeon_delay()
            _pigeon_arrives()
    for pigeon in pigeons.duplicate():
        if not pigeon.landed():
            pigeon.flying -= 1
            continue
        var station := stations[pigeon.station]
        if station.burning:
            _pigeon_leaves(pigeon, &"fire")
        elif _waiting_fries(station):
            pigeon.peck -= 1
            if pigeon.peck <= 0:
                station.basket.portions -= 1
                if station.basket.portions == 0:
                    station.basket = null
                _pigeon_leaves(pigeon, &"stole")


## A pigeon flies in, if there is room for one (also a test tool): to the fries waiting on a
## CUISSON 1 if any, otherwise to a station nobody squats, from its own random stream.
func _pigeon_arrives() -> void:
    if pigeons.size() >= rules.max_pigeons:
        return
    var taken := pigeons.map(func(pigeon: SimPigeon) -> int: return pigeon.station)
    var free := range(stations.size()).filter(func(index: int) -> bool:
        return not index in taken and not stations[index].burning and not stations[index].kind in rules.fireproof \
                and not stations[index].destroyed)
    var fries := free.filter(func(index: int) -> bool: return _waiting_fries(stations[index]))
    var choices: Array = fries if not fries.is_empty() else free
    if choices.is_empty():
        return
    var pigeon := SimPigeon.new()
    pigeon.id = _pigeons_seen
    _pigeons_seen += 1
    pigeon.station = choices[crowd.stream(["pigeon", pigeon.id]).randi_range(0, choices.size() - 1)]
    pigeon.flying = rules.pigeon_flight
    pigeon.peck = rules.pigeon_peck
    pigeons.append(pigeon)
    events.append({"type": &"pigeon_arrived", "id": pigeon.id, "station": pigeon.station})


## why: &"shooed", &"stole", &"fire" (and later &"shot").
func _pigeon_leaves(pigeon: SimPigeon, why: StringName) -> void:
    pigeons.erase(pigeon)
    events.append({"type": &"pigeon_left", "id": pigeon.id, "station": pigeon.station, "why": why})


func _pigeon_delay() -> int:
    return crowd.stream(["pigeon_delay", _pigeons_seen]).randi_range(rules.pigeon_every_min, rules.pigeon_every_max)


## The pigeon landed on this station, null if none.
func pigeon_at(station_index: int) -> SimPigeon:
    for pigeon in pigeons:
        if pigeon.station == station_index and pigeon.landed():
            return pigeon
    return null


## Fries blanched and waiting on a CUISSON 1: what pigeons are after.
static func _waiting_fries(station: SimStation) -> bool:
    return station.kind == &"cuisson_1" and station.basket != null and not station.frying \
            and station.basket.kind == Fryer.FRIES_BLANCHED


## What the player holds is gone; the BB gun goes back under a CAISSE by itself.
func _drop(player: SimPlayer) -> void:
    if player.item and player.item.kind == GUN:
        for station in stations:
            if station.kind == &"caisse" and not station.gun:
                station.gun = true
                break
    player.item = null


## What the BB gun can aim at (GDD §8), in a fixed order: the landed pigeons, the AFSCA inspector
## while he inspects, then the teammates. Never the customers. Each is [kind, id]: [&"pigeon",
## pigeon id], [&"inspector", 0], [&"mate", slot].
func gun_targets(player: SimPlayer) -> Array:
    var targets := []
    for pigeon in pigeons:
        if pigeon.landed():
            targets.append([&"pigeon", pigeon.id])
    if night_events.inspection > 0:
        targets.append([&"inspector", 0])
    for mate in players:
        if mate != player:
            targets.append([&"mate", mate.slot])
    return targets


## While the gun is held down, left and right pick a target (gun_targets); releasing after
## SimRules.aim_hold fires, earlier uses the station (puts the gun back at a CAISSE).
func _use_gun_aim(player: SimPlayer, command: int) -> bool:
    var targets := gun_targets(player)
    match command:
        Command.MOVE_LEFT, Command.MOVE_RIGHT:
            if not targets.is_empty():
                player.aim = posmod(player.aim + (1 if command == Command.MOVE_RIGHT else -1), targets.size())
        Command.MOVE_UP, Command.MOVE_DOWN, Command.INTERACT:
            pass
        Command.RELEASE:
            var held_long := player.aim_ticks >= rules.aim_hold
            var target: Array = targets[mini(player.aim, targets.size() - 1)] if not targets.is_empty() else []
            player.aim = -1
            if not held_long:
                _interact(player)
            elif not target.is_empty():
                _shoot(player, target)
        Command.CANCEL:
            player.aim = -1
        _:
            return false
    return true


## A BB: a pigeon flies off, the inspector runs off (no verdict, but the room is shocked), a
## teammate loses a heart and is stunned. Chaos.
func _shoot(player: SimPlayer, target: Array) -> void:
    events.append({"type": &"shot", "by": player.slot, "target": target[0], "id": target[1]})
    match target[0]:
        &"pigeon":
            for pigeon in pigeons:
                if pigeon.id == target[1]:
                    _pigeon_leaves(pigeon, &"shot")
                    break
        &"inspector":
            night_events.inspector_shot()
            crowd.change_mood(rules.mood_inspector_shot)
        &"mate":
            var mate := players[target[1]]
            _hurt(mate)
            mate.stun = maxi(mate.stun, rules.bump_stun)


## The car crashes in (NightEvents.CAR_CRASH, GDD §6.4): its nodes (SimLevel.crash_nodes) become
## rubble and their stations are wrecked for the night; whoever stands there is knocked out and
## thrown aside. Without a VIANDES left, the meat and bread dishes come off the menu, and the
## customers waiting for one flee, too scared to be angry.
func _crash() -> void:
    for node in level.crash_nodes:
        blocked[node] = true
        grease.erase(node)
        var index := level.node_stations[node]
        if index != SimLevel.NONE:
            var station := stations[index]
            station.destroyed = true
            station.basket = null
            station.frying = false
            station.burning = false
            var pigeon := pigeon_at(index)
            if pigeon:
                _pigeon_leaves(pigeon, &"fire")
    for player in players:
        if blocked.has(player.node) or blocked.has(player.occupied_node()):
            player.health = 0
            _knock_out(player)
            player.path.clear()
            player.progress = 0
            player.edge_ticks = 0
            player.node = _clear_of_rubble(player.node)
    var meat_left := stations.any(func(station: SimStation) -> bool:
        return station.kind == &"viandes" and not station.destroyed)
    if not meat_left:
        var gone := Menu.MEAT_DISHES + Menu.BREAD_DISHES
        rules.menu = rules.menu.filter(func(dish: StringName) -> bool: return not dish in gone)
        for index in range(crowd.line.size() - 1, -1, -1):
            var customer := crowd.line[index]
            if not customer.boss and not customer.group \
                    and StringName(String(customer.order).get_slice(":", 0)) in gone:
                crowd.line.remove_at(index)
                events.append({"type": &"fled", "index": index})


## The nearest node to this one that isn't rubble (itself if it isn't).
func _clear_of_rubble(node: int) -> int:
    if not blocked.has(node):
        return node
    var seen := {node: true}
    var frontier := [node]
    while not frontier.is_empty():
        var next := []
        for at: int in frontier:
            for neighbour: int in level.links[at]:
                if neighbour == SimLevel.NONE or seen.has(neighbour):
                    continue
                if not blocked.has(neighbour):
                    return neighbour
                seen[neighbour] = true
                next.append(neighbour)
        frontier = next
    return node


## The FRIGO's drink on tonight's menu with the fewest left (the first in Menu.DRINKS on a tie),
## &"" when they are all full: the next to come back.
func _shortest_drink(station: SimStation) -> StringName:
    var shortest := &""
    for drink in Menu.DRINKS:
        if drink in rules.menu and station.left(drink) < rules.fridge_beers \
                and (shortest == &"" or station.left(drink) < station.left(shortest)):
            shortest = drink
    return shortest


## A planned AFSCA inspection failed (the artist's DLC 1): "pas frais". The food in hand, the
## fries waiting pre-cooked on CUISSON 1 and every drink in the FRIGO go: orders start over, and
## the FRIGO has to fill up again. Drinks in hand, the extinguisher and the gun stay.
func _spoil() -> void:
    for player in players:
        if Menu.edible(player.item) and not player.item.kind in Menu.DRINKS:
            player.item = null
    for station in stations:
        if station.kind == &"cuisson_1" and station.basket and not station.frying:
            station.basket = null
        for drink: StringName in station.stock:
            station.stock[drink] = 0
    events.append({"type": &"spoiled"})
