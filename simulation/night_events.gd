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
## A surprise inspection (from the second week, GDD §6.4): announced only a few seconds ahead,
## and a dirty kitchen (a fire, grease on the floor) gets the shop closed.
const AFSCA_SURPRISE := &"afsca_surprise"
## A car crashes into the kitchen (GDD §6.4): announced a few seconds ahead, it wrecks a corner
## for the rest of the night (Simulation._crash).
const CAR_CRASH := &"voiture"

var rules: SimRules
var crowd: SimCrowd
## Ticks left before the FRIGO works again.
var fridge_down := 0
## Ticks left of the AFSCA inspection, and whether a fire burnt during it.
var inspection := 0
var inspection_failed := false
## Ticks before the colleagues' leader joins the line: the FRIGO restocks twice as fast meanwhile.
var group_coming := 0
## The tick a surprise inspection comes tonight, -1 if none (any more); ticks before the
## inspector walks in once announced; whether the inspection under way is a surprise one, and
## whether one closed the shop.
var surprise_at := -1
var inspector_coming := 0
var surprise := false
var closed := false
## Ticks before the car hits, once announced.
var car_coming := 0
## How many of tonight's events have started, in their order.
var _started := 0


func _init(p_rules: SimRules, p_crowd: SimCrowd) -> void:
    rules = p_rules
    crowd = p_crowd
    # Drawn from the night's seed alone, like the customers.
    var rng := crowd.stream("afsca_surprise")
    if rng.randf() < rules.surprise_inspection_chance:
        surprise_at = int(rules.night_ticks * rng.randf_range(0.15, 0.85))


## One tick: the next event starts once its time comes ({"type": &"night_event", "kind": ...}),
## and those under way run out. dirty: whether a station is burning or grease is on the floor.
func advance(tick: int, events: Array[Dictionary], dirty: bool) -> void:
    if car_coming > 0:
        car_coming -= 1
        if car_coming == 0:
            events.append({"type": &"car_crash"})
    if inspector_coming > 0:
        inspector_coming -= 1
        if inspector_coming == 0:
            _inspect(true)
    if group_coming > 0:
        group_coming -= 1
        if group_coming == 0:
            crowd.add_group(events)
    if inspection > 0:
        inspection_failed = inspection_failed or dirty
        inspection -= 1
        if inspection == 0:
            # A surprise inspection failed closes the shop; the planned one only sours the room.
            closed = surprise and inspection_failed
            if not closed:
                crowd.change_mood(rules.mood_inspection_failed if inspection_failed else rules.mood_inspection_passed)
            events.append({"type": &"inspection_over", "passed": not inspection_failed, "closed": closed})
    if surprise_at >= 0 and tick >= surprise_at:
        surprise_now(events)
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
            _inspect(false)
        COLLEGUES:
            group_coming = rules.group_warning
        CAR_CRASH:
            car_coming = rules.car_warning


func fingerprint() -> Array:
    return [fridge_down, inspection, inspection_failed, group_coming, _started, surprise_at, inspector_coming,
            surprise, closed, car_coming]


## The surprise inspector is announced now (also a test tool), unless an inspection is on.
func surprise_now(events: Array[Dictionary]) -> void:
    surprise_at = -1
    if inspection > 0 or inspector_coming > 0:
        return
    inspector_coming = rules.surprise_warning
    events.append({"type": &"night_event", "kind": AFSCA_SURPRISE})


func _inspect(is_surprise: bool) -> void:
    inspection = rules.inspection_ticks
    inspection_failed = false
    surprise = is_surprise


## Shot with the BB gun, the inspector runs off: the inspection ends with no verdict.
func inspector_shot() -> void:
    inspection = 0
    inspection_failed = false
    surprise = false


## Test tool: the car is announced now.
func car_now(events: Array[Dictionary]) -> void:
    if car_coming == 0:
        car_coming = rules.car_warning
        events.append({"type": &"night_event", "kind": CAR_CRASH})
