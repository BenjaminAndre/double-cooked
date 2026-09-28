class_name Looks
extends RefCounted
## What a player looks like (GDD §5.5), chosen in the lobby: a colour, unique within the team,
## which stands for the player everywhere instead of "P1", and a hat, just for fun.

const COLORS: Array[StringName] = [&"bleu", &"rouge", &"vert", &"jaune", &"orange", &"violet",
        &"rose", &"cyan", &"blanc"]
## The same colours, for the display.
const TINTS: Array[Color] = [Color(0.25, 0.45, 0.95), Color(0.9, 0.2, 0.2), Color(0.25, 0.75, 0.3),
        Color(0.95, 0.85, 0.2), Color(1.0, 0.55, 0.15), Color(0.6, 0.3, 0.85),
        Color(1.0, 0.5, 0.75), Color(0.25, 0.85, 0.9), Color(0.95, 0.95, 0.95)]
const NONE := &"rien"
const CAP := &"casquette"
const BEER_HELMET := &"casque_bieres"
const HATS: Array[StringName] = [NONE, CAP, BEER_HELMET]
const DEFAULT_HAT := 1


## The colour a player starts with: their slot's, so a team starts with distinct colours.
static func default_color(slot: int) -> int:
    return slot % COLORS.size()


## A colour and a hat as one Simulation command (Simulation.LOOK), so choosing them is
## replayed and relayed like any key press.
static func command(color: int, hat: int) -> int:
    return Simulation.LOOK + color * HATS.size() + hat


static func tint(color: int) -> Color:
    return TINTS[color] if color >= 0 and color < TINTS.size() else Color.WHITE


## "Rouge", for messages about a player.
static func player_name(color: int) -> String:
    return String(COLORS[color]).capitalize() if color >= 0 and color < COLORS.size() else "?"
