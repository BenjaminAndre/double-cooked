class_name NightEvents
extends RefCounted
## What happens to a night besides its customers (GDD §6.4, the artist's events): each comes at
## its time (SimRules.night_events), is announced, and changes the rules for a while.
## - PANNE_FRIGO: the FRIGO breaks down, no beer comes back for a while.
## - DIABLES_ROUGES: half-time of the national team, a rush of customers in a hurry.

const PANNE_FRIGO := &"panne_frigo"
const DIABLES_ROUGES := &"diables_rouges"

var rules: SimRules
var crowd: SimCrowd
## Ticks left before the FRIGO works again.
var fridge_down := 0
## How many of tonight's events have started, in their order.
var _started := 0


func _init(p_rules: SimRules, p_crowd: SimCrowd) -> void:
    rules = p_rules
    crowd = p_crowd


## One tick: the next event starts once its time comes ({"type": &"night_event", "kind": ...}),
## and those under way run out.
func advance(tick: int, events: Array[Dictionary]) -> void:
    if fridge_down > 0:
        fridge_down -= 1
        if fridge_down == 0:
            events.append({"type": &"fridge_fixed"})
    while _started < rules.night_events.size() \
            and tick >= int(rules.night_ticks * float(rules.night_events[_started][0])):
        var kind: StringName = rules.night_events[_started][1]
        _started += 1
        _start(kind)
        events.append({"type": &"night_event", "kind": kind})


func _start(kind: StringName) -> void:
    match kind:
        PANNE_FRIGO:
            fridge_down = rules.fridge_breakdown
        DIABLES_ROUGES:
            crowd.rush = rules.rush_customers


func fingerprint() -> Array:
    return [fridge_down, _started]
