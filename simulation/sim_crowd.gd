class_name SimCrowd
extends RefCounted
## The line of customers and the room mood (GDD §6). Each customer orders a single line
## (see Menu.order_key); the first SimRules.visible_orders show it.

enum Level { CALME, TENDU, CHAUD, EMEUTE }


class Customer:
    ## Unique within a night, so the display can follow each customer.
    var id: int
    ## What they want, see Menu.order_key.
    var order: StringName
    var patience: int
    ## Already given an unordered beer: another one sends them off angry.
    var gifted := false

    func fingerprint() -> Array:
        return [id, order, patience, gifted]

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


## One tick of the room: arrivals, patience, walk-outs, and a long line souring the mood.
## events receives {"type": &"arrival"} and {"type": &"walk_out", "index": place in line}.
func advance(tick: int, player_count: int, rng: RandomNumberGenerator, events: Array[Dictionary]) -> void:
    # The door closes at 04:00.
    if tick >= next_arrival and tick < rules.night_ticks:
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
            events.append({"type": &"walk_out", "index": index, "by": -1})
    if tick > 0 and tick % rules.line_pressure_every == 0:
        change_mood(maxi(line.size() - 1, 0))


## Serving is handing over whatever is held (GDD §6.2). The right order, done right, sends
## the customer off happy; anything else sends them off angry, at the player who served
## (by). A beer is the exception (see give_beer). Returns whether the item was handed over.
func serve(item: SimItem, by: int, events: Array[Dictionary]) -> bool:
    var customer := front()
    if not customer or not item:
        return false
    if item.kind == Menu.BEER:
        give_beer(0, by, events)
        return true
    line.pop_front()
    if Menu.order_key(item) == customer.order and Menu.done_right(item):
        change_mood(rules.mood_served)
        events.append({"type": &"served"})
    else:
        _leave_angry(0, by, events)
    return true


## A beer for the customer at index, handed over or caught. If they ordered one, they're
## served. The first unordered beer buys back some patience; a second one is too much and
## they leave angry, at whoever gave it.
func give_beer(index: int, by: int, events: Array[Dictionary]) -> void:
    var customer := line[index]
    if customer.order == Menu.BEER:
        line.remove_at(index)
        change_mood(rules.mood_served)
        events.append({"type": &"served"})
    elif customer.gifted:
        line.remove_at(index)
        _leave_angry(index, by, events)
    else:
        customer.gifted = true
        customer.patience = mini(customer.patience + rules.beer_patience, rules.patience)
        events.append({"type": &"beer_gift", "index": index})


func _leave_angry(index: int, by: int, events: Array[Dictionary]) -> void:
    change_mood(rules.mood_angry)
    events.append({"type": &"angry", "index": index, "by": by})


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
    customer.order = Menu.random_order(rng, rules.order_categories)
    return customer


func _arrival_delay(tick: int, player_count: int, rng: RandomNumberGenerator) -> int:
    var delay := float(rng.randi_range(rules.arrival_min, rules.arrival_max))
    # One player: as is. Each extra player shortens the wait (2 players: x2/3, 4: x2/5).
    delay *= 2.0 / (player_count + 1)
    delay *= lerpf(rules.calm_arrival_factor, rules.mad_arrival_factor, rules.intensity(tick))
    return maxi(1, roundi(delay))


