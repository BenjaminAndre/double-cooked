class_name ProjectilesView
extends Node3D
## Shows the cans in the air (GDD §8): a spinning can on its arc, and for cans thrown at the
## crew, the whole arc and a red ring where it will land, so players can dodge. Also shows the
## beer target cursor of the players at this keyboard.

const ARC_DOTS := 14
const DANGER := Color(1.0, 0.25, 0.2)
const CURSOR := Color(1.0, 0.85, 0.2)
## Just above a customer's head (they are drawn at 60% of a player's size).
const CURSOR_HEIGHT := 0.6
## Above a teammate's hearts and hand.
const MATE_CURSOR_HEIGHT := 1.75

@export var night: Night

## SimProjectile -> its nodes: [can, warning (or null)].
var _shown := {}
var _cursors: Array[Sprite3D] = []


func _process(_delta: float) -> void:
    var sim := night.simulation
    if not sim:
        return
    var now := sim.tick + night.alpha
    for projectile: SimProjectile in _shown.keys():
        if not projectile in sim.projectiles:
            for node in _shown[projectile]:
                if node:
                    node.queue_free()
            _shown.erase(projectile)
    for projectile in sim.projectiles:
        if not _shown.has(projectile):
            _shown[projectile] = [_new_can(), _new_warning(projectile) if projectile.kind == SimProjectile.CAN else null]
        var can: Node3D = _shown[projectile][0]
        can.position = projectile.position_at(now)
        can.rotation.x = now * 0.4
        can.rotation.z = now * 0.25
    _show_cursors(sim)


## A bobbing arrow over the customer or teammate each local player aims at, once the aim is held.
func _show_cursors(sim: Simulation) -> void:
    var aims: Array[Vector3] = []
    for slot in night.local_slots():
        var player := sim.players[slot]
        if player.aim >= 0 and player.aim_ticks >= sim.rules.aim_hold:
            if player.aim_player >= 0:
                aims.append(sim.player_position(sim.players[player.aim_player]) + Vector3.UP * MATE_CURSOR_HEIGHT)
            else:
                aims.append(sim.level.queue_position(player.aim) + Vector3.UP * CURSOR_HEIGHT)
    while _cursors.size() < aims.size():
        var cursor := Sprite3D.new()
        cursor.texture = Icons.arrow_down()
        cursor.pixel_size = 0.004
        cursor.modulate = CURSOR
        cursor.billboard = BaseMaterial3D.BILLBOARD_ENABLED
        cursor.no_depth_test = true
        add_child(cursor)
        _cursors.append(cursor)
    for index in _cursors.size():
        _cursors[index].visible = index < aims.size()
        if _cursors[index].visible:
            var bob := 0.05 * sin(Time.get_ticks_msec() * 0.01)
            _cursors[index].position = aims[index] + Vector3.UP * bob


func _new_can() -> Node3D:
    var can := BeerCan.new()
    add_child(can)
    return can


## The dotted arc and the landing ring of a can thrown at the crew.
func _new_warning(projectile: SimProjectile) -> Node3D:
    var warning := Node3D.new()
    var dot := SphereMesh.new()
    dot.radius = 0.03
    dot.height = 0.06
    dot.material = _flat(Color(DANGER, 0.7))
    for index in range(1, ARC_DOTS):
        var part := MeshInstance3D.new()
        part.mesh = dot
        part.position = projectile.position_at(projectile.start + projectile.duration * float(index) / ARC_DOTS)
        warning.add_child(part)
    var ring := MeshInstance3D.new()
    var torus := TorusMesh.new()
    torus.inner_radius = night.simulation.rules.can_radius - 0.06
    torus.outer_radius = night.simulation.rules.can_radius
    torus.material = _flat(DANGER)
    ring.mesh = torus
    ring.position = Vector3(projectile.to.x, 0.02, projectile.to.z)
    warning.add_child(ring)
    add_child(warning)
    return warning


func _flat(color: Color) -> StandardMaterial3D:
    var material := StandardMaterial3D.new()
    material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    if color.a < 1.0:
        material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    material.albedo_color = color
    return material
