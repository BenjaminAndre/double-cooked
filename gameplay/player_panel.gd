class_name PlayerPanel
extends VBoxContainer
## Menu options and key hints in the artist's style (docs/ART_PLAN.md): each option in a cream
## frame, the selected one in the yellow selection frame; each hint a key cap and its verb.
## Over a local player's head it shows their hints; in a MenuBubble, a station's menu.

const OPTION_FONT := 22
const HINT_FONT := 20
const KEY_FONT := 18
## Kept this far from the screen edges.
const MARGIN := 8.0
## A colour swatch in a menu, and how faded a greyed-out option is.
const SWATCH := 36
## A picture option, e.g. a character's face or a sauce.
const PICTURE := 56
const DISABLED_ALPHA := 0.3

## Inside a MenuBubble: the hints need no frame of their own.
var art_style := false

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
    _menu_row.add_theme_constant_override("h_separation", 4)
    _menu_row.add_theme_constant_override("v_separation", 4)
    add_child(_menu_row)
    _hints = PanelContainer.new()
    _hint_rows = VBoxContainer.new()
    _hint_rows.add_theme_constant_override("separation", 4)
    _hints.add_child(_hint_rows)
    _hints.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
    add_child(_hints)
    _menu_row.visible = false
    _hints.visible = false


func _ready() -> void:
    _hints.add_theme_stylebox_override("panel", StyleBoxEmpty.new() if art_style else ArtUi.option())


## The options of an open menu, [] when none is open: words, pictures, [picture, caption] pairs
## or colours shown as swatches. Each option sits at its Menu.CELLS cell, around the first one;
## disabled: indices greyed out.
func show_menu(options: Array, choice: int, disabled: Array = []) -> void:
    if options != _options or disabled != _disabled:
        _options = options.duplicate()
        _disabled = disabled.duplicate()
        _choice = -1
        for child in _menu_row.get_children():
            child.free()
        _option_panels.clear()
        for index in options.size():
            var panel := _option(options[index])
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
            _option_panels[index].add_theme_stylebox_override("panel",
                    ArtUi.selected_option() if index == choice else ArtUi.option())
        reset_size()


func _option(option: Variant) -> PanelContainer:
    var panel := PanelContainer.new()
    if option is Color:
        var swatch := ColorRect.new()
        swatch.color = option
        swatch.custom_minimum_size = Vector2.ONE * SWATCH
        panel.add_child(swatch)
    elif option is Texture2D:
        panel.add_child(ArtUi.picture(option, PICTURE))
    elif option is Array:
        # A picture with a caption under it, e.g. how many beers are left.
        var column := VBoxContainer.new()
        column.add_theme_constant_override("separation", 0)
        column.add_child(ArtUi.picture(option[0], PICTURE))
        column.add_child(_label(option[1], KEY_FONT))
        panel.add_child(column)
    else:
        panel.add_child(_label(option, OPTION_FONT))
    return panel


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
            var key := ArtUi.panel(ArtUi.key_cap())
            key.add_child(_label(row[0], KEY_FONT))
            line.add_child(key)
        var verb := _label(row[1], HINT_FONT)
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


func _label(text: String, font_size: int) -> Label:
    var label := Label.new()
    label.text = text
    label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    label.add_theme_font_size_override("font_size", font_size)
    label.add_theme_color_override("font_color", ArtUi.INK)
    label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    return label
