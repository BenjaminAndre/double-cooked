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
    Menu.GRIZZLY_RAW: ["Grizzly_Raw", Color.WHITE],
    Menu.GRIZZLY: ["Grizzly_Cooked", Color.WHITE],
    Menu.GRIZZLY_UNDERCOOKED: ["Grizzly_Raw", WASHED],
    Menu.GRIZZLY_BURNT: ["Grizzly_Burned", Color.WHITE],
    Menu.BUN: ["PainBurger", Color.WHITE],
    Menu.BAGUETTE: ["Baguette", Color.WHITE],
    # The dishes in a bread, and the salad and tomato of a burger complet.
    &"burger": ["Burger", Color.WHITE],
    &"mitraillette": ["Mitraillette", Color.WHITE],
    LEGUMES: ["SaladeTomate", Color.WHITE],
    Menu.COLA: ["Coca", Color.WHITE],
    Menu.BEER: ["Jupiler", Color.WHITE],
    Menu.MAES: ["Maes", Color.WHITE],
    Menu.SPRITE: ["Sprite", Color.WHITE],
    Simulation.EXTINGUISHER: ["Extincteur", Color.WHITE],
    Menu.MAYO: ["Sauce_Mayo", Color.WHITE],
    Menu.ANDALOUSE: ["Sauce_Andalouse", Color.WHITE],
    Menu.KETCHUP: ["Sauce_Ketchup", Color.WHITE],
    Menu.RICHE: ["Sauce_Riche", Color.WHITE],
}
## Dishes as ordered (Menu.order_key) -> the item that serves them.
const DISHES := {
    &"frites": Fryer.FRIES_GOOD,
    &"fricadelle": Menu.FRICADELLE,
    &"cervelas_froid": Menu.CERVELAS,
    &"cervelas_chaud": Menu.CERVELAS_WARM,
    &"boulette": Menu.BOULETTE,
    &"brochette": Menu.BROCHETTE,
    &"grizzly": Menu.GRIZZLY,
    &"burger": &"burger",
    &"mitraillette": &"mitraillette",
    Menu.COLA: Menu.COLA,
    Menu.BEER: Menu.BEER,
    Menu.MAES: Menu.MAES,
    Menu.SPRITE: Menu.SPRITE,
}


## The picture of an item kind or sauce, null if there is none.
static func picture(kind: StringName) -> Texture2D:
    if String(kind).begins_with("mitraillette"):
        return load(PATH % mitraillette(kind))
    if kind == Simulation.GUN:
        return _gun()
    return load(PATH % ITEMS[kind][0]) if ITEMS.has(kind) else null


static var _gun_picture: Texture2D


## The yellow BB gun, drawn in code until the artist draws it: a body, a barrel and a grip.
static func _gun() -> Texture2D:
    if not _gun_picture:
        var image := Image.create(96, 64, false, Image.FORMAT_RGBA8)
        for part: Rect2i in [Rect2i(8, 18, 72, 16), Rect2i(78, 22, 16, 8), Rect2i(14, 32, 18, 26)]:
            image.fill_rect(part.grow(2), Color(0.15, 0.1, 0.05))
        for part: Rect2i in [Rect2i(8, 18, 72, 16), Rect2i(78, 22, 16, 8), Rect2i(14, 32, 18, 26)]:
            image.fill_rect(part, Color(1.0, 0.85, 0.1))
        _gun_picture = ImageTexture.create_from_image(image)
    return _gun_picture


static func tint(kind: StringName) -> Color:
    return ITEMS[kind][1] if ITEMS.has(kind) else Color.WHITE


## An order line (Menu.order_key) as the kinds to draw: the dish, then its sauce unless nature.
static func order(key: StringName) -> Array[StringName]:
    var parts := String(key).split(":")
    # A mitraillette's picture has its sauce and crudités in it.
    if StringName(parts[0]) in Recipes.MITRAILLETTES:
        return [key]
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
    # A mitraillette's picture has its sauce and crudités in it.
    if Recipes.dish(item) in Recipes.MITRAILLETTES:
        return [Menu.order_key(item)]
    var kinds: Array[StringName] = []
    match Recipes.dish(item):
        Recipes.BURGER, Recipes.BURGER_COMPLET:
            kinds.append(&"burger")
        _:
            kinds.append(item.kind)
            for part: SimItem in [item.filling, item.fries]:
                if part:
                    kinds.append(part.kind)
    if item.veg:
        kinds.append(LEGUMES)
    return kinds


## The artist's picture of a mitraillette (DLC 1), from its order key or dish: fricadelle or
## grizzly, with or without crudités, and its sauce (mayo, the plain picture, when none yet).
static func mitraillette(key: StringName) -> String:
    var parts := String(key).split(":")
    var dish := parts[0]
    var name := "Mitraillette"
    if dish.contains("grizzly"):
        name += "Grizzly"
    if dish.contains("crudites"):
        name += "Crudités"
    var sauce := parts[1] if parts.size() > 1 else ""
    if sauce in [String(Menu.ANDALOUSE), String(Menu.KETCHUP), String(Menu.RICHE)]:
        name += "_" + sauce.capitalize()
    return name
