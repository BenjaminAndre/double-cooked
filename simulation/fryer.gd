class_name Fryer
extends RefCounted
## The double cuisson (GDD §7.1): what interacting with a fryer does, and its timings.
## Every step acts on the player's focused hand; there is never a put-down step.

const FRIES_RAW := &"frites_crues"
const FRIES_COLD := &"frites_froides"
const FRIES_OVERCOOKED := &"frites_trop_cuites"
const FRIES_RESTING := &"frites_reposees"
const FRIES_SOGGY := &"frites_molles"
const FRIES_GOOD := &"frites"
const FRIES_BURNT := &"frites_brulees"
## Out of CUISSON 2: they take sauce and can be served (bad ones at a mood penalty).
const FINISHED: Array[StringName] = [FRIES_GOOD, FRIES_SOGGY, FRIES_BURNT]

## First fry window, in ticks: lifting earlier gives cold fries, later overcooked ones.
const FIRST_FRY_MIN := 4 * Simulation.TICK_RATE
const FIRST_FRY_MAX := 7 * Simulation.TICK_RATE
## Rest needed between the fries, on CUISSON 1 or in a hand, for the fries not to go soggy.
const REST_NEEDED := 4 * Simulation.TICK_RATE
## Second fry window: lifting earlier gives soggy fries, later burnt ones.
const SECOND_FRY_MIN := 3 * Simulation.TICK_RATE
const SECOND_FRY_MAX := 5 * Simulation.TICK_RATE


## CUISSON 1: spawns a basket into empty oil, lifts the frying one, or hands over the resting one.
static func use_first(station: SimStation, player: SimPlayer) -> void:
    if not station.basket:
        station.basket = SimItem.new(FRIES_RAW)
        station.frying = true
        station.cook = 0
    elif station.frying:
        if station.cook < FIRST_FRY_MIN:
            _lift_into_hand(station, player, FRIES_COLD)
        elif station.cook <= FIRST_FRY_MAX:
            # Just in time: the basket stays on the fryer and starts resting.
            station.basket.kind = FRIES_RESTING
            station.frying = false
        else:
            _lift_into_hand(station, player, FRIES_OVERCOOKED)
    elif not player.focused_item():
        player.set_focused_item(station.basket)
        station.basket = null


## CUISSON 2: takes resting fries from the focused hand, or lifts the frying basket into it.
static func use_second(station: SimStation, player: SimPlayer) -> void:
    var held := player.focused_item()
    if not station.basket:
        if held and held.kind == FRIES_RESTING:
            held.rested = held.rest >= REST_NEEDED
            station.basket = held
            station.frying = true
            station.cook = 0
            player.set_focused_item(null)
    elif station.cook < SECOND_FRY_MIN:
        _lift_into_hand(station, player, FRIES_SOGGY)
    elif station.cook <= SECOND_FRY_MAX:
        _lift_into_hand(station, player, FRIES_GOOD if station.basket.rested else FRIES_SOGGY)
    else:
        _lift_into_hand(station, player, FRIES_BURNT)


## Every tick: frying and resting times run, on the fryer and in hands alike.
static func advance(station: SimStation) -> void:
    if not station.basket:
        return
    if station.frying:
        station.cook += 1
    else:
        advance_item(station.basket)


static func advance_item(item: SimItem) -> void:
    if item and item.kind == FRIES_RESTING:
        item.rest += 1


static func _lift_into_hand(station: SimStation, player: SimPlayer, kind: StringName) -> void:
    if player.focused_item():
        return
    station.basket.kind = kind
    player.set_focused_item(station.basket)
    station.basket = null
    station.frying = false
    station.cook = 0
