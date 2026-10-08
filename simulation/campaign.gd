class_name Campaign
extends RefCounted
## The campaign (GDD §4.2): nights one after the other until the crew falls, like the rounds of
## a zombie game. Each night is a little busier than the last, and the menu grows: fries and
## beer on the first (a knocked-out player always has a beer to crawl to), then sauces and
## cola, cold cervelas, fricadelle, and so on.

## Each night is a day of the week, from Monday, then the next week (the artist's idea).
const DAYS: Array[String] = ["lundi", "mardi", "mercredi", "jeudi", "vendredi", "samedi", "dimanche"]

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


## The day of the week of this night of a campaign, from 1 (lundi).
static func day(night: int) -> String:
    return DAYS[(maxi(night, 1) - 1) % DAYS.size()]


## Which week this night falls in, from 1.
static func week(night: int) -> int:
    return (maxi(night, 1) - 1) / DAYS.size() + 1


## The night as players read it: "mardi", then "mardi, semaine 2" from the second week.
static func day_label(night: int) -> String:
    return day(night) if week(night) == 1 else "%s, semaine %d" % [day(night), week(night)]


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
