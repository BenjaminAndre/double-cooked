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
## A colour swatch in a menu, and how faded a greyed-out option is.
const SWATCH := 36
const DISABLED_ALPHA := 0.25

var _menu_row: GridContainer
var _hints: PanelContainer
var _hint_rows: VBoxContainer
var _options: Array = []
var _choice := -1
var _disabled: Array = []
var _rows: Array = []


func _init() -> void:
    alignment = ALIGNMENT_END
    add_theme_constant_override("separation", 6)
    _menu_row = GridContainer.new()
    _menu_row.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
    _menu_row.add_theme_constant_override("h_separation", 6)
    _menu_row.add_theme_constant_override("v_separation", 6)
    add_child(_menu_row)
    _hints = UiPanel.make(UiPanel.DARK, 6)
    _hint_rows = VBoxContainer.new()
    _hint_rows.add_theme_constant_override("separation", 4)
    _hints.add_child(_hint_rows)
    add_child(_hints)
    _menu_row.visible = false
    _hints.visible = false


## The options of an open menu, [] when none is open: words, or colours shown as swatches.
## columns: options per row (0 for a single row); disabled: indices greyed out.
func show_menu(options: Array, choice: int, columns := 0, disabled: Array = []) -> void:
    if options != _options or disabled != _disabled:
        _options = options.duplicate()
        _disabled = disabled.duplicate()
        _choice = -1
        for child in _menu_row.get_children():
            child.free()
        _menu_row.columns = columns if columns > 0 else maxi(options.size(), 1)
        for index in options.size():
            var option: Variant = options[index]
            var panel := UiPanel.make(UiPanel.DARK, 8)
            if option is Color:
                panel.custom_minimum_size = Vector2.ONE * SWATCH
            else:
                panel.add_child(UiPanel.label(option, OPTION_FONT))
            if index in disabled:
                panel.modulate.a = DISABLED_ALPHA
            _menu_row.add_child(panel)
        _menu_row.visible = not options.is_empty()
        reset_size()
    if choice != _choice:
        _choice = choice
        for index in _menu_row.get_child_count():
            _style_option(index, index == choice)
        reset_size()


## Words go black on bright yellow when selected; swatches keep their colour and get a
## thick white border.
func _style_option(index: int, selected: bool) -> void:
    var panel: PanelContainer = _menu_row.get_child(index)
    var option: Variant = _options[index]
    if option is Color:
        var style := StyleBoxFlat.new()
        style.bg_color = option
        style.set_corner_radius_all(4)
        style.set_border_width_all(4 if selected else 1)
        style.border_color = Color.WHITE if selected else Color(0, 0, 0, 0.6)
        panel.add_theme_stylebox_override("panel", style)
        return
    var label: Label = panel.get_child(0)
    UiPanel.set_color(panel, UiPanel.SELECTED if selected else UiPanel.DARK, 8)
    label.add_theme_color_override("font_color", Color.BLACK if selected else Color.WHITE)
    label.add_theme_font_size_override("font_size", SELECTED_FONT if selected else OPTION_FONT)


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
        # No key cap for a hint that only explains, like why a door stays shut.
        if row[0] != "":
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
