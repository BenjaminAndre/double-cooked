class_name Tutorial
extends RefCounted
## The tutorial (GDD §4.4): one quiet night in steps. A step ends only once the crew has done
## it, whoever does; the next one may bring a customer or a fire. Nothing else happens meanwhile
## (Campaign.rules_for(Campaign.TUTORIAL)). After the last step the night is held.

## Each step: "id", "text" (what to do; {interagir} and {manger} stand for the keys) and
## "station", the kind of station to show, &"" for none.
const STEPS: Array[Dictionary] = [
    {"id": &"drop", "station": &"cuisson_1",
            "text": "Un client veut des frites mayo. Va au CUISSON 1 et plonge un panier de frites ({interagir})."},
    {"id": &"lift", "station": &"cuisson_1",
            "text": "Première cuisson : sors le panier ({interagir}) quand le curseur est dans le vert."},
    {"id": &"portion", "station": &"cuisson_1",
            "text": "Le lot attend au-dessus du CUISSON 1 : prends-en une portion ({interagir})."},
    {"id": &"second", "station": &"cuisson_2",
            "text": "Deuxième cuisson : plonge la portion au CUISSON 2."},
    {"id": &"golden", "station": &"cuisson_2",
            "text": "Sors-les quand elles sont dorées, dans le vert. Ratées ? À la POUBELLE, et reprends une portion."},
    {"id": &"sauce", "station": &"sauces",
            "text": "Aux SAUCES, choisis la mayo (flèches, puis {interagir})."},
    {"id": &"serve", "station": &"caisse",
            "text": "Sers le client à la CAISSE ({interagir})."},
    {"id": &"beer", "station": &"frigo",
            "text": "Un client veut une bière : prends-en une au FRIGO."},
    {"id": &"serve_beer", "station": &"caisse",
            "text": "Sers-la à la CAISSE. Plus tard : maintiens {interagir} pour la lancer, ou bois-la ({manger}) pour un cœur."},
    {"id": &"extinguisher", "station": &"extincteur",
            "text": "Au feu ! Prends l'EXTINCTEUR."},
    {"id": &"fire_out", "station": &"cuisson_2",
            "text": "Éteins le feu ({interagir} devant lui). Ne reste pas planté devant sans extincteur : ça brûle."},
]

## The current step (an index into STEPS); STEPS.size() once done.
var step := 0


func current() -> Dictionary:
    return STEPS[step] if step < STEPS.size() else {}


func finished() -> bool:
    return step >= STEPS.size()


## Called every tick: moves on as soon as the current step is done ({"type": &"tutorial_step",
## "step": the new one}), and sets up what the next one needs.
func advance(sim: Simulation, events: Array[Dictionary]) -> void:
    if sim.tick == 0 and step == 0:
        _start(sim, events)
    while not finished() and _done(sim, STEPS[step].id):
        step += 1
        events.append({"type": &"tutorial_step", "step": step})
        _start(sim, events)


func fingerprint() -> Array:
    return [step]


func _start(sim: Simulation, events: Array[Dictionary]) -> void:
    match current().get("id", &""):
        &"drop":
            sim.crowd.add_customer(StringName("frites:%s" % Menu.MAYO), events)
        &"beer":
            sim.crowd.add_customer(Menu.order_key(SimItem.new(Menu.BEER)), events)
        &"extinguisher":
            var fryer := sim.stations.find_custom(func(station: SimStation) -> bool:
                return station.kind == &"cuisson_2")
            if fryer >= 0:
                sim.stations[fryer].burning = true
                events.append({"type": &"fire_started", "station": fryer})


func _done(sim: Simulation, id: StringName) -> bool:
    match id:
        &"drop":
            return _any_station(sim, func(station: SimStation) -> bool:
                return station.kind == &"cuisson_1" and station.basket != null and station.frying)
        &"lift":
            return _any_station(sim, func(station: SimStation) -> bool:
                return station.kind == &"cuisson_1" and station.basket != null and not station.frying \
                        and station.basket.kind == Fryer.FRIES_BLANCHED)
        &"portion":
            return _anyone_holds(sim, func(item: SimItem) -> bool: return item.kind == Fryer.FRIES_BLANCHED)
        &"second":
            return _any_station(sim, func(station: SimStation) -> bool:
                return station.kind == &"cuisson_2" and station.basket != null and station.frying)
        &"golden":
            return _anyone_holds(sim, func(item: SimItem) -> bool: return item.kind == Fryer.FRIES_GOOD)
        &"sauce":
            return _anyone_holds(sim, func(item: SimItem) -> bool:
                return item.kind == Fryer.FRIES_GOOD and item.sauce == Menu.MAYO)
        &"serve":
            return sim.stats.served >= 1
        &"beer":
            return _anyone_holds(sim, func(item: SimItem) -> bool: return item.kind == Menu.BEER)
        &"serve_beer":
            return sim.stats.served >= 2
        &"extinguisher":
            return _anyone_holds(sim, func(item: SimItem) -> bool: return item.kind == Simulation.EXTINGUISHER)
        &"fire_out":
            return not _any_station(sim, func(station: SimStation) -> bool: return station.burning)
    return false


static func _any_station(sim: Simulation, test: Callable) -> bool:
    return sim.stations.any(test)


static func _anyone_holds(sim: Simulation, test: Callable) -> bool:
    return sim.players.any(func(player: SimPlayer) -> bool: return player.item != null and test.call(player.item))
