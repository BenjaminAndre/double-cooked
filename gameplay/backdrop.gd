class_name Backdrop
extends Node
## Draws the room itself (floor and walls) behind everything, whatever the depth: the tilted
## paper figures would otherwise sink into walls and floor (docs/ART_PLAN.md).
##
## The room's meshes go on LAYER, which the game's cameras don't see. A second camera, kept on
## the current one, renders that layer alone into a picture on a canvas layer below the 3D
## scene, which shows it as its background (Environment BG_CANVAS).
##
## The walls on the camera's side of the room must still hide what stands behind them (the
## customers in line, a player's legs): a copy of the room is also drawn in the 3D scene, with
## depth, keeping only those walls (front_walls.gdshader). Seen from the same camera, it covers
## the backdrop exactly.

## The render layer (1-based, as in the editor) for the backdrop.
const LAYER := 20
## The canvas layer the picture sits on; the environment shows layers up to this one.
const CANVAS_LAYER := -1
const FRONT_WALLS := preload("res://gameplay/front_walls.gdshader")

## The room drawn as the backdrop.
@export var room: Node3D
## The sky behind the room.
@export var background := Color("DCF6FF")

var _viewport: SubViewport
var _camera: Camera3D
## Texture -> the front walls' material drawing it.
var _front_materials := {}
var _looked_at := Vector3.INF


func _ready() -> void:
    for mesh: VisualInstance3D in room.find_children("*", "VisualInstance3D", true, false):
        mesh.layers = 1 << (LAYER - 1)
        if mesh is MeshInstance3D:
            _add_front_walls(mesh)
    _viewport = SubViewport.new()
    _viewport.world_3d = get_viewport().world_3d
    _viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
    add_child(_viewport)
    _camera = Camera3D.new()
    _camera.cull_mask = 1 << (LAYER - 1)
    var sky := Environment.new()
    sky.background_mode = Environment.BG_COLOR
    sky.background_color = background
    _camera.environment = sky
    _viewport.add_child(_camera)
    var layer := CanvasLayer.new()
    layer.layer = CANVAS_LAYER
    add_child(layer)
    var picture := TextureRect.new()
    picture.texture = _viewport.get_texture()
    picture.set_anchors_preset(Control.PRESET_FULL_RECT)
    picture.stretch_mode = TextureRect.STRETCH_SCALE
    picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
    layer.add_child(picture)


## Late in the frame, once the game has moved its camera.
func _process(_delta: float) -> void:
    var viewport := get_viewport()
    var main := viewport.get_camera_3d()
    if _viewport.size != Vector2i(viewport.get_visible_rect().size):
        _viewport.size = Vector2i(viewport.get_visible_rect().size)
    if not main:
        return
    main.cull_mask &= ~(1 << (LAYER - 1))
    _camera.global_transform = main.global_transform
    _camera.fov = main.fov
    _camera.near = main.near
    _camera.far = main.far
    # The front walls are those between the camera and where it looks at on the floor.
    var forward := -main.global_basis.z
    if forward.y < -0.01:
        var looked_at := main.global_position + forward * (-main.global_position.y / forward.y)
        if not looked_at.is_equal_approx(_looked_at):
            _looked_at = looked_at
            var toward := Vector2(forward.x, forward.z).normalized()
            for material: ShaderMaterial in _front_materials.values():
                material.set_shader_parameter(&"looked_at", Vector2(looked_at.x, looked_at.z))
                material.set_shader_parameter(&"forward", toward)


## The same mesh drawn in the 3D scene, keeping only the walls on the camera's side.
func _add_front_walls(mesh: MeshInstance3D) -> void:
    if not mesh.mesh:
        return
    var front := MeshInstance3D.new()
    front.name = "%sFrontWalls" % mesh.name
    front.mesh = mesh.mesh
    front.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    for surface in mesh.mesh.get_surface_count():
        var material := mesh.get_active_material(surface) as BaseMaterial3D
        var texture := material.albedo_texture if material else null
        if not _front_materials.has(texture):
            var walls := ShaderMaterial.new()
            walls.shader = FRONT_WALLS
            walls.set_shader_parameter(&"picture", texture)
            _front_materials[texture] = walls
        front.set_surface_override_material(surface, _front_materials[texture])
    mesh.add_child(front)
