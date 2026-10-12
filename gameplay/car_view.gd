class_name CarView
extends Node3D
## The car crash (NightEvents.CAR_CRASH, GDD §6.4), as placeholders until the artist's car:
## headlights flashing where it will hit while it comes, then a red box on the rubble.

const BODY := Color(0.8, 0.12, 0.1)
const LIGHT := Color(1.0, 0.95, 0.5)
const SIZE := Vector3(1.0, 0.8, 1.9)

var night: Night
var _car: MeshInstance3D
var _lights: Array[MeshInstance3D] = []


func _init(p_night: Night) -> void:
    night = p_night
    _car = _box(SIZE, BODY)
    add_child(_car)
    for side in [-1, 1]:
        var light := _box(Vector3.ONE * 0.25, LIGHT)
        light.position = Vector3(side * 0.3, 0.5, 0)
        _lights.append(light)
        add_child(light)


func _process(_delta: float) -> void:
    var sim := night.simulation
    var crash := sim.level.crash_nodes if sim and not night.in_lobby else PackedInt32Array()
    var coming := not crash.is_empty() and sim.night_events.car_coming > 0
    var crashed := not crash.is_empty() and sim.blocked.has(crash[0])
    _car.visible = crashed
    var flash := coming and int(Time.get_ticks_msec() / 150) % 2 == 0
    for light in _lights:
        light.visible = flash
    if coming or crashed:
        var centre := Vector3.ZERO
        for node in crash:
            centre += sim.level.positions[node]
        global_position = centre / crash.size()
        _car.position = Vector3.UP * SIZE.y / 2


func _box(size: Vector3, color: Color) -> MeshInstance3D:
    var mesh := BoxMesh.new()
    mesh.size = size
    var material := StandardMaterial3D.new()
    material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    material.albedo_color = color
    mesh.material = material
    var box := MeshInstance3D.new()
    box.mesh = mesh
    box.visible = false
    return box
