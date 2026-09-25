class_name Hud
extends CanvasLayer
## The night's clock and room mood (top right), and the end-of-night banner.

const MOOD_NAMES := ["Calme", "Tendu", "Chaud", "Émeute"]
const MOOD_COLORS := [Color(0.5, 1.0, 0.5), Color(1.0, 0.9, 0.3), Color(1.0, 0.55, 0.2), Color(1.0, 0.25, 0.2)]
const MOOD_CELLS := 12

@export var night: Night

var _status: Label
var _banner: Label


func _ready() -> void:
    _status = _label(24)
    _status.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE, 16)
    _status.grow_horizontal = Control.GROW_DIRECTION_BEGIN
    _status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    _banner = _label(44)
    _banner.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
    _banner.grow_horizontal = Control.GROW_DIRECTION_BOTH
    _banner.grow_vertical = Control.GROW_DIRECTION_BOTH
    _banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


func _process(_delta: float) -> void:
    var sim := night.simulation
    if not sim:
        return
    var level := sim.crowd.level()
    var filled := clampi(roundi(float(sim.crowd.mood) / sim.rules.riot * MOOD_CELLS), 0, MOOD_CELLS)
    _status.text = "%s\nAmbiance : %s\n%s" % [clock(sim.clock_minutes()), MOOD_NAMES[level],
            "■".repeat(filled) + "□".repeat(MOOD_CELLS - filled)]
    _status.modulate = MOOD_COLORS[level]
    _banner.visible = sim.outcome != &""
    if _banner.visible:
        var title := "Fermeture ! Vous avez tenu la nuit." if sim.outcome == &"won" \
                else "Émeute ! La nuit s'arrête à %s." % clock(sim.clock_minutes())
        var next := "Entrée : nouvelle nuit"
        if night.role == Night.Role.HOST:
            next = "Entrée : relancer la nuit"
        elif night.role == Night.Role.CLIENT:
            next = "En attente de l'hôte…"
        _banner.text = "%s\n%s" % [title, next]


## "HH:MM" for minutes since 18:00.
static func clock(minutes: int) -> String:
    return "%02d:%02d" % [(18 + minutes / 60) % 24, minutes % 60]


func _label(size: int) -> Label:
    var label := Label.new()
    label.add_theme_font_size_override("font_size", size)
    label.add_theme_constant_override("outline_size", 8)
    label.add_theme_color_override("font_outline_color", Color.BLACK)
    add_child(label)
    return label
