class_name Menu
extends RefCounted
## The fritkot's menu (GDD §7.2): what the menu stations offer, what CUISSON 2 turns things
## into, what each item counts as when served, and how customers pick their orders.
##
## A customer orders one line, one hand's worth: fries with a sauce, a meat with a sauce, or a drink.
## Its key reads "frites:mayo", "cervelas_chaud:nature" or "cola".

const MAYO := &"mayo"
const ANDALOUSE := &"andalouse"
## No sauce, which customers ask for too.
const NATURE := &"nature"
const SAUCES: Array[StringName] = [MAYO, ANDALOUSE]

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
const MEATS: Array[StringName] = [CERVELAS, FRICADELLE_RAW]

## The options of each station that opens a menu (GDD §5.4).
const STATION_OPTIONS := {
    &"sauces": SAUCES,
    &"frigo": DRINKS,
    &"viandes": MEATS,
}

## What CUISSON 2 gives back for each thing it accepts, lifted [too early, in time, too late].
const SECOND_FRY := {
    Fryer.FRIES_BLANCHED: [Fryer.FRIES_SOGGY, Fryer.FRIES_GOOD, Fryer.FRIES_BURNT],
    FRICADELLE_RAW: [FRICADELLE_UNDERCOOKED, FRICADELLE, FRICADELLE_BURNT],
    CERVELAS: [CERVELAS_LUKEWARM, CERVELAS_WARM, CERVELAS_BURNT],
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
    COLA: [COLA, true],
    BEER: [BEER, true],
}

## The dishes an order line can ask for, per category.
const FRIES_DISHES: Array[StringName] = [&"frites"]
const MEAT_DISHES: Array[StringName] = [&"fricadelle", &"cervelas_froid", &"cervelas_chaud"]


## Whether SAUCES can go on this item: a servable food without a sauce yet.
static func takes_sauce(item: SimItem) -> bool:
    return item != null and DISHES.has(item.kind) and not item.kind in DRINKS and item.sauce == &""


## The order line this item fulfils, &"" when it isn't servable.
static func order_key(item: SimItem) -> StringName:
    if not item or not DISHES.has(item.kind):
        return &""
    var dish: StringName = DISHES[item.kind][0]
    if item.kind in DRINKS:
        return dish
    return StringName("%s:%s" % [dish, item.sauce if item.sauce != &"" else NATURE])


static func done_right(item: SimItem) -> bool:
    return DISHES.has(item.kind) and DISHES[item.kind][1]


## One order line: fries, a meat or a drink, picked by category_weights, then a dish and a
## sauce at random.
static func random_order(rng: RandomNumberGenerator, category_weights: PackedFloat32Array) -> StringName:
    match rng.rand_weighted(category_weights):
        0:
            return _with_sauce(FRIES_DISHES[0], rng)
        1:
            return _with_sauce(MEAT_DISHES[rng.randi_range(0, MEAT_DISHES.size() - 1)], rng)
    return DRINKS[rng.randi_range(0, DRINKS.size() - 1)]


static func _with_sauce(dish: StringName, rng: RandomNumberGenerator) -> StringName:
    var sauces := [NATURE, MAYO, ANDALOUSE]
    return StringName("%s:%s" % [dish, sauces[rng.randi_range(0, sauces.size() - 1)]])
