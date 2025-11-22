class_name Player
extends Node3D


# Privates
var _max_health : int = 3

# Identification (may be outside of player scope later)
var health : int = 3
var pseudo : String = "Player"
var is_local_player : bool = true


@export var speed : float = 10.0
@export var spawn : Anchor

var current_anchor : Anchor
var future_path : Array[Anchor] = []
var last_input_direction : Vector2 = Vector2.ZERO

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
    future_path = [spawn]
    global_position = future_path[0].global_transform.origin
    health = _max_health


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
    _process_movement(delta)
    _debug_draw_path()
    if Input.is_action_just_pressed("ui_debug_damage"):
        health -= 1
        health = max(health, 0)
    if Input.is_action_just_pressed("ui_interact") and current_anchor.interactible:
        current_anchor.interactible.interact(self)

func _process_movement(delta: float) -> void:
    # Move and avoid null refs
    if future_path.size() > 0:
        global_position = global_position.move_toward(future_path[0].global_transform.origin, speed * delta)
        if global_position.distance_to(future_path[0].global_transform.origin) < 0.1:
            current_anchor = future_path[0]
            future_path.remove_at(0)

    var last_anchor = current_anchor
    if future_path.size() > 0:
        last_anchor = future_path[future_path.size() - 1]
        
    var anchor_to_add : Anchor = null
    
    # Only allow changing direction if not already moving in that direction
    if Input.is_action_just_pressed("ui_up") and last_anchor.up and last_input_direction != Vector2(0, 1):
        last_input_direction = Vector2(0, 1)
        anchor_to_add = last_anchor.up
    if Input.is_action_just_pressed("ui_down") and last_anchor.down and last_input_direction != Vector2(0, -1):
        last_input_direction = Vector2(0, -1)
        anchor_to_add = last_anchor.down
    if Input.is_action_just_pressed("ui_left") and last_anchor.left and last_input_direction != Vector2(-1, 0):
        last_input_direction = Vector2(-1, 0)
        anchor_to_add = last_anchor.left
    if Input.is_action_just_pressed("ui_right") and last_anchor.right and last_input_direction != Vector2(1, 0):
        last_input_direction = Vector2(1, 0)
        anchor_to_add = last_anchor.right
    if not Input.is_anything_pressed():
        last_input_direction = Vector2.ZERO
        
    # Remove loops from future path
    if anchor_to_add and anchor_to_add in future_path:
        var index = future_path.find(anchor_to_add)
        future_path = future_path.slice(0, index + 1)
    elif anchor_to_add:
        future_path.append(anchor_to_add)


func _debug_draw_path() -> void:
    for anchor in future_path:
        DebugDraw3D.draw_sphere(anchor.global_transform.origin, 0.12, Color.GREEN)
