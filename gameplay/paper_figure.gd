class_name PaperFigure
extends Node3D
## A character drawn as a paper cut-out (docs/ART_PLAN.md): the artist's drawing, facing the
## camera square on as on the concept, standing on its feet at this node's origin. Its depth is
## that of a card standing upright there (paper_figure.gdshader), so it never sinks into what
## is behind it. It can widen (fat) and lie flat on the floor (knocked out).

## Height of a standing figure, in metres: the artist's 1024-pixel drawings at 750 pixels a
## metre, as in their scenes (Readme_SettingsV3). Everyone is the same size.
const HEIGHT := 1.37
## A portrait is this tall for its width (the head and cap).
const PORTRAIT_RATIO := 1.1
const SHADER := preload("res://gameplay/paper_figure.gdshader")
## The shader moves the quad: a box it always fits in, so it isn't culled too early.
const BOUNDS := AABB(Vector3(-1.5, -0.5, -1.5), Vector3(3, 4.5, 3))

## Picture -> its portrait, so a menu keeps showing the same texture.
static var _portraits := {}

var _mesh: MeshInstance3D
var _material: ShaderMaterial
var _lying := false
var _mirrored := false


func _init(texture: Texture2D = null, height := HEIGHT) -> void:
    _mesh = MeshInstance3D.new()
    var quad := QuadMesh.new()
    quad.size = Vector2.ONE
    _mesh.mesh = quad
    _mesh.custom_aabb = BOUNDS
    _material = ShaderMaterial.new()
    _material.shader = SHADER
    _mesh.material_override = _material
    add_child(_mesh)
    set_picture(texture, height)


## Shows this picture, scaled so it stands height metres tall.
func set_picture(texture: Texture2D, height := HEIGHT) -> void:
    _material.set_shader_parameter(&"picture", texture)
    if texture:
        _material.set_shader_parameter(&"size",
                Vector2(height * texture.get_width() / texture.get_height(), height))


## Walking to the left of the screen: the drawing flips; to the right, it faces as drawn.
func set_mirrored(mirrored: bool) -> void:
    if mirrored != _mirrored:
        _mirrored = mirrored
        _material.set_shader_parameter(&"mirrored", mirrored)


## Turns the figure to face where it walks along this direction in the world, seen from this
## camera; standing still keeps it as it was.
func face(direction: Vector3, camera: Camera3D) -> void:
    if not camera:
        return
    var sideways := direction.dot(camera.global_basis.x)
    if absf(sideways) > 0.001:
        set_mirrored(sideways < 0.0)


## 1 is the drawing as is; more is wider.
func set_girth(girth: float) -> void:
    _material.set_shader_parameter(&"girth", girth)


## Knocked out: flat on the floor on its side, head to the left of the screen, facing up (lying
## head away from the camera would only look like a shorter standing figure).
func set_lying(lying: bool) -> void:
    if lying == _lying:
        return
    var camera := get_viewport().get_camera_3d() if is_inside_tree() else null
    if not lying:
        _lying = false
        _material.set_shader_parameter(&"standing", true)
        _mesh.basis = Basis.IDENTITY
        return
    if not camera:
        # Tried again next frame, once there is a camera to lie facing.
        return
    _lying = true
    _material.set_shader_parameter(&"standing", false)
    var forward := -camera.global_basis.z
    forward.y = 0
    forward = forward.normalized()
    var right := forward.cross(Vector3.UP).normalized()
    _mesh.global_basis = Basis(forward, -right, Vector3.UP)


## The head and shoulders of a character picture, e.g. for a menu.
static func portrait(texture: Texture2D) -> Texture2D:
    if not _portraits.has(texture):
        var head := AtlasTexture.new()
        head.atlas = texture
        head.region = Rect2(0, 0, texture.get_width(), texture.get_width() * PORTRAIT_RATIO)
        _portraits[texture] = head
    return _portraits[texture]
