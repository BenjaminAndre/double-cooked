class_name Campaign
extends RefCounted
## The campaign (GDD §4.2): nights one after the other until the crew falls, like the rounds of
## a zombie game. Each night is a little busier than the last, and the menu grows: fries and
## beer on the first (a knocked-out player always has a beer to crawl to), then sauces and
## cola, cold cervelas, fricadelle, and so on.

## What each night adds to the menu (Menu.FULL_MENU), from the first.
const UNLOCKS: Array = [
    [&"frites", Menu.NATURE, Menu.BEER],
    [Menu.MAYO, Menu.ANDALOUSE, Menu.COLA],
    [&"cervelas_froid"],
    [&"fricadelle"],
    [&"cervelas_chaud"],
    [Menu.KETCHUP],
    [&"boulette"],
    [&"brochette"],
]


## The menu of this night of a campaign: everything unlocked so far.
static func menu_for(night: int) -> Array[StringName]:
    var menu: Array[StringName] = []
    for index in mini(night, UNLOCKS.size()):
        for entry: StringName in UNLOCKS[index]:
            menu.append(entry)
    return menu


## The rules of a night: night 0 is a single night, with the whole menu at the base pace.
static func rules_for(night: int) -> SimRules:
    var rules := SimRules.new()
    if night > 0:
        rules.night_number = night
        rules.menu = menu_for(night)
    return rules


## What the menu gets new tonight, for the start of the night (nothing on the first).
static func new_on(night: int) -> Array[StringName]:
    var added: Array[StringName] = []
    if night >= 2 and night - 1 < UNLOCKS.size():
        for entry: StringName in UNLOCKS[night - 1]:
            added.append(entry)
    return added
