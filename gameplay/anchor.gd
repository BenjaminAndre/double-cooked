@tool
class_name Anchor
extends Node3D

@export var up : Anchor
@export var down: Anchor
@export var left : Anchor
@export var right : Anchor
@export var interactible : Interactible


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
    pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
    _draw_debug_helpers()
    

func _draw_debug_helpers() -> void:
    DebugDraw3D.draw_sphere(global_transform.origin, 0.1, Color.RED)
    if up:
        _draw_directional_debug_arrow(up, Color.RED)
    if down:
        _draw_directional_debug_arrow(down, Color.BLUE)
    if left:
        _draw_directional_debug_arrow(left, Color.YELLOW)
    if right:
        _draw_directional_debug_arrow(right, Color.GREEN)
    if interactible:
        _draw_directional_debug_arrow(interactible, Color.PINK)


func _draw_directional_debug_arrow(target: Node3D, color: Color) -> void:
    var direction = (target.global_transform.origin - global_transform.origin).normalized()
    DebugDraw3D.draw_arrow(global_transform.origin, global_transform.origin + direction * 0.5, color, 0.05)
