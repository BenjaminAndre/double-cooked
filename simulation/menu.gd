class_name Menu
extends RefCounted
## The fritkot's menu (GDD §7.2): what the menu stations offer, what CUISSON 2 turns things
## into, what each item counts as when served, and how customers pick their orders.
##
## A customer orders one line, one hand's worth: fries with a sauce, a meat with a sauce, or a drink.
## Its key reads "frites:mayo", "cervelas_chaud:nature" or "cola".

const MAYO := &"mayo"
const ANDALOUSE := &"andalouse"
const KETCHUP := &"ketchup"
## No sauce, which customers ask for too.
const NATURE := &"nature"
const SAUCES: Array[StringName] = [MAYO, ANDALOUSE, KETCHUP]

const COLA := &"cola"
const BEER := &"biere"
const DRINKS: Array[StringName] = [COLA, BEER]

## Cold, straight from VIANDES; fried in CUISSON 2 it becomes a warm one.
const CERVELAS := &"cervelas"
const CERVELAS_WARM := &"cervelas_chaud"
const CERVELAS_LUKEWARM := &"cervelas_tiede"
const CERVELAS_BURNT := &"cervelas_brule"
const FRICADELLE_RAW := &"fricadelle_crue"
const FRICADELLE := &"fricadelle"
const FRICADELLE_UNDERCOOKED := &"fricadelle_pas_cuite"
const FRICADELLE_BURNT := &"fricadelle_brulee"
## Fried in CUISSON 2 from raw, like the fricadelle.
const BOULETTE_RAW := &"boulette_crue"
const BOULETTE := &"boulette"
const BOULETTE_UNDERCOOKED := &"boulette_pas_cuite"
const BOULETTE_BURNT := &"boulette_brulee"
const BROCHETTE_RAW := &"brochette_crue"
const BROCHETTE := &"brochette"
const BROCHETTE_UNDERCOOKED := &"brochette_pas_cuite"
const BROCHETTE_BURNT := &"brochette_brulee"
## The burger's steak, fried in a CUISSON VIANDE like the others (Recipes).
const STEAK_RAW := &"steak_cru"
const STEAK := &"steak"
const STEAK_UNDERCOOKED := &"steak_pas_cuit"
const STEAK_BURNT := &"steak_brule"
## The breads PAIN hands out (Recipes).
const BUN := &"pain_burger"
const BAGUETTE := &"baguette"
const BREADS: Array[StringName] = [BUN, BAGUETTE]
## What VIANDES hands out, the most common first.
const MEATS: Array[StringName] = [CERVELAS, FRICADELLE_RAW, BOULETTE_RAW, BROCHETTE_RAW, STEAK_RAW]

## The lobby's TÉLÉPHONE: play online or on this keyboard (GDD §4.1).
const PHONE_HOST := &"creer"
const PHONE_JOIN := &"rejoindre"
const PHONE_DUO := &"duo"
const PHONE_LEAVE := &"quitter"
const PHONE: Array[StringName] = [PHONE_HOST, PHONE_JOIN, PHONE_DUO, PHONE_LEAVE]
## The lobby's PORTE: a campaign (GDD §4.2) or the Nuit unique, a score attack (GDD §4.3).
const DOOR_CAMPAIGN := &"campagne"
const DOOR_SINGLE_NIGHT := &"nuit_unique"
const DOOR: Array[StringName] = [DOOR_CAMPAIGN, DOOR_SINGLE_NIGHT]

## The options of each station that opens a menu (GDD §5.4).
const STATION_OPTIONS := {
    &"sauces": SAUCES,
    &"frigo": DRINKS,
    &"viandes": MEATS,
    &"pain": BREADS,
    &"peinture": Looks.COLORS,
    &"casquette": Looks.HATS,
    &"telephone": PHONE,
    &"porte": DOOR,
}
## Where each option sits in a menu (GDD §5.4), as (column, row) on a 3 × 3 grid. A menu opens
## on its first option, in the centre, and grows by steps without moving the options already
## there: right, left, then below, bottom right, bottom left, then above, top right, top left.
## So the first option should be the most common choice.
const CELLS: Array[Vector2i] = [Vector2i(1, 1), Vector2i(2, 1), Vector2i(0, 1), Vector2i(1, 2),
        Vector2i(2, 2), Vector2i(0, 2), Vector2i(1, 0), Vector2i(2, 0), Vector2i(0, 0)]


## The option at this cell of a menu of this many options, -1 for an empty cell.
static func option_at(cell: Vector2i, count: int) -> int:
    var index := CELLS.find(cell)
    return index if index >= 0 and index < count else -1

## What CUISSON 2 gives back for each thing it accepts, lifted [too early, in time, too late].
const SECOND_FRY := {
    Fryer.FRIES_BLANCHED: [Fryer.FRIES_SOGGY, Fryer.FRIES_GOOD, Fryer.FRIES_BURNT],
    FRICADELLE_RAW: [FRICADELLE_UNDERCOOKED, FRICADELLE, FRICADELLE_BURNT],
    CERVELAS: [CERVELAS_LUKEWARM, CERVELAS_WARM, CERVELAS_BURNT],
    BOULETTE_RAW: [BOULETTE_UNDERCOOKED, BOULETTE, BOULETTE_BURNT],
    BROCHETTE_RAW: [BROCHETTE_UNDERCOOKED, BROCHETTE, BROCHETTE_BURNT],
    STEAK_RAW: [STEAK_UNDERCOOKED, STEAK, STEAK_BURNT],
}

## Servable items: [the dish they count as, whether they were done right].
const DISHES := {
    Fryer.FRIES_GOOD: [&"frites", true],
    Fryer.FRIES_SOGGY: [&"frites", false],
    Fryer.FRIES_BURNT: [&"frites", false],
    FRICADELLE: [&"fricadelle", true],
    FRICADELLE_UNDERCOOKED: [&"fricadelle", false],
    FRICADELLE_BURNT: [&"fricadelle", false],
    CERVELAS: [&"cervelas_froid", true],
    CERVELAS_WARM: [&"cervelas_chaud", true],
    CERVELAS_LUKEWARM: [&"cervelas_chaud", false],
    CERVELAS_BURNT: [&"cervelas_chaud", false],
    BOULETTE: [&"boulette", true],
    BOULETTE_UNDERCOOKED: [&"boulette", false],
    BOULETTE_BURNT: [&"boulette", false],
    BROCHETTE: [&"brochette", true],
    BROCHETTE_UNDERCOOKED: [&"brochette", false],
    BROCHETTE_BURNT: [&"brochette", false],
    # Served alone, a steak is the wrong dish: it is for burgers.
    STEAK: [&"steak", true],
    STEAK_UNDERCOOKED: [&"steak", false],
    STEAK_BURNT: [&"steak", false],
    COLA: [COLA, true],
    BEER: [BEER, true],
}

## The dishes an order line can ask for, per category.
const FRIES_DISHES: Array[StringName] = [&"frites"]
const MEAT_DISHES: Array[StringName] = [&"fricadelle", &"cervelas_froid", &"cervelas_chaud", &"boulette",
        &"brochette"]
## The dishes a CUISSON VIANDE cooks.
const COOKED_MEATS: Array[StringName] = [&"cervelas_chaud", &"fricadelle", &"boulette", &"brochette",
        &"burger", &"burger_complet", &"mitraillette"]
## Which dish each raw meat from VIANDES leads to.
const MEAT_FOR := {
    CERVELAS: [&"cervelas_froid", &"cervelas_chaud"],
    FRICADELLE_RAW: [&"fricadelle"],
    BOULETTE_RAW: [&"boulette"],
    BROCHETTE_RAW: [&"brochette"],
    STEAK_RAW: [&"burger", &"burger_complet"],
}
## The dishes in a bread (Recipes.DISHES), ordered like the meats.
const BREAD_DISHES: Array[StringName] = [&"burger", &"burger_complet", &"mitraillette"]
## Everything a menu can hold (see SimRules.menu): dishes, sauces and drinks, as ordered.
const FULL_MENU: Array[StringName] = [&"frites", NATURE, MAYO, ANDALOUSE, KETCHUP, &"cervelas_froid",
        &"fricadelle", COLA, BEER, &"cervelas_chaud", &"boulette", &"brochette", &"burger", &"burger_complet",
        &"mitraillette"]


## Whether SAUCES can go on this item: a servable food or a bread, without a sauce yet.
static func takes_sauce(item: SimItem) -> bool:
    return item != null and (DISHES.has(item.kind) and not item.kind in DRINKS or item.kind in BREADS) \
            and item.sauce == &""


## The order line this item fulfils, &"" when it isn't servable.
static func order_key(item: SimItem) -> StringName:
    if item and item.kind in BREADS:
        var bread_dish := Recipes.dish(item)
        if bread_dish == &"":
            return &""
        return StringName("%s:%s" % [bread_dish, item.sauce if item.sauce != &"" else NATURE])
    if not item or not DISHES.has(item.kind):
        return &""
    var dish: StringName = DISHES[item.kind][0]
    if item.kind in DRINKS:
        return dish
    return StringName("%s:%s" % [dish, item.sauce if item.sauce != &"" else NATURE])


static func done_right(item: SimItem) -> bool:
    if item.kind in BREADS:
        return Recipes.done_right(item)
    return DISHES.has(item.kind) and DISHES[item.kind][1]


## One order line from what is on the menu (SimRules.menu): fries, a meat or a drink, picked by
## category_weights, then a dish and a sauce at random. food_only: no drinks (the boss takes his
## on the side).
static func random_order(rng: RandomNumberGenerator, category_weights: PackedFloat32Array,
        menu: Array[StringName] = FULL_MENU, food_only := false) -> StringName:
    var fries := FRIES_DISHES.filter(func(dish: StringName) -> bool: return dish in menu)
    # The breads count as meat dishes.
    var meats := (MEAT_DISHES + BREAD_DISHES).filter(func(dish: StringName) -> bool: return dish in menu)
    var drinks := DRINKS.filter(func(drink: StringName) -> bool: return drink in menu)
    var weights := category_weights.duplicate()
    for category: int in 3:
        if [fries, meats, drinks][category].is_empty() or (food_only and category == 2):
            weights[category] = 0.0
    match rng.rand_weighted(weights):
        0:
            return _with_sauce(fries[rng.randi_range(0, fries.size() - 1)], rng, menu)
        1:
            return _with_sauce(meats[rng.randi_range(0, meats.size() - 1)], rng, menu)
    return drinks[rng.randi_range(0, drinks.size() - 1)]


static func _with_sauce(dish: StringName, rng: RandomNumberGenerator, menu: Array[StringName]) -> StringName:
    var sauces := [NATURE] + SAUCES.filter(func(sauce: StringName) -> bool: return sauce in menu)
    return StringName("%s:%s" % [dish, sauces[rng.randi_range(0, sauces.size() - 1)]])


## What a station's menu offers tonight: only what the menu needs (SAUCES and FRIGO what is on
## it, VIANDES the meats of dishes on it, PAIN the breads); other menus are always whole.
static func options(kind: StringName, menu: Array[StringName] = FULL_MENU) -> Array:
    var all: Array = STATION_OPTIONS[kind]
    match kind:
        &"sauces", &"frigo":
            return all.filter(func(option: StringName) -> bool: return option in menu)
        &"viandes":
            return all.filter(func(meat: StringName) -> bool:
                return MEAT_FOR[meat].any(func(dish: StringName) -> bool: return dish in menu))
        &"pain":
            return all.filter(func(bread: StringName) -> bool: return _bread_needed(bread, menu))
    return all


## Whether a dish on the menu is made in this bread (Recipes).
static func _bread_needed(bread: StringName, menu: Array[StringName]) -> bool:
    if bread == BUN:
        return &"burger" in menu or &"burger_complet" in menu
    return &"mitraillette" in menu


## Whether a station has anything to do tonight; one that hasn't is greyed out and does nothing
## (GDD §4.2).
static func station_in_use(kind: StringName, menu: Array[StringName] = FULL_MENU) -> bool:
    match kind:
        &"cuisson_viande":
            return COOKED_MEATS.any(func(dish: StringName) -> bool: return dish in menu)
        &"sauces", &"frigo", &"viandes", &"pain":
            return not options(kind, menu).is_empty()
    return true


## Whether a player can eat or drink this to get a heart back: anything from the kitchen,
## however badly done, but not the extinguisher (GDD §5.1).
static func edible(item: SimItem) -> bool:
    return item != null and item.kind != Simulation.EXTINGUISHER
