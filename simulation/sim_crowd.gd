class_name SimCrowd
extends RefCounted
## The line of customers and the room mood (GDD §6). Only the front customer shows an order.

enum Level { CALME, TENDU, CHAUD, EMEUTE }


class Customer:
    ## Unique within a night, so the display can follow each customer.
    var id: int
    ## Order lines still to hand over (see Menu.order_key), one to three.
    var order: Array[StringName] = []
    var patience: int

    func fingerprint() -> Array:
        return [id, order, patience]

var rules: SimRules
## Front of the line first.
var line: Array[Customer] = []
var mood := 0
var next_arrival: int
var _next_id := 0


func _init(p_rules: SimRules) -> void:
    rules = p_rules
    next_arrival = rules.first_arrival


func level() -> Level:
    return clampi(mood * 4 / rules.riot, Level.CALME, Level.EMEUTE) as Level


func front() -> Customer:
    return line[0] if not line.is_empty() else null


## One tick of the room: arrivals, patience, walk-outs and the mood's own drift.
## events receives {"type": &"arrival"} and {"type": &"walk_out"}.
func advance(tick: int, player_count: int, rng: RandomNumberGenerator, events: Array[Dictionary]) -> void:
    if tick >= next_arrival:
        if line.size() < rules.max_line:
            line.append(_new_customer(rng))
            events.append({"type": &"arrival"})
        next_arrival = tick + _arrival_delay(tick, player_count, rng)
    for index in range(line.size() - 1, -1, -1):
        var customer := line[index]
        customer.patience -= rules.front_drain if index == 0 else rules.back_drain
        if customer.patience <= 0:
            line.remove_at(index)
            change_mood(rules.mood_walk_out)
            events.append({"type": &"walk_out"})
    if tick > 0 and tick % _drift_every(tick) == 0:
        change_mood(1)
    if tick > 0 and tick % rules.line_pressure_every == 0:
        change_mood(maxi(line.size() - 1, 0))


## Hands item to the front customer if it's part of their order. Returns whether it was taken.
func serve(item: SimItem, events: Array[Dictionary]) -> bool:
    var customer := front()
    if not customer or not item:
        return false
    var dish := Menu.order_key(item)
    if not dish in customer.order:
        return false
    customer.order.erase(dish)
    var good := Menu.done_right(item)
    change_mood(rules.mood_good_item if good else rules.mood_bad_item)
    events.append({"type": &"served", "good": good})
    if customer.order.is_empty():
        line.pop_front()
        events.append({"type": &"order_done"})
    return true


func change_mood(amount: int) -> void:
    mood = clampi(mood + amount, 0, rules.riot)



func fingerprint() -> Array:
    var customers := []
    for customer in line:
        customers.append(customer.fingerprint())
    return [customers, mood, next_arrival, _next_id]


func _new_customer(rng: RandomNumberGenerator) -> Customer:
    var customer := Customer.new()
    customer.id = _next_id
    _next_id += 1
    customer.patience = rules.patience
    customer.order = Menu.random_order(rng, rules.order_sizes)
    return customer


func _arrival_delay(tick: int, player_count: int, rng: RandomNumberGenerator) -> int:
    var delay := float(rng.randi_range(rules.arrival_min, rules.arrival_max))
    # One player: as is. Each extra player shortens the wait (2 players: x2/3, 4: x2/5).
    delay *= 2.0 / (player_count + 1)
    if _phase(tick) == 1:
        delay *= rules.rush_arrival_factor
    return maxi(1, roundi(delay))


func _drift_every(tick: int) -> int:
    match _phase(tick):
        0:
            return rules.drift_every_soiree
        1:
            return rules.drift_every_rush
    return rules.drift_every_after


## 0 Soirée, 1 Rush, 2 After.
func _phase(tick: int) -> int:
    var progress := float(tick) / rules.night_ticks
    return 0 if progress < rules.rush_start else 1 if progress < rules.after_start else 2
