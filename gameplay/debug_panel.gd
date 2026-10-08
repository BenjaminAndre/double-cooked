class_name DebugPanel
extends PanelContainer
## The host's test tools (F4, GDD §9.3), in a cream note on the left: one row per tool, the
## selected option framed like a menu's. Up and down pick a row, left and right an option, Space
## or Enter uses it, F4 or Escape closes. The host's or offline only, in the web build too; the
## night goes on meanwhile, and the keys go to the panel.

const KEY := KEY_F4
## The last campaign night offered.
const LAST_NIGHT := 20
const SPEEDS := [1, 2, 4]
## An option that is on, e.g. the current speed.
const ACTIVE := Color(0.1, 0.45, 0.15)
## Text sizes: the title, the rows' names, the options and the keys at the bottom.
const TITLE_SIZE := 24
const ROW_SIZE := 19
const OPTION_SIZE := 17

var night: Night
var _rows: VBoxContainer
## The selected row, and the option picked in each row (by id).
var _row := 0
var _choice := {}
## Who the crew tools aim at (a slot), and the campaign night to go to.
var _target := 0
var _night_number := 1
## An option, and the selected one: the key cap, yellow like the hints'.
var _option_style: StyleBox
var _selected_style: StyleBox


func _init(p_night: Night) -> void:
    night = p_night
    _option_style = _chip(ArtUi.option())
    _selected_style = _chip(ArtUi.key_cap())
    add_theme_stylebox_override("panel", ArtUi.notebook())
    var column := VBoxContainer.new()
    column.add_theme_constant_override("separation", 6)
    add_child(column)
    _ink(column, "Outils de test", TITLE_SIZE)
    _rows = VBoxContainer.new()
    _rows.add_theme_constant_override("separation", 3)
    column.add_child(_rows)
    _ink(column, "Flèches : choisir · Espace : appliquer · F4 : fermer", OPTION_SIZE)
    visible = false


func _input(event: InputEvent) -> void:
    var key := event as InputEventKey
    if not key or not key.pressed or key.echo:
        return
    if key.physical_keycode == KEY:
        toggle()
        get_viewport().set_input_as_handled()
    elif visible:
        press(key.physical_keycode)
        get_viewport().set_input_as_handled()


## Opens or closes the panel; a guest only gets told the tools are the host's.
func toggle() -> void:
    if not night.can_use_tools():
        night.notice.emit("Outils de test : réservés à l'hôte")
        return
    visible = not visible
    if visible:
        _show()


## A key while the panel is open (a physical keycode).
func press(keycode: Key) -> void:
    var rows := rows()
    _row = clampi(_row, 0, rows.size() - 1)
    var row: Dictionary = rows[_row]
    match keycode:
        KEY_UP, KEY_DOWN:
            _row = posmod(_row + (1 if keycode == KEY_DOWN else -1), rows.size())
        KEY_LEFT, KEY_RIGHT:
            var step := 1 if keycode == KEY_RIGHT else -1
            match row.id:
                &"target":
                    _target = posmod(_target + step, night.simulation.players.size())
                &"campaign":
                    _night_number = posmod(_night_number - 1 + step, LAST_NIGHT) + 1
                _:
                    _choice[row.id] = clampi(_choice.get(row.id, 0) + step, 0, row.options.size() - 1)
        KEY_SPACE, KEY_ENTER, KEY_KP_ENTER:
            _use(row.id, _choice.get(row.id, 0), row.options[_choice.get(row.id, 0)])
        KEY_ESCAPE:
            visible = false
    if visible:
        _show()


## The rows for where the crew is: {"id", "label", "options": texts, "active": index on or -1}.
## In the lobby only what takes the crew somewhere; the night's tools in the kitchen.
func rows() -> Array[Dictionary]:
    var result: Array[Dictionary] = []
    if not night.in_lobby:
        var target := night.simulation.players[mini(_target, night.simulation.players.size() - 1)]
        var who := Looks.player_name(target.color)
        result.append_array([
            {"id": &"mood", "label": "Humeur", "options": ["calme", "tendu", "chaud", "avant l'émeute"]},
            {"id": &"clock", "label": "Horloge", "options": ["+30 min", "02:00, le boss", "fermeture"]},
            {"id": &"customers", "label": "Clients", "options": ["boss maintenant", "file pleine"]},
            {"id": &"kitchen", "label": "Cuisine", "options": ["frigo plein", "éteindre les feux", "allumer un feu"]},
            {"id": &"target", "label": "Joueur", "options": ["< %s >" % who]},
            {"id": &"crew", "label": "Équipe", "options": ["tout soigner", "K.O. : " + who, "affamé : " + who,
                    "gros : " + who]},
        ])
    result.append({"id": &"campaign", "label": "Campagne",
            "options": ["< %s (nuit %d) >" % [Campaign.day_label(_night_number), _night_number]]})
    var speeds := []
    for times: int in SPEEDS:
        speeds.append("×%d" % times)
    result.append({"id": &"speed", "label": "Vitesse", "options": speeds, "active": SPEEDS.find(night.speed)})
    return result


func _use(id: StringName, index: int, text: String) -> void:
    const Tool := Simulation.DebugTool
    match id:
        &"mood":
            night.use_tool(Tool.MOOD, index)
        &"clock":
            night.use_tool(Tool.CLOCK, index)
        &"customers":
            night.use_tool([Tool.BOSS, Tool.FILL_LINE][index])
        &"kitchen":
            night.use_tool([Tool.FRIDGE, Tool.FIRES_OUT, Tool.FIRE][index])
        &"crew":
            night.use_tool([Tool.HEAL, Tool.KNOCK_OUT, Tool.HUNGRY, Tool.FAT][index], _target)
        &"campaign":
            # Another night begins: the panel closes on it.
            visible = false
            night.jump_to_night(_night_number)
            return
        &"speed":
            night.speed = SPEEDS[index]
        _:
            return
    night.notice.emit("Test : %s" % text)


## Rebuilds the rows, the selected option framed.
func _show() -> void:
    var rows := rows()
    _row = clampi(_row, 0, rows.size() - 1)
    for child in _rows.get_children():
        # Out at once, or the old rows still count in the size below.
        _rows.remove_child(child)
        child.queue_free()
    for index in rows.size():
        var row: Dictionary = rows[index]
        var line := HBoxContainer.new()
        line.add_theme_constant_override("separation", 6)
        _rows.add_child(line)
        _ink(line, row.label, ROW_SIZE).custom_minimum_size.x = 110
        var picked: int = _choice.get(row.id, 0)
        for option in row.options.size():
            var selected: bool = index == _row and option == picked
            var box := ArtUi.panel(_selected_style if selected else _option_style)
            line.add_child(box)
            var label := _ink(box, row.options[option], OPTION_SIZE)
            if option == row.get("active", -1):
                label.add_theme_color_override("font_color", ACTIVE)
    reset_size()
    # Centred on the left: the size only settles once the rows are in.
    position = Vector2(16, (get_viewport_rect().size.y - size.y) / 2)


## A frame for a line of text: the artist's, with room on the sides.
static func _chip(frame: StyleBox) -> StyleBox:
    var style := frame.duplicate() as StyleBox
    style.content_margin_left = 12
    style.content_margin_right = 12
    style.content_margin_top = 3
    style.content_margin_bottom = 3
    return style


func _ink(parent: Node, text: String, size: int) -> Label:
    var label := Label.new()
    label.text = text
    label.add_theme_font_size_override("font_size", size)
    label.add_theme_color_override("font_color", ArtUi.INK)
    label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    parent.add_child(label)
    return label
