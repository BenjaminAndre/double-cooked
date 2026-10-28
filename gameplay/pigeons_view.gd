class_name PigeonsView
extends Node3D
## The pigeons in the kitchen (Simulation.pigeons, GDD §8), the artist's FlyingBird (DLC 1): they
## glide in from over the door to their station, facing the way they fly, and bob while they peck.

const PICTURE := preload("res://art/textures/FlyingBird.png")
## How tall a pigeon is drawn, in metres.
const HEIGHT := 0.4
## Over a station's centre, where a pigeon stands.
const PERCH := Vector3(0, 0.6, 0)
## Where they come from: high over the front of the line.
const FROM := Vector3(0, 3.0, 0)

var night: Night
## Pigeon id -> its sprite.
var _figures := {}


func _init(p_night: Night) -> void:
    night = p_night


func _process(_delta: float) -> void:
    var sim := night.simulation
    if not sim or night.in_lobby:
        _clear({})
        return
    var camera := get_viewport().get_camera_3d()
    var seen := {}
    for pigeon in sim.pigeons:
        seen[pigeon.id] = true
        if not _figures.has(pigeon.id):
            _figures[pigeon.id] = _new_figure()
            add_child(_figures[pigeon.id])
        var figure: Sprite3D = _figures[pigeon.id]
        var perch := night.station_centre(pigeon.station) + PERCH
        var from := night.queue.global_position + FROM if night.queue else perch + FROM
        # The picture looks right: flipped when the pigeon came from the right of the screen.
        if camera:
            figure.flip_h = (perch - from).dot(camera.global_basis.x) < 0.0
        if pigeon.landed():
            # Pecking: a quick bob.
            figure.global_position = perch + Vector3.UP * absf(sin(Time.get_ticks_msec() * 0.012)) * 0.05
        else:
            var t := 1.0 - (pigeon.flying - night.alpha) / sim.rules.pigeon_flight
            figure.global_position = from.lerp(perch, clampf(t, 0.0, 1.0))
    _clear(seen)


## Frees the figures of pigeons gone (not in keep).
func _clear(keep: Dictionary) -> void:
    for id: int in _figures.keys():
        if not keep.has(id):
            _figures[id].queue_free()
            _figures.erase(id)


func _new_figure() -> Sprite3D:
    var figure := Sprite3D.new()
    figure.texture = PICTURE
    figure.pixel_size = HEIGHT / PICTURE.get_height()
    figure.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    figure.shaded = false
    figure.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
    # Over everything, so a pigeon behind a hood still shows.
    figure.no_depth_test = true
    figure.render_priority = 10
    return figure
