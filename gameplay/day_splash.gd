class_name DaySplash
extends PanelContainer
## At the start of a campaign night (GDD §4.2), in the middle of the screen: the artist's agenda,
## the day, and what is new on the menu tonight (the whole menu on the first night), each as its
## picture and name. It leaves after TIME seconds, or as soon as a player at this keyboard moves:
## the night is already running.

const TIME := 4.0
const FADE := 0.4
const AGENDA_SIZE := 120
const ITEM_SIZE := 64

var _day: Label
var _new: Label
var _items: HBoxContainer
var _left := 0.0


func _init() -> void:
    add_theme_stylebox_override("panel", ArtUi.frame("FrameEventInfo", Vector4(24, 24, 24, 24), 28))
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    visible = false
    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation", 24)
    add_child(row)
    row.add_child(ArtUi.picture(load("res://art/textures/Agenda.png"), AGENDA_SIZE))
    var column := VBoxContainer.new()
    column.alignment = BoxContainer.ALIGNMENT_CENTER
    column.add_theme_constant_override("separation", 6)
    row.add_child(column)
    _day = _label(52, column)
    _new = _label(24, column)
    _items = HBoxContainer.new()
    _items.add_theme_constant_override("separation", 18)
    column.add_child(_items)


## Shows the start of this night of a campaign.
func show_night(night: int) -> void:
    _day.text = Hud.capitalized(Campaign.day_label(night))
    for child in _items.get_children():
        child.free()
    # The first night shows its whole menu, the next ones what they add to it.
    var added: Array = Campaign.new_on(night) if night > 1 else Campaign.menu_for(night)
    added = added.filter(func(entry: StringName) -> bool: return entry != Menu.NATURE)
    _new.text = "Nouveau ce soir" if night > 1 else "Au menu ce soir"
    for entry in added:
        var item := VBoxContainer.new()
        item.add_theme_constant_override("separation", 0)
        var kind: StringName = ItemIcons.DISHES.get(entry, entry)
        if ItemIcons.picture(kind):
            item.add_child(ArtUi.picture(ItemIcons.picture(kind), ITEM_SIZE))
        var name_label := _label(22, item)
        name_label.text = ItemNames.DISHES.get(entry, ItemNames.word(entry))
        _items.add_child(item)
    _new.visible = not added.is_empty()
    _items.visible = not added.is_empty()
    _left = TIME
    modulate.a = 1.0
    visible = true
    reset_size()


## Leaves at once, e.g. when a player starts moving.
func dismiss() -> void:
    _left = minf(_left, FADE)


func _process(delta: float) -> void:
    if not visible:
        return
    _left -= delta
    modulate.a = clampf(_left / FADE, 0.0, 1.0)
    visible = _left > 0.0
    position = (get_viewport_rect().size - size) / 2


func _label(size: int, parent: Node) -> Label:
    var label := Label.new()
    label.add_theme_font_size_override("font_size", size)
    label.add_theme_color_override("font_color", ArtUi.INK)
    label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    parent.add_child(label)
    return label
