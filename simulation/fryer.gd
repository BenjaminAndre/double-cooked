class_name Fryer
extends RefCounted
## The double cuisson (GDD §7.1): what interacting with a fryer does, and its timings.
## Every step acts on the player's focused hand; there is never a put-down step.
##
## CUISSON 1 fries a batch of BATCH portions. Lifted in time, the batch stays on the fryer
## and players take its portions one by one, each ready for a CUISSON 2.

const FRIES_RAW := &"frites_crues"
const FRIES_COLD := &"frites_froides"
const FRIES_OVERCOOKED := &"frites_trop_cuites"
const FRIES_BLANCHED := &"frites_blanchies"
const FRIES_SOGGY := &"frites_molles"
const FRIES_GOOD := &"frites"
const FRIES_BURNT := &"frites_brulees"

## Portions in one CUISSON 1 batch.
const BATCH := 5
## First fry window, in ticks: lifting earlier gives cold fries, later overcooked ones.
const FIRST_FRY_MIN := 8 * Simulation.TICK_RATE
const FIRST_FRY_MAX := 20 * Simulation.TICK_RATE
## Second fry window: lifting earlier gives soggy fries, later burnt ones.
const SECOND_FRY_MIN := 3 * Simulation.TICK_RATE
const SECOND_FRY_MAX := 7 * Simulation.TICK_RATE


## The [min, max] ticks in the oil for what this fryer is cooking.
static func window(station: SimStation) -> Vector2i:
    if station.kind == &"cuisson_1":
        return Vector2i(FIRST_FRY_MIN, FIRST_FRY_MAX)
    return Vector2i(SECOND_FRY_MIN, SECOND_FRY_MAX)


## CUISSON 1: drops a new batch into empty oil, lifts the frying one, or hands over one
## portion of the batch waiting on the fryer. A ruined batch goes whole into the hand.
static func use_first(station: SimStation, player: SimPlayer) -> void:
    if not station.basket:
        station.basket = SimItem.new(FRIES_RAW)
        station.basket.portions = BATCH
        station.frying = true
        station.cook = 0
    elif station.frying:
        if station.cook < FIRST_FRY_MIN:
            _lift_into_hand(station, player, FRIES_COLD)
        elif station.cook <= FIRST_FRY_MAX:
            station.basket.kind = FRIES_BLANCHED
            station.frying = false
        else:
            _lift_into_hand(station, player, FRIES_OVERCOOKED)
    elif not player.item:
        player.item = SimItem.new(FRIES_BLANCHED)
        station.basket.portions -= 1
        if station.basket.portions == 0:
            station.basket = null


## CUISSON 2: takes what it can fry (a blanched portion, a raw fricadelle, a cold cervelas)
## from the focused hand, or lifts the frying one into it (see Menu.SECOND_FRY).
static func use_second(station: SimStation, player: SimPlayer) -> void:
    var held := player.item
    if not station.basket:
        if can_second_fry(held):
            station.basket = held
            station.frying = true
            station.cook = 0
            player.item = null
        return
    var outcomes: Array = Menu.SECOND_FRY[station.basket.kind]
    if station.cook < SECOND_FRY_MIN:
        _lift_into_hand(station, player, outcomes[0])
    elif station.cook <= SECOND_FRY_MAX:
        _lift_into_hand(station, player, outcomes[1])
    else:
        _lift_into_hand(station, player, outcomes[2])


static func can_second_fry(item: SimItem) -> bool:
    return item != null and Menu.SECOND_FRY.has(item.kind) and item.sauce == &""


## Every tick: frying time runs.
static func advance(station: SimStation) -> void:
    if station.basket and station.frying:
        station.cook += 1


static func _lift_into_hand(station: SimStation, player: SimPlayer, kind: StringName) -> void:
    if player.item:
        return
    station.basket.kind = kind
    player.item = station.basket
    station.basket = null
    station.frying = false
    station.cook = 0
