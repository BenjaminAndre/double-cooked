class_name CustomersView
extends Node3D
## Shows the line of customers in front of the counter. This node's position is the front of
## the line; the rest queue up along line_step. The first SimRules.visible_orders customers
## show a ticket with their order and patience (GDD §6.2).

const MODEL := preload("res://assets/kenney_prototype-kit/Models/GLB format/figurine-cube.glb")
## How fast customers walk to their place in line, as a fraction of the distance per second.
const SHUFFLE_SPEED := 8.0
## Where customers come from and go to, relative to the front of the line.
const ENTRANCE := Vector3(-6, 0, 0)
const EXIT := Vector3(2.5, 0, -1)
## The camera is close to the line, so customers are drawn smaller than the players.
const FIGURE_SCALE := 0.6
## Tickets are drawn on screen under their customer (clear of the counter), and pushed apart so
## they never overlap.
const TICKET_GAP_BELOW := 6.0
const TICKET_GAP := 8.0
const FRONT_FONT_SIZE := 24
const BACK_FONT_SIZE := 18

@export var night: Night
@export var line_step := Vector3(-0.45, 0, 0)

## Customer id -> its figure.
var _figures := {}
var _leaving: Array[Node3D] = []
var _tickets: Array[PanelContainer] = []
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
            _figures[customer.id] = _new_figure()
        var figure: Node3D = _figures[customer.id]
        figure.position = figure.position.lerp(line_step * index, minf(1.0, SHUFFLE_SPEED * delta))
    for id in _figures.keys():
        if not present.has(id):
            _leaving.append(_figures[id])
            _figures.erase(id)
    for figure in _leaving.duplicate():
        figure.position = figure.position.move_toward(EXIT, 3.0 * delta)
        if figure.position.is_equal_approx(EXIT):
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
## is pushed along the line, so the order of the tickets always matches the line.
func _show_tickets(crowd: SimCrowd) -> void:
    var camera := get_viewport().get_camera_3d()
    var shown := mini(crowd.line.size(), crowd.rules.visible_orders)
    while _tickets.size() < shown:
        _tickets.append(_new_ticket())
    var previous_right := -INF
    for index in _tickets.size():
        var ticket := _tickets[index]
        ticket.visible = index < shown and camera != null
        if not ticket.visible:
            continue
        var customer := crowd.line[index]
        var figure: Node3D = _figures[customer.id]
        var label: Label = ticket.get_child(0).get_child(0)
        var bar: DrainingBar = ticket.get_child(0).get_child(1)
        var patience := float(customer.patience) / crowd.rules.patience
        label.text = _order_text(customer.order)
        label.add_theme_font_size_override("font_size", FRONT_FONT_SIZE if index == 0 else BACK_FONT_SIZE)
        bar.show_fraction(patience)
        ticket.reset_size()
        var anchor := camera.unproject_position(figure.global_position)
        var left := maxf(anchor.x - ticket.size.x / 2, previous_right + TICKET_GAP)
        ticket.position = Vector2(left, anchor.y + TICKET_GAP_BELOW)
        previous_right = left + ticket.size.x


## "frites mayo ×2", one line per dish.
func _order_text(order: Array[StringName]) -> String:
    var counts := {}
    for dish in order:
        counts[dish] = counts.get(dish, 0) + 1
    var lines := []
    for dish in counts:
        lines.append("%s ×%d" % [ItemNames.dish(dish), counts[dish]] if counts[dish] > 1 \
                else ItemNames.dish(dish))
    return "\n".join(lines)



func _new_ticket() -> PanelContainer:
    var ticket := PanelContainer.new()
    var style := StyleBoxFlat.new()
    style.bg_color = Color(0, 0, 0, 0.7)
    style.set_content_margin_all(6)
    style.set_corner_radius_all(4)
    ticket.add_theme_stylebox_override("panel", style)
    var column := VBoxContainer.new()
    ticket.add_child(column)
    var label := Label.new()
    label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    column.add_child(label)
    column.add_child(DrainingBar.new(0, 8))
    _layer.add_child(ticket)
    return ticket


func _new_figure() -> Node3D:
    var figure: Node3D = MODEL.instantiate()
    figure.position = ENTRANCE
    # Customers face the counter.
    figure.rotation.y = PI
    figure.scale = Vector3.ONE * FIGURE_SCALE
    add_child(figure)
    return figure
