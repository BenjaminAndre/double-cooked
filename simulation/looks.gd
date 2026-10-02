class_name Looks
extends RefCounted
## What a player looks like (GDD §5.5), chosen in the lobby: one of the four characters, told
## apart by their T-shirt colour, unique within the team, which stands for the player
## everywhere instead of "P1"; and a hat, just for fun.

const COLORS: Array[StringName] = [&"bleu", &"rouge", &"vert", &"jaune"]
## The same T-shirt colours, for the display (the artist's MainCharacter01 to 04).
const TINTS: Array[Color] = [Color(0.24, 0.49, 0.73), Color(0.69, 0.12, 0.12), Color(0.24, 0.69, 0.26),
        Color(0.91, 0.83, 0.23)]
const CHARACTERS := "res://art/textures/MainCharacter%02d.png"
const CHARACTERS_FAT := "res://art/textures/MainCharacter%02d_Fat%02d.png"
const FAT_PICTURES := 3
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


## The character drawn in this colour.
## fat: 0 for the drawing as is, 1 to 3 for the artist's fatter ones (MainCharacterXX_FatYY).
static func character(color: int, fat := 0) -> Texture2D:
    var number := clampi(color, 0, COLORS.size() - 1) + 1
    if fat > 0:
        return load(CHARACTERS_FAT % [number, mini(fat, FAT_PICTURES)])
    return load(CHARACTERS % number)
