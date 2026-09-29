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
## A picture option, e.g. a character's face.
const PICTURE := 64
const DISABLED_ALPHA := 0.25

var _menu_row: GridContainer
var _hints: PanelContainer
var _hint_rows: VBoxContainer
var _options: Array = []
var _choice := -1
var _disabled: Array = []
## One per option, in option order (the grid holds them by cell).
var _option_panels: Array[PanelContainer] = []
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
## Each option sits at its Menu.CELLS cell, around the first one; disabled: indices greyed out.
func show_menu(options: Array, choice: int, disabled: Array = []) -> void:
    if options != _options or disabled != _disabled:
        _options = options.duplicate()
        _disabled = disabled.duplicate()
        _choice = -1
        for child in _menu_row.get_children():
            child.free()
        _option_panels.clear()
        for index in options.size():
            var option: Variant = options[index]
            var panel := UiPanel.make(UiPanel.DARK, 8)
            if option is Color:
                panel.custom_minimum_size = Vector2.ONE * SWATCH
            elif option is Texture2D:
                var picture := TextureRect.new()
                picture.texture = option
                picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
                picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
                picture.custom_minimum_size = Vector2.ONE * PICTURE
                panel.add_child(picture)
            else:
                panel.add_child(UiPanel.label(option, OPTION_FONT))
            if index in disabled:
                panel.modulate.a = DISABLED_ALPHA
            _option_panels.append(panel)
        # Only the rows and columns in use; empty cells keep the others in place.
        var used := Menu.CELLS.slice(0, options.size())
        var low := Vector2i(3, 3)
        var high := Vector2i(-1, -1)
        for cell: Vector2i in used:
            low = low.min(cell)
            high = high.max(cell)
        _menu_row.columns = maxi(high.x - low.x + 1, 1)
        for row in range(low.y, high.y + 1):
            for column in range(low.x, high.x + 1):
                var index := Menu.option_at(Vector2i(column, row), options.size())
                _menu_row.add_child(_option_panels[index] if index >= 0 else Control.new())
        _menu_row.visible = not options.is_empty()
        reset_size()
    if choice != _choice:
        _choice = choice
        for index in _option_panels.size():
            _style_option(index, index == choice)
        reset_size()


## Words go black on bright yellow when selected; swatches keep their colour and pictures
## their own, and both get a thick white border.
func _style_option(index: int, selected: bool) -> void:
    var panel: PanelContainer = _option_panels[index]
    var option: Variant = _options[index]
    if option is Color or option is Texture2D:
        var style := StyleBoxFlat.new()
        style.bg_color = option if option is Color else (UiPanel.SELECTED if selected else UiPanel.DARK)
        style.set_content_margin_all(0 if option is Color else 4)
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
