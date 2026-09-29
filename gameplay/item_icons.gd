class_name ItemIcons
extends RefCounted
## The artist's picture for each item, order and sauce (docs/ART_PLAN.md). Failed states have
## no drawing yet: they show the right one, washed out (soggy, lukewarm, cold) or darkened
## (burnt, overcooked), until the artist draws them.

const PATH := "res://art/textures/Item_%s.png"
const WASHED := Color(0.75, 0.8, 0.85)
const BURNT := Color(0.35, 0.25, 0.2)

## Item kind -> [picture, tint].
const ITEMS := {
    Fryer.FRIES_RAW: ["Frites_Raw", Color.WHITE],
    Fryer.FRIES_COLD: ["Frites_FirstCooked", WASHED],
    Fryer.FRIES_OVERCOOKED: ["Frites_FirstCooked", BURNT],
    Fryer.FRIES_BLANCHED: ["Frites_FirstCooked", Color.WHITE],
    Fryer.FRIES_SOGGY: ["Frites_DoubleCooked", WASHED],
    Fryer.FRIES_GOOD: ["Frites_DoubleCooked", Color.WHITE],
    Fryer.FRIES_BURNT: ["Frites_DoubleCooked", BURNT],
    Menu.CERVELAS: ["Cervelas_Raw", Color.WHITE],
    Menu.CERVELAS_WARM: ["Cervelas_Cooked", Color.WHITE],
    Menu.CERVELAS_LUKEWARM: ["Cervelas_Cooked", WASHED],
    Menu.CERVELAS_BURNT: ["Cervelas_Cooked", BURNT],
    Menu.FRICADELLE_RAW: ["Fricadelle_Raw", Color.WHITE],
    Menu.FRICADELLE: ["Fricadelle_Cooked", Color.WHITE],
    Menu.FRICADELLE_UNDERCOOKED: ["Fricadelle_Raw", WASHED],
    Menu.FRICADELLE_BURNT: ["Fricadelle_Cooked", BURNT],
    Menu.COLA: ["Coca", Color.WHITE],
    Menu.BEER: ["Jupiler", Color.WHITE],
    Simulation.EXTINGUISHER: ["Extincteur", Color.WHITE],
    Menu.MAYO: ["Sauce_Mayo", Color.WHITE],
    Menu.ANDALOUSE: ["Sauce_Andalouse", Color.WHITE],
}
## Dishes as ordered (Menu.order_key) -> the item that serves them.
const DISHES := {
    &"frites": Fryer.FRIES_GOOD,
    &"fricadelle": Menu.FRICADELLE,
    &"cervelas_froid": Menu.CERVELAS,
    &"cervelas_chaud": Menu.CERVELAS_WARM,
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
    if parts.size() > 1 and StringName(parts[1]) != Menu.NATURE:
        kinds.append(StringName(parts[1]))
    return kinds
