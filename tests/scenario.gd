class_name Scenario
extends RefCounted
## A scripted game for tests (GDD §9.2): a level, spawns, a seed and a timeline of commands.
## It has the same shape as a replay, so a recorded game can become a test.
##
##     var sim := Scenario.new(level, [a, b]).at(0, 0, MOVE_RIGHT).at(0, 1, MOVE_LEFT).run_until(10)

var simulation: Simulation
## Every event so far, each with the "tick" it happened on.
var events: Array[Dictionary] = []

## tick -> Array of [slot, command], in the order they were added.
var _timeline := {}


func _init(level: SimLevel, spawns: PackedInt32Array, seed_value := 0, rules: SimRules = null) -> void:
    simulation = Simulation.new(level, spawns, seed_value, rules)


## Rebuilds a recorded night (Night.replay(), or a file from user://replays) on its level.
## run_until(replay.ticks) then reproduces it exactly.
static func from_replay(level: SimLevel, replay: Dictionary) -> Scenario:
    var spawns := PackedInt32Array()
    for spawn_name: String in replay.spawns:
        spawns.append(level.find(spawn_name))
    var scenario := Scenario.new(level, spawns, int(replay.seed))
    var commands: Array = replay.commands
    for index in range(0, commands.size(), 3):
        scenario.at(int(commands[index]), int(commands[index + 1]), int(commands[index + 2]))
    return scenario


## Queues a command for a player at a tick. Chainable.
func at(tick: int, slot: int, command: int) -> Scenario:
    if not _timeline.has(tick):
        _timeline[tick] = []
    _timeline[tick].append([slot, command])
    return self


## Steps the simulation until its tick counter reaches tick.
func run_until(tick: int) -> Simulation:
    while simulation.tick < tick:
        var commands := []
        for slot in simulation.players.size():
            commands.append([])
        for entry in _timeline.get(simulation.tick, []):
            commands[entry[0]].append(entry[1])
        simulation.step(commands)
        for event in simulation.events:
            var logged := event.duplicate()
            logged.tick = simulation.tick - 1
            events.append(logged)
    return simulation
