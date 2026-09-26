class_name GridView
extends Node3D
## A pale tile on the floor under every node players can walk to, so the kitchen reads as
## the square grid it is (GDD §5.2), even in builds without the debug arrows.

const TILE := 0.9
const COLOR := Color(1, 1, 1, 0.18)

@export var night: Night


func _ready() -> void:
    night.began.connect(_build)
    _build()


func _build() -> void:
    for child in get_children():
        child.queue_free()
    if not night.simulation:
        return
    var mesh := PlaneMesh.new()
    mesh.size = Vector2(TILE, TILE)
    var material := StandardMaterial3D.new()
    material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    material.albedo_color = COLOR
    mesh.material = material
    for point in night.simulation.level.positions:
        var tile := MeshInstance3D.new()
        tile.mesh = mesh
        tile.position = point + Vector3.UP * 0.01
        add_child(tile)
