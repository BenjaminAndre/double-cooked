class_name PlayerPanel
extends VBoxContainer
## Over a local player's head, on screen: the open station menu, then what their keys would do.
## Each menu option sits in its own panel (an icon can replace its text later), the selected
## one in a bright colour; each hint is a key cap followed by its verb, on a dark panel.

const OPTION_FONT := 20
const SELECTED_FONT := 24
const HINT_FONT := 20
const KEY_FONT := 18
## Kept this far from the screen edges.
const MARGIN := 8.0

var _menu_row: HBoxContainer
var _hints: PanelContainer
var _hint_rows: VBoxContainer
var _options: Array = []
var _choice := -1
var _rows: Array = []


func _init() -> void:
    alignment = ALIGNMENT_END
    add_theme_constant_override("separation", 6)
    _menu_row = HBoxContainer.new()
    _menu_row.alignment = BoxContainer.ALIGNMENT_CENTER
    _menu_row.add_theme_constant_override("separation", 6)
    add_child(_menu_row)
    _hints = UiPanel.make(UiPanel.DARK, 6)
    _hint_rows = VBoxContainer.new()
    _hint_rows.add_theme_constant_override("separation", 4)
    _hints.add_child(_hint_rows)
    add_child(_hints)
    _menu_row.visible = false
    _hints.visible = false


## The options of an open menu, [] when none is open.
func show_menu(options: Array, choice: int) -> void:
    if options != _options:
        _options = options.duplicate()
        _choice = -1
        for child in _menu_row.get_children():
            child.free()
        for option: String in options:
            var panel := UiPanel.make(UiPanel.DARK, 8)
            panel.add_child(UiPanel.label(option, OPTION_FONT))
            _menu_row.add_child(panel)
        _menu_row.visible = not options.is_empty()
        reset_size()
    if choice != _choice:
        _choice = choice
        for index in _menu_row.get_child_count():
            var panel: PanelContainer = _menu_row.get_child(index)
            var label: Label = panel.get_child(0)
            var selected := index == choice
            UiPanel.set_color(panel, UiPanel.SELECTED if selected else UiPanel.DARK, 8)
            label.add_theme_color_override("font_color", Color.BLACK if selected else Color.WHITE)
            label.add_theme_font_size_override("font_size", SELECTED_FONT if selected else OPTION_FONT)
        reset_size()


## rows: [key name, verb] pairs, [] for none.
func show_hints(rows: Array) -> void:
    if rows == _rows:
        return
    _rows = rows.duplicate(true)
    for child in _hint_rows.get_children():
        child.free()
    for row: Array in rows:
        var line := HBoxContainer.new()
        line.add_theme_constant_override("separation", 8)
        var key := UiPanel.make(UiPanel.KEY, 3)
        key.add_child(UiPanel.label(row[0], KEY_FONT, Color.BLACK))
        line.add_child(key)
        var verb := UiPanel.label(row[1], HINT_FONT)
        verb.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
        line.add_child(verb)
        _hint_rows.add_child(line)
    _hints.visible = not rows.is_empty()
    reset_size()


func hint_rows() -> Array:
    return _rows


## Centres the panel's bottom on this screen point, inside the screen.
func place(bottom_centre: Vector2) -> void:
    var screen := get_viewport_rect().size
    var at := bottom_centre - Vector2(size.x / 2, size.y)
    position = at.clamp(Vector2.ONE * MARGIN, (screen - size - Vector2.ONE * MARGIN).max(Vector2.ZERO))
