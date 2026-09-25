class_name BeerCan
extends MeshInstance3D
## A Belgian pils can, inspired by the classic white, red and gold one, without its name or
## logo. Built in code (a cylinder and a painted texture) until the 3D artist makes a real one.

## Drawn a bit larger than life (a real can is 11.5 cm) so it reads from the camera.
const HEIGHT := 0.26
const RADIUS := 0.07
const TEXTURE_SIZE := Vector2i(256, 256)
const WHITE := Color(0.96, 0.96, 0.94)
const RED := Color(0.78, 0.07, 0.1)
const GOLD := Color(0.86, 0.68, 0.24)
const ALUMINIUM := Color(0.78, 0.8, 0.82)

static var _mesh: CylinderMesh


func _init() -> void:
    if not _mesh:
        _mesh = _build_mesh()
    mesh = _mesh


static func _build_mesh() -> CylinderMesh:
    var can := CylinderMesh.new()
    can.top_radius = RADIUS
    can.bottom_radius = RADIUS
    can.height = HEIGHT
    can.radial_segments = 24
    can.rings = 1
    var material := StandardMaterial3D.new()
    material.albedo_texture = ImageTexture.create_from_image(_paint())
    material.metallic = 0.4
    material.roughness = 0.35
    can.material = material
    return can


## The label, unrolled: aluminium rims, a white body, a wide red band edged with gold, and a
## gold medallion in the band on two sides of the can. CylinderMesh wraps the top half of the
## texture around the side and takes the lids from the bottom half, left aluminium.
static func _paint() -> Image:
    var image := Image.create(TEXTURE_SIZE.x, TEXTURE_SIZE.y, false, Image.FORMAT_RGB8)
    var w := TEXTURE_SIZE.x
    var h := TEXTURE_SIZE.y / 2
    image.fill(ALUMINIUM)
    image.fill_rect(Rect2i(0, h * 12 / 100, w, h * 76 / 100), WHITE)
    image.fill_rect(Rect2i(0, h * 38 / 100, w, h * 30 / 100), RED)
    image.fill_rect(Rect2i(0, h * 35 / 100, w, h * 3 / 100), GOLD)
    image.fill_rect(Rect2i(0, h * 68 / 100, w, h * 3 / 100), GOLD)
    for centre_x in [w / 4, w * 3 / 4]:
        var centre := Vector2(centre_x, h * 53 / 100)
        for y in range(h * 38 / 100, h * 68 / 100):
            for x in range(centre_x - h * 20 / 100, centre_x + h * 20 / 100):
                var distance := Vector2(x, y).distance_to(centre)
                if distance < h * 0.13:
                    image.set_pixel(x, y, GOLD if distance > h * 0.095 or distance < h * 0.055 else RED)
    return image
