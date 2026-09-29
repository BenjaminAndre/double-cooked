class_name PaperFigure
extends Node3D
## A character drawn as a paper cut-out (docs/ART_PLAN.md): a picture that always faces the
## camera square on, as in the artist's concept, tilted back from its feet at this node's origin. It can widen (fat)
## and lie flat on the floor (knocked out).

## Height of a standing figure, in metres (a counter is about 0.95 m).
const HEIGHT := 1.55
## A portrait is this tall for its width (the head and cap).
const PORTRAIT_RATIO := 1.1

## Picture -> its portrait, so a menu keeps showing the same texture.
static var _portraits := {}

var _sprite: Sprite3D
var _lying := false


func _init(texture: Texture2D = null, height := HEIGHT) -> void:
    _sprite = Sprite3D.new()
    _sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    _sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_OPAQUE_PREPASS
    _sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
    add_child(_sprite)
    set_picture(texture, height)


## Shows this picture, scaled so it stands height metres tall.
func set_picture(texture: Texture2D, height := HEIGHT) -> void:
    _sprite.texture = texture
    if texture:
        _sprite.pixel_size = height / texture.get_height()
        # Feet on the ground.
        _sprite.offset = Vector2(0, texture.get_height() / 2.0)


## 1 is the drawing as is; more is wider.
func set_girth(girth: float) -> void:
    _sprite.scale.x = girth


## Knocked out: flat on the floor on its side, head to the left of the screen, facing up (lying
## head away from the camera would only look like a shorter standing figure).
func set_lying(lying: bool) -> void:
    if lying == _lying:
        return
    var camera := get_viewport().get_camera_3d() if is_inside_tree() else null
    if not lying:
        _lying = false
        _sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
        _sprite.basis = Basis.IDENTITY
        return
    if not camera:
        # Tried again next frame, once there is a camera to lie facing.
        return
    _lying = true
    _sprite.billboard = BaseMaterial3D.BILLBOARD_DISABLED
    var forward := -camera.global_basis.z
    forward.y = 0
    forward = forward.normalized()
    var right := forward.cross(Vector3.UP).normalized()
    var girth := _sprite.scale.x
    _sprite.global_basis = Basis(forward, -right, Vector3.UP)
    _sprite.scale.x = girth


## The head and shoulders of a character picture, e.g. for a menu.
static func portrait(texture: Texture2D) -> Texture2D:
    if not _portraits.has(texture):
        var head := AtlasTexture.new()
        head.atlas = texture
        head.region = Rect2(0, 0, texture.get_width(), texture.get_width() * PORTRAIT_RATIO)
        _portraits[texture] = head
    return _portraits[texture]
