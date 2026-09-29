class_name CustomersView
extends Node3D
## Shows the line of customers in front of the counter. This node's position is the front of
## the line; the rest queue up along line_step. The first SimRules.visible_orders customers
## show a ticket with their order and patience (GDD §6.2).

const MODEL := preload("res://assets/kenney_prototype-kit/Models/GLB format/figurine-cube.glb")
## How fast customers walk to their place in line, as a fraction of the distance per second.
const SHUFFLE_SPEED := 8.0
## The camera is close to the line, so customers are drawn smaller than the players.
const FIGURE_SCALE := 0.6
## Tickets are drawn on screen under their customer (clear of the counter), and pushed apart so
## they never overlap.
const TICKET_GAP_BELOW := 6.0
const TICKET_GAP := 8.0
const FRONT_FONT_SIZE := 20
const BACK_FONT_SIZE := 16
## The boss: bigger, red, on a red ticket with a dot per order (SimCrowd.Result: to come,
## served, missed).
const BOSS_SCALE := 1.6
const BOSS_COLOR := Color(0.85, 0.12, 0.1)
const BOSS_TICKET := Color(0.45, 0.02, 0.02, 0.85)
const DOT_SIZE := 14
const DOT_COLORS := [Color.BLACK, Color(0.3, 0.85, 0.35), Color(0.95, 0.2, 0.15)]

@export var night: Night
@export var line_step := Vector3(-0.45, 0, 0)
## Where customers come from and go to, relative to the front of the line.
@export var entrance := Vector3(-6, 0, 0)
@export var exit := Vector3(2.5, 0, -1)

## Customer id -> its figure.
var _figures := {}
var _leaving: Array[Node3D] = []
var _tickets: Array[PanelContainer] = []
## The boss's drink, on a ticket of its own.
var _drink_ticket: PanelContainer
var _layer: CanvasLayer


func _ready() -> void:
    night.began.connect(clear)
    _layer = CanvasLayer.new()
    add_child(_layer)


func _process(delta: float) -> void:
    if not night.simulation:
        return
    var crowd := night.simulation.crowd
    var present := {}
    for index in crowd.line.size():
        var customer := crowd.line[index]
        present[customer.id] = true
        if not _figures.has(customer.id):
            _figures[customer.id] = _new_figure(customer.boss)
        var figure: Node3D = _figures[customer.id]
        figure.position = figure.position.lerp(line_step * index, minf(1.0, SHUFFLE_SPEED * delta))
    for id in _figures.keys():
        if not present.has(id):
            _leaving.append(_figures[id])
            _figures.erase(id)
    for figure in _leaving.duplicate():
        figure.position = figure.position.move_toward(exit, 3.0 * delta)
        if figure.position.is_equal_approx(exit):
            _leaving.erase(figure)
            figure.queue_free()
    _show_tickets(crowd)


## Forgets every figure, e.g. when a new night starts.
func clear() -> void:
    for figure in _figures.values() + _leaving:
        figure.queue_free()
    _figures.clear()
    _leaving.clear()


## Each ticket sits under its customer on screen; a ticket that would overlap the previous one
## is pushed along the line, so the order of the tickets always matches the line. A ticket
## shows the order (dish, then sauce) and the customer's patience. The boss's ticket also shows
## his three orders as dots, and his drink comes on a ticket of its own right after it.
## Tickets never leave the screen: the row slides left or up by whatever overflows.
func _show_tickets(crowd: SimCrowd) -> void:
    var camera := get_viewport().get_camera_3d()
    var screen := get_viewport().get_visible_rect().size
    var shown := mini(crowd.line.size(), crowd.rules.visible_orders)
    while _tickets.size() < shown:
        _tickets.append(_new_ticket())
    if not _drink_ticket:
        _drink_ticket = _new_ticket()
    var previous_right := -INF
    var lowest := 0.0
    var placed: Array[PanelContainer] = []
    _drink_ticket.visible = false
    for index in _tickets.size():
        var ticket := _tickets[index]
        ticket.visible = index < shown and camera != null
        if not ticket.visible:
            continue
        var customer := crowd.line[index]
        var figure: Node3D = _figures[customer.id]
        var font_size := FRONT_FONT_SIZE if index == 0 else BACK_FONT_SIZE
        var full := crowd.boss_patience() if customer.boss else crowd.rules.patience
        _fill(ticket, "\n".join(ItemNames.order_line(customer.order)).strip_edges(), font_size,
                float(customer.patience) / full, customer.boss)
        _show_dots(ticket, customer)
        var anchor := camera.unproject_position(figure.global_position)
        var left := maxf(maxf(anchor.x - ticket.size.x / 2, previous_right + TICKET_GAP), TICKET_GAP)
        ticket.position = Vector2(left, anchor.y + TICKET_GAP_BELOW)
        previous_right = left + ticket.size.x
        lowest = maxf(lowest, ticket.position.y + ticket.size.y)
        placed.append(ticket)
        if customer.boss and customer.drink != &"":
            _drink_ticket.visible = true
            _fill(_drink_ticket, ItemNames.order_line(customer.drink)[0], font_size,
                    float(customer.drink_patience) / crowd.rules.boss_drink_patience, true)
            _drink_ticket.position = Vector2(previous_right + TICKET_GAP, ticket.position.y)
            previous_right += TICKET_GAP + _drink_ticket.size.x
            placed.append(_drink_ticket)
    var overflow := Vector2(maxf(previous_right + TICKET_GAP - screen.x, 0), maxf(lowest + TICKET_GAP - screen.y, 0))
    for ticket in placed:
        ticket.position -= overflow


## Text, size and colour only when they change: each change relayouts the ticket.
func _fill(ticket: PanelContainer, text: String, font_size: int, patience: float, boss: bool) -> void:
    var column := ticket.get_child(0)
    var label: Label = column.get_child(0)
    if label.text != text or label.get_theme_font_size("font_size") != font_size:
        label.text = text
        label.add_theme_font_size_override("font_size", font_size)
        ticket.reset_size()
    if ticket.get_meta(&"boss", false) != boss:
        ticket.set_meta(&"boss", boss)
        UiPanel.set_color(ticket, BOSS_TICKET if boss else UiPanel.DARK, 6)
    var bar: DrainingBar = column.get_child(2)
    bar.show_fraction(patience)


## The boss's orders as dots: black to come, ringed in white for the current one, green once
## served, red once missed.
func _show_dots(ticket: PanelContainer, customer: SimCrowd.Customer) -> void:
    var dots: HBoxContainer = ticket.get_child(0).get_child(1)
    var state := [Array(customer.results), customer.current()] if customer.boss else []
    if ticket.get_meta(&"dots", []) == state:
        return
    ticket.set_meta(&"dots", state)
    dots.visible = customer.boss
    for child in dots.get_children():
        child.free()
    if not customer.boss:
        ticket.reset_size()
        return
    for index in customer.results.size():
        var dot := Panel.new()
        dot.custom_minimum_size = Vector2.ONE * DOT_SIZE
        var style := StyleBoxFlat.new()
        style.set_corner_radius_all(DOT_SIZE / 2)
        style.bg_color = DOT_COLORS[customer.results[index]]
        if index == customer.current():
            style.set_border_width_all(2)
            style.border_color = Color.WHITE
        dot.add_theme_stylebox_override("panel", style)
        dots.add_child(dot)
    ticket.reset_size()


func _new_ticket() -> PanelContainer:
    var ticket := UiPanel.make(UiPanel.DARK, 6)
    var column := VBoxContainer.new()
    ticket.add_child(column)
    var label := Label.new()
    label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    column.add_child(label)
    var dots := HBoxContainer.new()
    dots.alignment = BoxContainer.ALIGNMENT_CENTER
    dots.visible = false
    column.add_child(dots)
    column.add_child(DrainingBar.new(0, 8))
    _layer.add_child(ticket)
    return ticket


func _new_figure(boss: bool) -> Node3D:
    var figure: Node3D = MODEL.instantiate()
    figure.position = entrance
    # Customers face the counter.
    figure.rotation.y = PI
    figure.scale = Vector3.ONE * FIGURE_SCALE * (BOSS_SCALE if boss else 1.0)
    if boss:
        var red := StandardMaterial3D.new()
        red.albedo_color = BOSS_COLOR
        for mesh in figure.find_children("*", "MeshInstance3D", true, false):
            (mesh as MeshInstance3D).material_override = red
    add_child(figure)
    return figure
