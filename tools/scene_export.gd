extends SceneTree
## Builds a Godot scene from one of the artist's Unity scene exports (docs/art/SceneExport_*.md):
## the room and its props where the artist placed them, the camera, the floor squares (Cases)
## and the particles' places (Oil, Fire) as markers.
##
##     godot --headless --path . -s res://tools/scene_export.gd -- docs/art/SceneExport_X.md art/scenes/X.tscn
##
## Our FBX imports are Unity's mirrored on X: a Unity position (x, y, z) is (-x, y, z) here, and
## a turn about Y goes the other way. The -90° about X on every model is Unity's FBX import, not
## ours, and is dropped. (The export's own "Godot" lines assume a Z mirror instead: unused.)

const MODELS := "res://art/models/%s"

## Unity path -> its mesh's asset, to tell a model's parts from models placed under it.
var _assets := {}


func _init() -> void:
    var args := OS.get_cmdline_user_args()
    if args.size() < 2:
        printerr("Usage: -- <export.md> <out.tscn>")
        quit(1)
        return
    var root := Node3D.new()
    root.name = args[1].get_file().get_basename()
    var markers := {}
    var entry := {}
    var section := ""
    for line: String in FileAccess.get_file_as_string(args[0]).split("\n"):
        line = line.strip_edges(false, true)
        if line.begins_with("## "):
            _add(root, entry, markers)
            entry = {}
            section = line.trim_prefix("## ")
        elif line.begins_with("- "):
            _add(root, entry, markers)
            entry = {"title": line.trim_prefix("- "), "section": section}
        elif line.begins_with("  - ") and not entry.is_empty():
            var parts := line.trim_prefix("  - ").split(" : ", true, 1)
            if parts.size() == 2:
                entry[parts[0].strip_edges()] = parts[1].strip_edges()
    _add(root, entry, markers)
    var scene := PackedScene.new()
    var error := scene.pack(root)
    if error == OK:
        DirAccess.make_dir_recursive_absolute(args[1].get_base_dir())
        error = ResourceSaver.save(scene, "res://" + args[1])
    print("Saved %s: %s" % [args[1], error_string(error)])
    root.free()
    quit(0 if error == OK else 1)


func _add(root: Node3D, entry: Dictionary, markers: Dictionary) -> void:
    if entry.is_empty():
        return
    var title: String = entry.title
    if title.begins_with("Caméra"):
        _add_camera(root, entry)
        return
    var where: String = entry.get("Position monde Unity", "")
    if where == "":
        return
    var position := _vector(where.split("|")[0])
    if entry.section == "Particle System":
        var kind := "Oil" if "FryingOil" in title else "Fire"
        _marker(root, markers, kind, position)
        return
    var path := title.get_slice("chemin : ", 1).get_slice(",", 0)
    if "[CASES]" in path:
        _marker(root, markers, "Cases", position)
        return
    var asset: String = entry.get("Mesh", "").get_slice("asset : ", 1)
    _assets[path] = asset
    # Only the models placed in the scene, even under another one (the bread bag on its
    # counter): a model's own parts come with it.
    if not asset.ends_with(".fbx") or "INACTIF" in title or _assets.get(path.get_base_dir(), "") == asset:
        return
    var model: Node3D = (load(MODELS % asset.get_file()) as PackedScene).instantiate()
    model.name = path.get_file()
    model.position = position
    model.rotation.y = -deg_to_rad(_vector(entry.get("Rotation monde Unity (euler)", "(0, 0, 0)")).y)
    model.scale = _vector(entry.get("Échelle monde (lossy)", "(1, 1, 1)"), false)
    root.add_child(model)
    model.owner = root


func _add_camera(root: Node3D, entry: Dictionary) -> void:
    var camera := Camera3D.new()
    camera.name = "Camera"
    var euler := _vector(entry.get("Rotation monde Unity (euler)", "(0, 0, 0)"), false)
    var pitch := deg_to_rad(euler.x)
    var yaw := deg_to_rad(euler.y)
    # Unity's forward for this pitch and yaw, mirrored on X.
    var forward := Vector3(-sin(yaw) * cos(pitch), -sin(pitch), cos(yaw) * cos(pitch))
    var eye := _vector(entry.get("Position monde Unity", "(0, 0, 0)"))
    camera.transform = Transform3D.IDENTITY.looking_at(forward, Vector3.UP).translated(eye)
    camera.fov = float(entry.get("Field of view (vertical)", "25"))
    var near_far: String = entry.get("Near/Far", "0.3 / 50")
    camera.near = float(near_far.get_slice("/", 0))
    camera.far = float(near_far.get_slice("/", 1))
    root.add_child(camera)
    camera.owner = root


func _marker(root: Node3D, markers: Dictionary, group: String, position: Vector3) -> void:
    if not markers.has(group):
        var parent := Node3D.new()
        parent.name = group
        root.add_child(parent)
        parent.owner = root
        markers[group] = parent
    var marker := Marker3D.new()
    marker.position = position
    markers[group].add_child(marker)
    marker.owner = root
    marker.name = "%s%d" % [group.trim_suffix("s"), marker.get_index()]


## "(x, y, z)" from Unity; mirrored on X unless mirror is false (scales, angles).
func _vector(text: String, mirror := true) -> Vector3:
    var numbers := text.strip_edges().trim_prefix("(").trim_suffix(")").split(",")
    var vector := Vector3(float(numbers[0]), float(numbers[1]), float(numbers[2]))
    if mirror:
        vector.x = -vector.x
    return vector
