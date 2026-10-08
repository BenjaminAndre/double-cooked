class_name Recipes
extends RefCounted
## Breads and what goes in them (GDD §7.3, the artist's recipes). PAIN hands out a burger bun or
## a baguette; with one in hand, a player fills it, in any order, still one item in the hand:
## - a burger: a steak, taken from a CUISSON VIANDE in the green; with salad and tomato from
##   VIANDES it is a burger complet;
## - a mitraillette: a meat (fricadelle, warm cervelas or brochette) taken from a CUISSON VIANDE
##   in the green, and a portion of fries taken from CUISSON 2 in the green.
## SAUCES adds a sauce to either. The other way round works too: holding a good meat (or fries,
## for a baguette), PAIN wraps it in the bread chosen.

const BREADS: Array[StringName] = [Menu.BUN, Menu.BAGUETTE]
## What a bread holds once full enough to be served, as ordered (Menu.order_key).
const BURGER := &"burger"
const BURGER_COMPLET := &"burger_complet"
const MITRAILLETTE := &"mitraillette"
const DISHES: Array[StringName] = [BURGER, BURGER_COMPLET, MITRAILLETTE]
## The cooked meats each bread takes.
const FILLINGS := {
    Menu.BUN: [Menu.STEAK],
    Menu.BAGUETTE: [Menu.FRICADELLE, Menu.CERVELAS_WARM, Menu.BROCHETTE],
}


static func is_bread(item: SimItem) -> bool:
    return item != null and item.kind in BREADS


## Whether this bread takes the meat of this kind (done right: a bread only takes it in time).
static func takes_meat(bread: SimItem, meat_kind: StringName) -> bool:
    return is_bread(bread) and bread.filling == null and meat_kind in FILLINGS[bread.kind]


## Whether this bread takes a portion of fries: a baguette without any yet.
static func takes_fries(bread: SimItem) -> bool:
    return is_bread(bread) and bread.kind == Menu.BAGUETTE and bread.fries == null


## Whether VIANDES can add salad and tomato: a bun without them yet.
static func takes_veg(bread: SimItem) -> bool:
    return is_bread(bread) and bread.kind == Menu.BUN and not bread.veg


## PAIN with something in hand: the chosen bread around it, null if it doesn't go in.
static func wrap(held: SimItem, bread_kind: StringName) -> SimItem:
    var bread := SimItem.new(bread_kind)
    if held.sauce != &"":
        return null
    if takes_meat(bread, held.kind):
        bread.filling = held
        return bread
    if held.kind == Fryer.FRIES_GOOD and takes_fries(bread):
        bread.fries = held
        return bread
    return null


## The dish this bread makes as it is, &"" while it isn't one yet.
static func dish(bread: SimItem) -> StringName:
    match bread.kind:
        Menu.BUN:
            if bread.filling:
                return BURGER_COMPLET if bread.veg else BURGER
        Menu.BAGUETTE:
            if bread.filling and bread.fries:
                return MITRAILLETTE
    return &""


## A bread is only as good as what is in it.
static func done_right(bread: SimItem) -> bool:
    for part: SimItem in [bread.filling, bread.fries]:
        if part and not Menu.done_right(part):
            return false
    return true
