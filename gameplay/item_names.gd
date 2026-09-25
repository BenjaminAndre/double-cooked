class_name ItemNames
## How items read on screen (in French, GDD §9).

const NAMES := {
    Fryer.FRIES_RAW: "frites crues",
    Fryer.FRIES_COLD: "frites froides",
    Fryer.FRIES_OVERCOOKED: "frites trop cuites",
    Fryer.FRIES_RESTING: "frites au repos",
    Fryer.FRIES_SOGGY: "frites molles",
    Fryer.FRIES_GOOD: "frites",
    Fryer.FRIES_BURNT: "frites brûlées",
    Simulation.EXTINGUISHER: "extincteur",
}


const DISHES := {
    SimCrowd.FRITES_MAYO: "frites mayo",
}


static func dish(dish_id: StringName) -> String:
    return DISHES.get(dish_id, String(dish_id))


static func of(item: SimItem) -> String:
    if not item:
        return "—"
    var text: String = NAMES.get(item.kind, String(item.kind))
    if item.kind == Fryer.FRIES_RESTING and item.rest >= Fryer.REST_NEEDED:
        text += " ✓"
    if item.sauce:
        text += " mayo"
    return text
