class_name CustomersView
extends Node3D
## Shows the line of customers in front of the counter. This node's position is the front of
## the line; the rest queue up along line_step. Only the front customer shows a ticket (GDD §6.2).

const MODEL := preload("res://assets/kenney_prototype-kit/Models/GLB format/figurine-cube.glb")
const PATIENCE_CELLS := 8
## How fast customers walk to their place in line, as a fraction of the distance per second.
const SHUFFLE_SPEED := 8.0
## Where customers come from and go to, relative to the front of the line.
const ENTRANCE := Vector3(-6, 0, 0)
const EXIT := Vector3(2.5, 0, -1)
## The camera is close to the line, so customers are drawn smaller than the players.
const FIGURE_SCALE := 0.6

@export var night: Night
@export var line_step := Vector3(-0.45, 0, 0)

## Customer id -> its node.
var _figures := {}
var _leaving: Array[Node3D] = []
var _ticket: Label3D


func _ready() -> void:
    _ticket = Label3D.new()
    _ticket.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    _ticket.font_size = 30
    _ticket.outline_size = 10
    # On top of the CAISSE, where the players look when serving.
    _ticket.position = Vector3(0, 1.0, 0.4)
    add_child(_ticket)
    night.began.connect(clear)


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
    _show_ticket(crowd)


## Forgets every figure, e.g. when a new night starts.
func clear() -> void:
    for figure in _figures.values() + _leaving:
        figure.queue_free()
    _figures.clear()
    _leaving.clear()


func _show_ticket(crowd: SimCrowd) -> void:
    var front := crowd.front()
    _ticket.visible = front != null
    if not front:
        return
    var counts := {}
    for dish in front.order:
        counts[dish] = counts.get(dish, 0) + 1
    var lines := []
    for dish in counts:
        lines.append("%s ×%d" % [ItemNames.dish(dish), counts[dish]] if counts[dish] > 1 \
                else ItemNames.dish(dish))
    var patience := float(front.patience) / crowd.rules.patience
    var filled := clampi(ceili(patience * PATIENCE_CELLS), 0, PATIENCE_CELLS)
    lines.append("■".repeat(filled) + "□".repeat(PATIENCE_CELLS - filled))
    _ticket.text = "\n".join(lines)
    _ticket.modulate = Color(1, 1, 1) if patience > 0.5 else Color(1, 0.8, 0.2) if patience > 0.25 \
            else Color(1, 0.3, 0.2)


func _new_figure() -> Node3D:
    var figure: Node3D = MODEL.instantiate()
    figure.position = ENTRANCE
    # Customers face the counter.
    figure.rotation.y = PI
    figure.scale = Vector3.ONE * FIGURE_SCALE
    add_child(figure)
    return figure
