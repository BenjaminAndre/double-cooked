class_name LocalInput
extends RefCounted
## Turns key presses into Simulation commands for the players sitting at this keyboard.
## Actions are bound to physical keys, so they sit at the same place on AZERTY and QWERTY.
## Key names below are QWERTY positions.

## One player: arrows, Space to interact, Enter to eat or drink, Escape to close a menu, Tab to
## take damage (debug).
const SOLO := [{
    &"ui_up": Simulation.Command.MOVE_UP,
    &"ui_down": Simulation.Command.MOVE_DOWN,
    &"ui_left": Simulation.Command.MOVE_LEFT,
    &"ui_right": Simulation.Command.MOVE_RIGHT,
    &"ui_interact": Simulation.Command.INTERACT,
    &"ui_cancel": Simulation.Command.CANCEL,
    &"ui_eat": Simulation.Command.EAT,
    &"ui_debug_damage": Simulation.Command.DEBUG_DAMAGE,
}]

## Two players on one keyboard, one hand each:
## P1 on the left (WASD, Space, E to eat, Escape), P2 on the right (arrows, Right Shift, Enter
## to eat, Backspace).
const DUO := [{
    &"p1_up": Simulation.Command.MOVE_UP,
    &"p1_down": Simulation.Command.MOVE_DOWN,
    &"p1_left": Simulation.Command.MOVE_LEFT,
    &"p1_right": Simulation.Command.MOVE_RIGHT,
    &"p1_interact": Simulation.Command.INTERACT,
    &"p1_cancel": Simulation.Command.CANCEL,
    &"p1_eat": Simulation.Command.EAT,
    &"ui_debug_damage": Simulation.Command.DEBUG_DAMAGE,
}, {
    &"p2_up": Simulation.Command.MOVE_UP,
    &"p2_down": Simulation.Command.MOVE_DOWN,
    &"p2_left": Simulation.Command.MOVE_LEFT,
    &"p2_right": Simulation.Command.MOVE_RIGHT,
    &"p2_interact": Simulation.Command.INTERACT,
    &"p2_cancel": Simulation.Command.CANCEL,
    &"p2_eat": Simulation.Command.EAT,
}]

## The interact key of each layout, as shown in hints.
const SOLO_INTERACT_KEYS := ["Espace"]
const DUO_INTERACT_KEYS := ["Espace", "Maj"]
## The eat key of each layout, as shown in hints.
const SOLO_EAT_KEYS := ["Entrée"]
const DUO_EAT_KEYS := ["E", "Entrée"]

var _layouts: Array
var _interact_keys: Array
var _eat_keys: Array


func _init(local_players: int) -> void:
    _layouts = SOLO if local_players == 1 else DUO
    _interact_keys = SOLO_INTERACT_KEYS if local_players == 1 else DUO_INTERACT_KEYS
    _eat_keys = SOLO_EAT_KEYS if local_players == 1 else DUO_EAT_KEYS


func eat_key_name(local_index: int) -> String:
    return _eat_keys[local_index]


func interact_key_name(local_index: int) -> String:
    return _interact_keys[local_index]


## Returns [slot, command] for a key press, or [] if it isn't one of ours. Letting go of the
## interact key gives RELEASE, for throwing.
func read(event: InputEvent) -> Array:
    for slot in _layouts.size():
        for action: StringName in _layouts[slot]:
            var command: int = _layouts[slot][action]
            if event.is_action_pressed(action):
                return [slot, command]
            if command == Simulation.Command.INTERACT and event.is_action_released(action):
                return [slot, Simulation.Command.RELEASE]
    return []
