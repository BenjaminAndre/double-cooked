class_name ItemIcons
extends RefCounted
## The artist's picture for each item, order and sauce (docs/ART_PLAN.md), burnt ones included.
## The other failed states have no drawing: they show the right one washed out (soggy,
## lukewarm, cold, undercooked).

const PATH := "res://art/textures/Item_%s.png"
const WASHED := Color(0.75, 0.8, 0.85)
## The salad and tomato of a burger complet, drawn as an item of their own.
const LEGUMES := &"legumes"

## Item kind -> [picture, tint].
const ITEMS := {
    Fryer.FRIES_RAW: ["Frites_Raw", Color.WHITE],
    Fryer.FRIES_COLD: ["Frites_FirstCooked", WASHED],
    Fryer.FRIES_OVERCOOKED: ["Frites_Burned", Color.WHITE],
    Fryer.FRIES_BLANCHED: ["Frites_FirstCooked", Color.WHITE],
    Fryer.FRIES_SOGGY: ["Frites_DoubleCooked", WASHED],
    Fryer.FRIES_GOOD: ["Frites_DoubleCooked", Color.WHITE],
    Fryer.FRIES_BURNT: ["Frites_Burned", Color.WHITE],
    Menu.CERVELAS: ["Cervelas_Raw", Color.WHITE],
    Menu.CERVELAS_WARM: ["Cervelas_Cooked", Color.WHITE],
    Menu.CERVELAS_LUKEWARM: ["Cervelas_Cooked", WASHED],
    Menu.CERVELAS_BURNT: ["Cervelas_Burned", Color.WHITE],
    Menu.FRICADELLE_RAW: ["Fricadelle_Raw", Color.WHITE],
    Menu.FRICADELLE: ["Fricadelle_Cooked", Color.WHITE],
    Menu.FRICADELLE_UNDERCOOKED: ["Fricadelle_Raw", WASHED],
    Menu.FRICADELLE_BURNT: ["Fricadelle_Burned", Color.WHITE],
    Menu.BOULETTE_RAW: ["Boulette_Raw", Color.WHITE],
    Menu.BOULETTE: ["Boulette_Cooked", Color.WHITE],
    Menu.BOULETTE_UNDERCOOKED: ["Boulette_Raw", WASHED],
    Menu.BOULETTE_BURNT: ["Boulette_Burned", Color.WHITE],
    Menu.BROCHETTE_RAW: ["Brochette_Raw", Color.WHITE],
    Menu.BROCHETTE: ["Brochette_Cooked", Color.WHITE],
    Menu.BROCHETTE_UNDERCOOKED: ["Brochette_Raw", WASHED],
    Menu.BROCHETTE_BURNT: ["Brochette_Burned", Color.WHITE],
    Menu.STEAK_RAW: ["ViandeBurger_Raw", Color.WHITE],
    Menu.STEAK: ["ViandeBurger_Cooked", Color.WHITE],
    Menu.STEAK_UNDERCOOKED: ["ViandeBurger_Raw", WASHED],
    Menu.STEAK_BURNT: ["ViandeBurger_Burned", Color.WHITE],
    Menu.BUN: ["PainBurger", Color.WHITE],
    Menu.BAGUETTE: ["Baguette", Color.WHITE],
    # The dishes in a bread, and the salad and tomato of a burger complet.
    &"burger": ["Burger", Color.WHITE],
    &"mitraillette": ["Mitraillette", Color.WHITE],
    LEGUMES: ["SaladeTomate", Color.WHITE],
    Menu.COLA: ["Coca", Color.WHITE],
    Menu.BEER: ["Jupiler", Color.WHITE],
    Simulation.EXTINGUISHER: ["Extincteur", Color.WHITE],
    Menu.MAYO: ["Sauce_Mayo", Color.WHITE],
    Menu.ANDALOUSE: ["Sauce_Andalouse", Color.WHITE],
    Menu.KETCHUP: ["Sauce_Ketchup", Color.WHITE],
}
## Dishes as ordered (Menu.order_key) -> the item that serves them.
const DISHES := {
    &"frites": Fryer.FRIES_GOOD,
    &"fricadelle": Menu.FRICADELLE,
    &"cervelas_froid": Menu.CERVELAS,
    &"cervelas_chaud": Menu.CERVELAS_WARM,
    &"boulette": Menu.BOULETTE,
    &"brochette": Menu.BROCHETTE,
    &"burger": &"burger",
    &"mitraillette": &"mitraillette",
    Menu.COLA: Menu.COLA,
    Menu.BEER: Menu.BEER,
}


## The picture of an item kind or sauce, null if there is none.
static func picture(kind: StringName) -> Texture2D:
    return load(PATH % ITEMS[kind][0]) if ITEMS.has(kind) else null


static func tint(kind: StringName) -> Color:
    return ITEMS[kind][1] if ITEMS.has(kind) else Color.WHITE


## An order line (Menu.order_key) as the kinds to draw: the dish, then its sauce unless nature.
static func order(key: StringName) -> Array[StringName]:
    var parts := String(key).split(":")
    var kinds: Array[StringName] = [DISHES.get(StringName(parts[0]), StringName(parts[0]))]
    if parts[0] == "burger_complet":
        kinds = [&"burger", LEGUMES]
    if parts.size() > 1 and StringName(parts[1]) != Menu.NATURE:
        kinds.append(StringName(parts[1]))
    return kinds


## What a held item shows, the main picture first: a bread shows what it has become (a burger,
## a mitraillette) or what is in it so far; anything else, itself.
static func held(item: SimItem) -> Array[StringName]:
    if not Recipes.is_bread(item):
        return [item.kind]
    var kinds: Array[StringName] = []
    match Recipes.dish(item):
        Recipes.BURGER, Recipes.BURGER_COMPLET:
            kinds.append(&"burger")
        Recipes.MITRAILLETTE:
            kinds.append(&"mitraillette")
        _:
            kinds.append(item.kind)
            for part: SimItem in [item.filling, item.fries]:
                if part:
                    kinds.append(part.kind)
    if item.veg:
        kinds.append(LEGUMES)
    return kinds
