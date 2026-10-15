class_name TutorialView
extends Node3D
## The tutorial's pointer (Tutorial, GDD §4.4): the artist's arrow bobbing over each station the
## current step is about.

const HEIGHT := 1.4

var night: Night
var _arrows: Array[Sprite3D] = []


func _init(p_night: Night) -> void:
    night = p_night


func _process(_delta: float) -> void:
    var sim := night.simulation
    var spots: Array[Vector3] = []
    if sim and sim.tutorial and sim.outcome == &"" and not night.in_lobby:
        var kind: StringName = sim.tutorial.current().get("station", &"")
        for index in sim.stations.size():
            if kind != &"" and sim.stations[index].kind == kind:
                spots.append(night.station_centre(index) + Vector3.UP * HEIGHT)
    while _arrows.size() < spots.size():
        var arrow := Sprite3D.new()
        # The artist's arrow points up: turned to point down at the station.
        arrow.texture = preload("res://art/textures/UX_Arrow.png")
        arrow.flip_v = true
        arrow.pixel_size = 0.003
        arrow.billboard = BaseMaterial3D.BILLBOARD_ENABLED
        arrow.no_depth_test = true
        add_child(arrow)
        _arrows.append(arrow)
    var bob := 0.08 * sin(Time.get_ticks_msec() * 0.008)
    for index in _arrows.size():
        _arrows[index].visible = index < spots.size()
        if _arrows[index].visible:
            _arrows[index].global_position = spots[index] + Vector3.UP * bob
