class_name ItemNames
## How items, orders and actions read on screen (in French, GDD §9). Meant to shrink to
## icons over time.

const NAMES := {
    Fryer.FRIES_RAW: "frites crues",
    Fryer.FRIES_COLD: "frites froides",
    Fryer.FRIES_OVERCOOKED: "frites trop cuites",
    Fryer.FRIES_BLANCHED: "frites blanchies",
    Fryer.FRIES_SOGGY: "frites molles",
    Fryer.FRIES_GOOD: "frites",
    Fryer.FRIES_BURNT: "frites brûlées",
    Menu.CERVELAS: "cervelas froid",
    Menu.CERVELAS_WARM: "cervelas chaud",
    Menu.CERVELAS_LUKEWARM: "cervelas tiède",
    Menu.CERVELAS_BURNT: "cervelas brûlé",
    Menu.FRICADELLE_RAW: "fricadelle crue",
    Menu.FRICADELLE: "fricadelle",
    Menu.FRICADELLE_UNDERCOOKED: "fricadelle pas cuite",
    Menu.FRICADELLE_BURNT: "fricadelle brûlée",
    Menu.BOULETTE_RAW: "boulette crue",
    Menu.BOULETTE: "boulette",
    Menu.BOULETTE_UNDERCOOKED: "boulette pas cuite",
    Menu.BOULETTE_BURNT: "boulette brûlée",
    Menu.BROCHETTE_RAW: "brochette crue",
    Menu.BROCHETTE: "brochette",
    Menu.BROCHETTE_UNDERCOOKED: "brochette pas cuite",
    Menu.BROCHETTE_BURNT: "brochette brûlée",
    Menu.COLA: "cola",
    Menu.BEER: "bière",
    Menu.MAYO: "mayo",
    Menu.ANDALOUSE: "andalouse",
    Menu.KETCHUP: "ketchup",
    Menu.NATURE: "nature",
    Simulation.EXTINGUISHER: "extincteur",
    Looks.NONE: "rien",
    Looks.CAP: "casquette",
    Looks.BEER_HELMET: "casque à bières",
    Menu.PHONE_HOST: "créer",
    Menu.PHONE_JOIN: "rejoindre",
    Menu.PHONE_LEAVE: "quitter",
    Menu.DOOR_CAMPAIGN: "campagne",
    Menu.DOOR_FREE_NIGHT: "nuit libre",
}

## Dishes as customers order them (see Menu.DISHES).
const DISHES := {
    &"frites": "frites",
    &"fricadelle": "fricadelle",
    &"cervelas_froid": "cervelas froid",
    &"cervelas_chaud": "cervelas chaud",
    &"boulette": "boulette",
    &"brochette": "brochette",
    Menu.COLA: "cola",
    Menu.BEER: "bière",
}

## Short verbs for the interaction hint (see Simulation.action_for).
const ACTIONS := {
    &"choose": "choisir",
    &"throw": "lancer",
    &"extinguish": "éteindre",
    &"fry": "plonger",
    &"lift": "soulever",
    &"take": "prendre",
    &"sauce": "sauce",
    &"fridge": "boisson",
    &"eat": "manger",
    &"drink": "boire",
    &"meat": "viande",
    &"trash": "jeter",
    &"serve": "servir",
    &"take_extinguisher": "prendre",
    &"return_extinguisher": "reposer",
    &"paint": "peindre",
    &"hat": "chapeau",
    &"phone": "téléphoner",
    &"open": "ouvrir",
    &"door_wait": "les autres sur PRÊT",
    &"door_host": "l'hôte ouvre",
    &"asleep": "le client dort",
}


static func action(action_id: StringName) -> String:
    return ACTIONS.get(action_id, String(action_id))


static func word(id: StringName) -> String:
    return NAMES.get(id, String(id))


## An order line (see Menu.order_key) as [dish, sauce]; sauce is "" for a drink.
static func order_line(key: StringName) -> PackedStringArray:
    var parts := String(key).split(":")
    var dish: String = DISHES.get(StringName(parts[0]), parts[0])
    return PackedStringArray([dish, word(StringName(parts[1])) if parts.size() > 1 else ""])


static func of(item: SimItem) -> String:
    if not item:
        return "—"
    var text := word(item.kind)
    if item.portions > 1:
        text += " ×%d" % item.portions
    if item.sauce != &"":
        text += " " + word(item.sauce)
    return text
