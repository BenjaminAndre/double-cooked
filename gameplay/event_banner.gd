class_name EventBanner
extends PanelContainer
## A night's event as it starts (NightEvents, GDD §6.4): the artist's picture for it and what
## it means, at the top of the screen for a few seconds.

const TIME := 4.5
const PICTURE_SIZE := 110
## Event kind -> [picture, title, what it means].
const EVENTS := {
    NightEvents.PANNE_FRIGO: ["Event_PanneFrigo", "Panne de frigo !", "Plus de bière qui revient un moment"],
    NightEvents.DIABLES_ROUGES: ["Event_MiTempsDiablesRouges", "Mi-temps des Diables Rouges !",
            "Une foule pressée débarque"],
    NightEvents.AFSCA: ["Event_Afsca", "Contrôle AFSCA !", "Pas un feu pendant 20 s"],
    NightEvents.COLLEGUES: ["Event_GroupCollegues", "Les collègues arrivent !",
            "Une grosse commande, des bières surtout : remplis le frigo"],
}

var _picture: TextureRect
var _title: Label
var _text: Label
var _left := 0.0


func _init() -> void:
    add_theme_stylebox_override("panel", ArtUi.frame("FrameEventInfo", Vector4(24, 24, 24, 24), 18))
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    visible = false
    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation", 18)
    add_child(row)
    _picture = ArtUi.picture(null, PICTURE_SIZE)
    row.add_child(_picture)
    var column := VBoxContainer.new()
    column.alignment = BoxContainer.ALIGNMENT_CENTER
    row.add_child(column)
    _title = _label(36, column)
    _text = _label(22, column)


func show_event(kind: StringName) -> void:
    if not EVENTS.has(kind):
        return
    var shown: Array = EVENTS[kind]
    _picture.texture = load("res://art/textures/%s.png" % shown[0])
    _title.text = shown[1]
    _text.text = shown[2]
    _left = TIME
    visible = true
    reset_size()


func _process(delta: float) -> void:
    if not visible:
        return
    _left -= delta
    visible = _left > 0.0
    position = Vector2((get_viewport_rect().size.x - size.x) / 2, 24)


func _label(size: int, parent: Node) -> Label:
    var label := Label.new()
    label.add_theme_font_size_override("font_size", size)
    label.add_theme_color_override("font_color", ArtUi.INK)
    label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    parent.add_child(label)
    return label
