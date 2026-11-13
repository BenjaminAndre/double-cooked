class_name Tutorial
extends RefCounted
## The tutorial (GDD §4.4): quiet nights in steps, in two parts: the basics (cooking, serving, a
## fire), then the rest (throwing drinks, getting up from a K.O., grease, pigeons, the BB gun, the
## AFSCA). A step ends only once the crew has done it, whoever does; the next one may bring a
## customer, a fire, a pigeon... Nothing else happens meanwhile (Campaign.rules_for). After the
## last step the night is held.

## Each step: "id", "text" (what to do; {interagir} and {manger} stand for the keys) and
## "station", the kind of station to show, &"" for none.
const PART_1: Array[Dictionary] = [
    {"id": &"drop", "station": &"cuisson_1",
            "text": "Un client veut des frites mayo. Va au CUISSON 1 ({fleches}) et plonge un panier de frites ({interagir})."},
    {"id": &"lift", "station": &"cuisson_1",
            "text": "Première cuisson : sors le panier ({interagir}) quand le curseur est dans le vert."},
    {"id": &"portion", "station": &"cuisson_1",
            "text": "Le lot attend au-dessus du CUISSON 1 : prends-en une portion ({interagir})."},
    {"id": &"second", "station": &"cuisson_2",
            "text": "Deuxième cuisson : plonge la portion au CUISSON 2."},
    {"id": &"golden", "station": &"cuisson_2",
            "text": "Sors-les quand elles sont dorées, dans le vert. Ratées ? À la POUBELLE, et reprends une portion."},
    {"id": &"sauce", "station": &"sauces",
            "text": "Aux SAUCES, choisis la mayo ({fleches}, puis {interagir})."},
    {"id": &"serve", "station": &"caisse",
            "text": "Sers le client à la CAISSE ({interagir})."},
    {"id": &"beer", "station": &"frigo",
            "text": "Un client veut une bière : prends-en une au FRIGO."},
    {"id": &"serve_beer", "station": &"caisse",
            "text": "Sers-la à la CAISSE. Plus tard : {maintenir} pour la lancer, ou bois-la ({manger}) pour un cœur."},
    {"id": &"extinguisher", "station": &"extincteur",
            "text": "Au feu ! Prends l'EXTINCTEUR."},
    {"id": &"fire_out", "station": &"cuisson_2",
            "text": "Éteins le feu ({interagir} devant lui). Ne reste pas planté devant sans extincteur : ça brûle."},
]
## The second part (Campaign.TUTORIAL_2).
const PART_2: Array[Dictionary] = [
    {"id": &"take_drink", "station": &"frigo",
            "text": "Une cliente attend ses frites. En attendant, prends une boisson au FRIGO."},
    {"id": &"throw", "station": &"",
            "text": "Toute boisson se lance : {maintenir}, vise la cliente ({fleches}) et lâche. Offerte, elle lui rend de la patience."},
    {"id": &"knocked", "station": &"frigo",
            "text": "Aïe, K.O. ! Rampe jusqu'au FRIGO, prends une boisson et bois-la ({manger}). À plusieurs, un équipier peut t'en lancer une."},
    {"id": &"slip", "station": &"sauces",
            "text": "Une flaque de graisse devant les SAUCES : marche dessus pour voir. Ça glisse, et ce qu'on tient tombe."},
    {"id": &"shoo", "station": &"",
            "text": "Un pigeon squatte une station et bloque tout : chasse-le ({interagir} devant lui)."},
    {"id": &"gun", "station": &"caisse",
            "text": "Sous la CAISSE, il y a une carabine : prends-la ({interagir}, les mains vides)."},
    {"id": &"shoot", "station": &"",
            "text": "Un autre pigeon : {maintenir} pour viser, {fleches} pour changer de cible, lâche pour tirer. Les équipiers aussi peuvent être visés !"},
    {"id": &"afsca", "station": &"",
            "text": "Contrôle AFSCA : l'inspecteur fait le tour, et la saleté qu'il voit remplit sa jauge (vite, juste sous son nez). Pleine, c'est raté. Ou alors... vise-le."},
]

## Which part: 1 or 2.
var part := 1
## The current step (an index into steps()); steps().size() once done.
var step := 0


func _init(p_part := 1) -> void:
    part = p_part


## This part's steps.
func steps() -> Array[Dictionary]:
    return PART_2 if part == 2 else PART_1


func current() -> Dictionary:
    return steps()[step] if step < steps().size() else {}


func finished() -> bool:
    return step >= steps().size()


## Called every tick: moves on as soon as the current step is done ({"type": &"tutorial_step",
## "step": the new one}), and sets up what the next one needs.
func advance(sim: Simulation, events: Array[Dictionary]) -> void:
    if sim.tick == 0 and step == 0:
        _start(sim, events)
    while not finished() and _done(sim, steps()[step].id, events):
        _end_step(sim, steps()[step].id)
        step += 1
        events.append({"type": &"tutorial_step", "step": step})
        _start(sim, events)
    _keep(sim, events)


func fingerprint() -> Array:
    return [part, step]


func _start(sim: Simulation, events: Array[Dictionary]) -> void:
    match current().get("id", &""):
        &"drop", &"take_drink":
            sim.crowd.add_customer(StringName("frites:%s" % Menu.MAYO), events)
        &"beer":
            sim.crowd.add_customer(Menu.order_key(SimItem.new(Menu.BEER)), events)
        &"extinguisher":
            var fryer := _station_of(sim, &"cuisson_2")
            if fryer >= 0:
                sim.stations[fryer].burning = true
                events.append({"type": &"fire_started", "station": fryer})
        &"knocked":
            # The first player falls (as if burnt to their last heart).
            var player := sim.players[0]
            player.health = 0
            sim._knock_out(player)
        &"afsca":
            sim.night_events.inspect_now(events)


## What a step leaves behind that would spoil the next ones.
func _end_step(sim: Simulation, id: StringName) -> void:
    match id:
        &"knocked":
            # Back up with all their hearts: the slide that follows may end in a fryer.
            for player in sim.players:
                player.health = SimPlayer.MAX_HEALTH
        &"slip":
            # The puddle is mopped: the inspector would see it.
            sim.grease.clear()


## Keeps what the current step needs there: the puddle until someone slips on it, a pigeon until
## the crew deals with it (one may fly off with fries, or flee a fire).
func _keep(sim: Simulation, events: Array[Dictionary]) -> void:
    match current().get("id", &""):
        &"slip":
            var node := _node_of(sim, &"sauces")
            if node >= 0 and not sim.grease.has(node):
                sim._grease(node)
        &"shoo", &"shoot":
            if sim.pigeons.is_empty():
                sim._pigeon_arrives()


func _done(sim: Simulation, id: StringName, events: Array[Dictionary]) -> bool:
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
        &"take_drink":
            return _anyone_holds(sim, func(item: SimItem) -> bool: return item.kind in Menu.DRINKS)
        &"throw":
            # Caught (the landing comes after the tutorial in a tick: seen on the customer).
            return sim.crowd.line.any(func(customer: SimCrowd.Customer) -> bool: return customer.gifts > 0)
        &"knocked":
            return not sim.players.any(func(player: SimPlayer) -> bool: return player.down)
        &"slip":
            return _happened(events, [&"slipped"])
        &"shoo":
            return events.any(func(event: Dictionary) -> bool:
                return event.type == &"pigeon_left" and event.why == &"shooed")
        &"gun":
            return _anyone_holds(sim, func(item: SimItem) -> bool: return item.kind == Simulation.GUN)
        &"shoot":
            return events.any(func(event: Dictionary) -> bool:
                return event.type == &"shot" and event.target == &"pigeon")
        &"afsca":
            # Passed, failed (nothing is thrown away here) or the inspector shot: all the same.
            return sim.night_events.inspection == 0 and sim.night_events.inspector_coming == 0
    return false


static func _happened(events: Array[Dictionary], types: Array) -> bool:
    return events.any(func(event: Dictionary) -> bool: return event.type in types)


static func _station_of(sim: Simulation, kind: StringName) -> int:
    return sim.stations.find_custom(func(station: SimStation) -> bool: return station.kind == kind)


## The node in front of the first station of this kind, -1 if none.
static func _node_of(sim: Simulation, kind: StringName) -> int:
    var index := _station_of(sim, kind)
    return sim.level.node_stations.find(index) if index >= 0 else -1


static func _any_station(sim: Simulation, test: Callable) -> bool:
    return sim.stations.any(test)


static func _anyone_holds(sim: Simulation, test: Callable) -> bool:
    return sim.players.any(func(player: SimPlayer) -> bool: return player.item != null and test.call(player.item))
