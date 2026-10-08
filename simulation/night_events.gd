class_name NightEvents
extends RefCounted
## What happens to a night besides its customers (GDD §6.4, the artist's events): each comes at
## its time (SimRules.night_events), is announced, and changes the rules for a while.
## - PANNE_FRIGO: the FRIGO breaks down, no beer comes back for a while.
## - DIABLES_ROUGES: half-time of the national team, a rush of customers in a hurry.
## - AFSCA: the food safety inspector watches the kitchen a while; a fire meanwhile and the room
##   sours, none and it calms down.
## - COLLEGUES: a group of colleagues from the company, announced ahead: their leader queues and
##   orders for everyone, beers mostly; the others wait outside.

const PANNE_FRIGO := &"panne_frigo"
const DIABLES_ROUGES := &"diables_rouges"
const AFSCA := &"afsca"
const COLLEGUES := &"collegues"

var rules: SimRules
var crowd: SimCrowd
## Ticks left before the FRIGO works again.
var fridge_down := 0
## Ticks left of the AFSCA inspection, and whether a fire burnt during it.
var inspection := 0
var inspection_failed := false
## Ticks before the colleagues' leader joins the line: the FRIGO restocks twice as fast meanwhile.
var group_coming := 0
## How many of tonight's events have started, in their order.
var _started := 0


func _init(p_rules: SimRules, p_crowd: SimCrowd) -> void:
    rules = p_rules
    crowd = p_crowd


## One tick: the next event starts once its time comes ({"type": &"night_event", "kind": ...}),
## and those under way run out. fire: whether a station is burning.
func advance(tick: int, events: Array[Dictionary], fire: bool, rng: RandomNumberGenerator) -> void:
    if group_coming > 0:
        group_coming -= 1
        if group_coming == 0:
            crowd.add_group(rng, events)
    if inspection > 0:
        inspection_failed = inspection_failed or fire
        inspection -= 1
        if inspection == 0:
            crowd.change_mood(rules.mood_inspection_failed if inspection_failed else rules.mood_inspection_passed)
            events.append({"type": &"inspection_over", "passed": not inspection_failed})
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
        AFSCA:
            inspection = rules.inspection_ticks
            inspection_failed = false
        COLLEGUES:
            group_coming = rules.group_warning


func fingerprint() -> Array:
    return [fridge_down, inspection, inspection_failed, group_coming, _started]
