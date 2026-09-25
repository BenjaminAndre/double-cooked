class_name ItemNames
## How items read on screen (in French, GDD §9).

const NAMES := {
    Fryer.FRIES_RAW: "frites crues",
    Fryer.FRIES_COLD: "frites froides",
    Fryer.FRIES_OVERCOOKED: "frites trop cuites",
    Fryer.FRIES_BLANCHED: "frites blanchies",
    Fryer.FRIES_SOGGY: "frites molles",
    Fryer.FRIES_GOOD: "frites",
    Fryer.FRIES_BURNT: "frites brûlées",
    Simulation.EXTINGUISHER: "extincteur",
}


const DISHES := {
    SimCrowd.FRITES_MAYO: "frites mayo",
}


## Short verbs for the interaction hint (see Simulation.action_for). Meant to become icons.
const ACTIONS := {
    &"revive": "relever",
    &"extinguish": "éteindre",
    &"heal": "se soigner",
    &"fry": "plonger",
    &"lift": "soulever",
    &"take": "prendre",
    &"sauce": "mayo",
    &"trash": "jeter",
    &"serve": "servir",
    &"take_extinguisher": "prendre",
    &"return_extinguisher": "reposer",
}


static func action(action_id: StringName) -> String:
    return ACTIONS.get(action_id, String(action_id))


static func dish(dish_id: StringName) -> String:
    return DISHES.get(dish_id, String(dish_id))


static func of(item: SimItem) -> String:
    if not item:
        return "—"
    var text: String = NAMES.get(item.kind, String(item.kind))
    if item.portions > 1:
        text += " ×%d" % item.portions
    if item.sauce:
        text += " mayo"
    return text
