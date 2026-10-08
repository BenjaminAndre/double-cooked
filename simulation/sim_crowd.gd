class_name SimCrowd
extends RefCounted
## The line of customers and the room mood (GDD §6). Each customer orders a single line
## (see Menu.order_key); the first SimRules.visible_orders show it. Once a night the boss comes
## (GDD §6.3): several orders in a row, a drink on the side, and cans while he waits.

enum Level { CALME, TENDU, CHAUD, EMEUTE }
## What became of each of the boss's orders.
enum Result { WAITING, SERVED, MISSED }


class Customer:
    ## Unique within a night, so the display can follow each customer.
    var id: int
    ## What they want, see Menu.order_key. For the boss, his current order.
    var order: StringName
    var patience: int
    ## Unordered beers given so far (GDD §6.2): the first SimRules.beer_gifts buy patience, one
    ## more puts them to sleep.
    var gifts := 0
    ## Ticks left asleep: no patience lost, and they can't be served.
    var asleep := 0
    var boss := false
    ## The boss's orders, and what became of each (Result).
    var orders: Array[StringName] = []
    var results := PackedInt32Array()
    ## The boss's drink order, &"" between two; drink_patience while he waits for one,
    ## drink_again until the next.
    var drink := &""
    var drink_patience := 0
    var drink_again := 0
    ## Ticks until the boss throws his next can for no reason.
    var next_can := 0

    ## The index of the boss's current order, -1 once they are all done.
    func current() -> int:
        return Array(results).find(Result.WAITING)

    func fingerprint() -> Array:
        return [id, order, patience, gifts, asleep, boss, orders, results, drink, drink_patience,
                drink_again, next_can]

var rules: SimRules
## Front of the line first.
var line: Array[Customer] = []
var mood := 0
var next_arrival: int
## Whether tonight's boss has walked in.
var boss_came := false
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
    if not boss_came and rules.boss_orders > 0 and tick >= rules.boss_tick() and tick < rules.night_ticks:
        _boss_arrives(rng, events)
    if tick >= next_arrival and tick < rules.night_ticks:
        if line.size() < rules.max_line:
            line.append(_new_customer(rng))
            events.append({"type": &"arrival"})
        next_arrival = tick + _arrival_delay(tick, player_count, rng)
    for index in range(line.size() - 1, -1, -1):
        var customer := line[index]
        if customer.boss:
            _advance_boss(customer, rng, events)
            continue
        if customer.asleep > 0:
            customer.asleep -= 1
            continue
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
    if customer.boss:
        _serve_boss(customer, item, by, events)
        return true
    if customer.asleep > 0:
        return false
    if item.kind == Menu.BEER:
        give_beer(0, by, events)
        return true
    line.pop_front()
    if Menu.order_key(item) == customer.order and Menu.done_right(item):
        change_mood(rules.mood_served)
        events.append({"type": &"served", "by": by})
    else:
        _leave_angry(0, by, events)
    return true


## A beer for the customer at index, handed over or caught. If they ordered one, they're
## served. The first unordered ones (SimRules.beer_gifts) buy back some patience; one more puts
## them to sleep for a while (the artist's rule). The boss only takes it as his drink.
func give_beer(index: int, by: int, events: Array[Dictionary]) -> void:
    var customer := line[index]
    if customer.boss:
        _boss_drink(customer, Menu.BEER, events)
    elif customer.order == Menu.BEER:
        line.remove_at(index)
        change_mood(rules.mood_served)
        events.append({"type": &"served", "by": by})
    elif customer.gifts < rules.beer_gifts:
        customer.gifts += 1
        customer.patience = mini(customer.patience + rules.beer_patience, rules.patience)
        events.append({"type": &"beer_gift", "index": index, "by": by})
    else:
        customer.gifts += 1
        customer.asleep = rules.beer_sleep
        events.append({"type": &"asleep", "index": index, "by": by})


func _leave_angry(index: int, by: int, events: Array[Dictionary]) -> void:
    change_mood(rules.mood_angry)
    events.append({"type": &"angry", "index": index, "by": by})


func change_mood(amount: int) -> void:
    mood = clampi(mood + amount, 0, rules.riot)


func fingerprint() -> Array:
    var customers := []
    for customer in line:
        customers.append(customer.fingerprint())
    return [customers, mood, next_arrival, boss_came, _next_id]


## The patience each of the boss's orders starts with.
func boss_patience() -> int:
    return rules.patience * rules.boss_patience_factor


## He cuts in at the counter: everyone goes back one place, even a customer being served.
func _boss_arrives(rng: RandomNumberGenerator, events: Array[Dictionary]) -> void:
    boss_came = true
    var boss := Customer.new()
    boss.id = _next_id
    _next_id += 1
    boss.boss = true
    for index in rules.boss_orders:
        boss.orders.append(Menu.random_order(rng, rules.order_categories, rules.menu, true))
        boss.results.append(Result.WAITING)
    boss.order = boss.orders[0]
    boss.patience = boss_patience()
    boss.drink_again = rules.boss_drink_again
    boss.next_can = rules.boss_can_every
    line.insert(0, boss)
    events.append({"type": &"boss_arrived"})


func _advance_boss(boss: Customer, rng: RandomNumberGenerator, events: Array[Dictionary]) -> void:
    boss.patience -= rules.front_drain
    if boss.patience <= 0:
        _boss_miss(boss, -1, events)
        if boss.current() < 0:
            return
    if boss.drink != &"":
        boss.drink_patience -= 1
        if boss.drink_patience <= 0:
            _boss_thirsty(boss, events)
    else:
        boss.drink_again -= 1
        var drinks := Menu.options(&"frigo", rules.menu)
        # No drink on the menu yet: no drink ticket.
        if boss.drink_again <= 0 and not drinks.is_empty():
            boss.drink = drinks[rng.randi_range(0, drinks.size() - 1)]
            boss.drink_patience = rules.boss_drink_patience
    boss.next_can -= 1
    if boss.next_can <= 0:
        boss.next_can = rules.boss_can_every
        events.append({"type": &"boss_throws"})


## A drink goes on his drink ticket; food is his current order.
func _serve_boss(boss: Customer, item: SimItem, by: int, events: Array[Dictionary]) -> void:
    if item.kind in Menu.DRINKS:
        _boss_drink(boss, item.kind, events)
        return
    if Menu.order_key(item) == boss.order and Menu.done_right(item):
        boss.results[boss.current()] = Result.SERVED
        change_mood(rules.mood_served)
        events.append({"type": &"boss_served", "by": by})
        _boss_next(boss, events)
    else:
        _boss_miss(boss, by, events)


## The right drink clears his drink ticket; any other counts as none.
func _boss_drink(boss: Customer, drink: StringName, events: Array[Dictionary]) -> void:
    if boss.drink != &"" and drink == boss.drink:
        boss.drink = &""
        boss.drink_again = rules.boss_drink_again
        events.append({"type": &"boss_drank"})
    else:
        _boss_thirsty(boss, events)


## No drink (or the wrong one): his current order loses patience, and he orders another later.
func _boss_thirsty(boss: Customer, events: Array[Dictionary]) -> void:
    boss.drink = &""
    boss.drink_again = rules.boss_drink_again
    boss.patience = maxi(boss.patience - rules.boss_drink_penalty, 1)
    events.append({"type": &"boss_thirsty"})


## A missed order: worse mood and a salvo of cans (thrown by Simulation), then the next one.
func _boss_miss(boss: Customer, by: int, events: Array[Dictionary]) -> void:
    boss.results[boss.current()] = Result.MISSED
    change_mood(rules.mood_boss_miss)
    events.append({"type": &"boss_missed", "by": by})
    _boss_next(boss, events)


## On to his next order, or he leaves once they are all done.
func _boss_next(boss: Customer, events: Array[Dictionary]) -> void:
    var index := boss.current()
    if index >= 0:
        boss.order = boss.orders[index]
        boss.patience = boss_patience()
        return
    line.erase(boss)
    var served := Array(boss.results).count(Result.SERVED)
    if served == boss.results.size():
        change_mood(rules.mood_boss_served)
    events.append({"type": &"boss_left", "served": served})


func _new_customer(rng: RandomNumberGenerator) -> Customer:
    var customer := Customer.new()
    customer.id = _next_id
    _next_id += 1
    customer.patience = rules.patience
    customer.order = Menu.random_order(rng, rules.order_categories, rules.menu)
    return customer


func _arrival_delay(tick: int, player_count: int, rng: RandomNumberGenerator) -> int:
    var delay := float(rng.randi_range(rules.arrival_min, rules.arrival_max))
    # One player: as is. Each extra player shortens the wait (2 players: x2/3, 4: x2/5).
    delay *= 2.0 / (player_count + 1)
    delay *= lerpf(rules.calm_arrival_factor, rules.mad_arrival_factor, rules.intensity(tick))
    # Each night of a campaign is a little busier than the last.
    delay /= 1.0 + rules.busier_per_night * maxi(rules.night_number - 1, 0)
    return maxi(1, roundi(delay))
