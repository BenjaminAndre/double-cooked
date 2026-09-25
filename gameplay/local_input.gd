class_name LocalInput
extends RefCounted
## Turns key presses into Simulation commands for the players sitting at this keyboard.
## Actions are bound to physical keys, so they sit at the same place on AZERTY and QWERTY.
## Key names below are QWERTY positions.

## One player: arrows, Space to interact, Escape to close a menu, Tab to take damage (debug).
const SOLO := [{
    &"ui_up": Simulation.Command.MOVE_UP,
    &"ui_down": Simulation.Command.MOVE_DOWN,
    &"ui_left": Simulation.Command.MOVE_LEFT,
    &"ui_right": Simulation.Command.MOVE_RIGHT,
    &"ui_interact": Simulation.Command.INTERACT,
    &"ui_cancel": Simulation.Command.CANCEL,
    &"ui_debug_damage": Simulation.Command.DEBUG_DAMAGE,
}]

## Two players on one keyboard, one hand each:
## P1 on the left (WASD, Space, Escape), P2 on the right (arrows, Right Shift, Backspace).
const DUO := [{
    &"p1_up": Simulation.Command.MOVE_UP,
    &"p1_down": Simulation.Command.MOVE_DOWN,
    &"p1_left": Simulation.Command.MOVE_LEFT,
    &"p1_right": Simulation.Command.MOVE_RIGHT,
    &"p1_interact": Simulation.Command.INTERACT,
    &"p1_cancel": Simulation.Command.CANCEL,
    &"ui_debug_damage": Simulation.Command.DEBUG_DAMAGE,
}, {
    &"p2_up": Simulation.Command.MOVE_UP,
    &"p2_down": Simulation.Command.MOVE_DOWN,
    &"p2_left": Simulation.Command.MOVE_LEFT,
    &"p2_right": Simulation.Command.MOVE_RIGHT,
    &"p2_interact": Simulation.Command.INTERACT,
    &"p2_cancel": Simulation.Command.CANCEL,
}]

## The interact key of each layout, as shown in hints.
const SOLO_INTERACT_KEYS := ["Espace"]
const DUO_INTERACT_KEYS := ["Espace", "Maj"]

var _layouts: Array
var _interact_keys: Array


func _init(local_players: int) -> void:
    _layouts = SOLO if local_players == 1 else DUO
    _interact_keys = SOLO_INTERACT_KEYS if local_players == 1 else DUO_INTERACT_KEYS


func interact_key_name(local_index: int) -> String:
    return _interact_keys[local_index]


## Returns [slot, command] for a key press, or [] if it isn't one of ours.
func read(event: InputEvent) -> Array:
    for slot in _layouts.size():
        for action: StringName in _layouts[slot]:
            if event.is_action_pressed(action):
                return [slot, _layouts[slot][action]]
    return []
