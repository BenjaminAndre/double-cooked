class_name PigeonsView
extends Node3D
## The pigeons in the kitchen (Simulation.pigeons, GDD §8), as placeholders until the artist's
## pigeon: a grey body, a head and an orange beak. They glide in from over the door to their
## station and bob while they peck.

## Over a station's centre, where a pigeon stands.
const PERCH := Vector3(0, 0.6, 0)
## Placeholders are drawn over everything, so a pigeon behind a hood still shows.
const SIZE := 1.8
## Where they come from: high over the front of the line.
const FROM := Vector3(0, 3.0, 0)
const BODY := Color(0.55, 0.57, 0.62)
const HEAD := Color(0.35, 0.38, 0.45)
const BEAK := Color(0.95, 0.6, 0.15)

var night: Night
## Pigeon id -> its figure.
var _figures := {}


func _init(p_night: Night) -> void:
    night = p_night


func _process(_delta: float) -> void:
    var sim := night.simulation
    if not sim or night.in_lobby:
        _clear({})
        return
    var seen := {}
    for pigeon in sim.pigeons:
        seen[pigeon.id] = true
        if not _figures.has(pigeon.id):
            _figures[pigeon.id] = _new_figure()
            add_child(_figures[pigeon.id])
        var figure: Node3D = _figures[pigeon.id]
        var perch := night.station_centre(pigeon.station) + PERCH
        if pigeon.landed():
            # Pecking: a quick bob.
            figure.global_position = perch + Vector3.UP * absf(sin(Time.get_ticks_msec() * 0.012)) * 0.05
        else:
            var from := night.queue.global_position + FROM if night.queue else perch + FROM
            var t := 1.0 - (pigeon.flying - night.alpha) / sim.rules.pigeon_flight
            figure.global_position = from.lerp(perch, clampf(t, 0.0, 1.0))
    _clear(seen)


## Frees the figures of pigeons gone (not in keep).
func _clear(keep: Dictionary) -> void:
    for id: int in _figures.keys():
        if not keep.has(id):
            _figures[id].queue_free()
            _figures.erase(id)


func _new_figure() -> Node3D:
    var figure := Node3D.new()
    figure.add_child(_ball(Vector3(0.16, 0.12, 0.12), Vector3.ZERO, BODY))
    figure.add_child(_ball(Vector3(0.08, 0.08, 0.08), Vector3(0.12, 0.09, 0), HEAD))
    figure.add_child(_ball(Vector3(0.04, 0.025, 0.025), Vector3(0.19, 0.08, 0), BEAK))
    return figure


func _ball(radii: Vector3, at: Vector3, color: Color) -> MeshInstance3D:
    var mesh := SphereMesh.new()
    mesh.radius = 1.0
    mesh.height = 2.0
    var material := StandardMaterial3D.new()
    material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    material.albedo_color = color
    material.no_depth_test = true
    material.render_priority = 10
    mesh.material = material
    var ball := MeshInstance3D.new()
    ball.mesh = mesh
    ball.scale = radii * SIZE
    ball.position = at * SIZE
    return ball
