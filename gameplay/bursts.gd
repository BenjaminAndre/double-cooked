class_name Bursts
extends RefCounted
## The artist's particle effects (DLC 1, docs/art/DLC1/Readme_DLC1.txt), with their Unity values
## and timings calibrated on the preview GIFs: banknotes for a customer served, grawlix for one
## leaving angry, beer drops where a beer lands on someone, and Z's over a sleeper.

const MONEY := preload("res://art/textures/MoneySheet.png")
const GRAWLIX := preload("res://art/textures/GrawlixSheet.png")
const BEER_DROP := preload("res://art/textures/Particle_BeerDrop.png")
const Z := preload("res://art/textures/Particle_Z.png")


## About 20 banknotes bursting out and spinning, ~1.2 s (MoneySheet, 3×3).
static func money(parent: Node, at: Vector3) -> CPUParticles3D:
    var burst := _burst(parent, at, MONEY, Vector2i(3, 3), 20, 1.2, 0.3)
    burst.emission_sphere_radius = 0.2
    burst.initial_velocity_min = 0.5
    burst.initial_velocity_max = 0.8
    burst.angular_velocity_min = -45.0
    burst.angular_velocity_max = 45.0
    burst.gravity = Vector3(0, -0.4, 0)
    return burst


## About 10 swear symbols around the customer, fading out within ~1 s (GrawlixSheet, 4×4).
static func grawlix(parent: Node, at: Vector3) -> CPUParticles3D:
    var burst := _burst(parent, at, GRAWLIX, Vector2i(4, 4), 10, 1.0, 0.5)
    burst.emission_sphere_radius = 0.65
    burst.initial_velocity_min = 0.2
    burst.initial_velocity_max = 0.2
    burst.angular_velocity_min = -45.0
    burst.angular_velocity_max = 45.0
    burst.gravity = Vector3.ZERO
    return burst


## Eight drops of beer splashing and falling, 0.5 s.
static func beer_drops(parent: Node, at: Vector3) -> CPUParticles3D:
    var burst := _burst(parent, at, BEER_DROP, Vector2i.ONE, 8, 0.5, 0.12)
    burst.emission_sphere_radius = 0.2
    burst.initial_velocity_min = 0.5
    burst.initial_velocity_max = 0.5
    burst.scale_amount_min = 0.08 / 0.12
    burst.gravity = Vector3(0, -4.0, 0)
    return burst


## Z's rising from a sleeper's head, small then growing until they fade: on while emitting (off
## at first: set emitting once it's in place).
static func zzz(parent: Node) -> CPUParticles3D:
    var stream := _particles(Z, Vector2i.ONE, 3, 1.6, 0.35)
    stream.one_shot = false
    stream.explosiveness = 0.0
    stream.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
    stream.emission_sphere_radius = 0.05
    stream.direction = Vector3(0.4, 1, 0)
    stream.spread = 15.0
    stream.initial_velocity_min = 0.35
    stream.initial_velocity_max = 0.45
    stream.gravity = Vector3.ZERO
    var grow := Curve.new()
    grow.add_point(Vector2(0, 0.15))
    grow.add_point(Vector2(1, 1))
    stream.scale_amount_curve = grow
    # Started once in place (see _burst).
    stream.emitting = false
    parent.add_child(stream)
    return stream


## A one-shot burst at a point of the world, freed once it's over.
static func _burst(parent: Node, at: Vector3, texture: Texture2D, frames: Vector2i, amount: int, lifetime: float,
        size: float) -> CPUParticles3D:
    var burst := _particles(texture, frames, amount, lifetime, size)
    burst.one_shot = true
    burst.explosiveness = 1.0
    burst.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
    burst.direction = Vector3.UP
    burst.spread = 180.0
    # Placed before it enters the tree: moved after, its first particles would start from the
    # parent's origin.
    burst.position = (parent as Node3D).to_local(at) if parent is Node3D else at
    parent.add_child(burst)
    burst.emitting = true
    burst.finished.connect(burst.queue_free)
    return burst


## Particles drawn as the artist's picture (a random cell of its sheet), facing the camera, over
## everything, fading out at the end of their life.
static func _particles(texture: Texture2D, frames: Vector2i, amount: int, lifetime: float,
        size: float) -> CPUParticles3D:
    var particles := CPUParticles3D.new()
    var quad := QuadMesh.new()
    quad.size = Vector2.ONE * size
    var material := StandardMaterial3D.new()
    material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    material.albedo_texture = texture
    material.vertex_color_use_as_albedo = true
    material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
    material.billboard_keep_scale = true
    material.no_depth_test = true
    material.render_priority = 5
    material.particles_anim_h_frames = frames.x
    material.particles_anim_v_frames = frames.y
    material.particles_anim_loop = false
    quad.material = material
    particles.mesh = quad
    particles.amount = amount
    particles.lifetime = lifetime
    particles.local_coords = false
    # A random cell of the sheet each, kept for its life.
    particles.anim_speed_min = 0.0
    particles.anim_speed_max = 0.0
    particles.anim_offset_min = 0.0
    particles.anim_offset_max = 1.0
    var fade := Gradient.new()
    fade.set_color(0, Color.WHITE)
    fade.set_color(1, Color(1, 1, 1, 0))
    fade.add_point(0.6, Color.WHITE)
    particles.color_ramp = fade
    return particles
