class_name GridRoom
extends Node3D
## A room built in code from a grid layout, instead of placing every Anchor and station by
## hand: the lobby (GDD §4.1) and the kitchen, later kitchens sized for the player count.
##
## layout holds one string per row, the top row first (the far side, seen from the camera).
## Each cell is one of:
## - a station kind, e.g. "caisse";
## - "+": the station of the cell on its left, which spans both cells (VIANDES);
## - "." for bare floor;
## - "-" for no cell at all (a gap, e.g. a row that is only a doorway).
## A trailing "@" marks where a player starts ("@" alone: bare floor), in reading order.
## Top-row stations stand behind their cell, bottom-row ones in front of it; a "pret" cell is a
## tile on the floor. Columns run to the right of the screen.
##
## names, if given, names the cells the same way (one string per row), e.g. to keep the names
## that replays refer to; otherwise they are "Cell<row>_<column>".

const ANCHOR_SCENE := preload("res://gameplay/anchor.tscn")
const FLOOR := preload("res://assets/kenney_prototype-kit/Models/GLB format/floor-small-square.glb")
const SPACING := 1.0
const LABELS := {
    &"peinture": "PEINTURE",
    &"casquette": "CASQUETTE",
    &"telephone": "TÉLÉPHONE",
    &"porte": "PORTE",
    &"pret": "PRÊT",
    &"frigo": "FRIGO",
    &"cuisson_1": "CUISSON 1",
    &"cuisson_2": "CUISSON 2",
    &"cuisson_viande": "CUISSON VIANDE",
    &"pain": "PAIN",
    &"extincteur": "EXTINCTEUR",
    &"sauces": "SAUCES",
    &"caisse": "CAISSE",
    &"viandes": "VIANDES",
    &"poubelle": "POUBELLE",
}
const COLORS := {
    &"peinture": Color(0.85, 0.35, 0.6),
    &"casquette": Color(0.35, 0.55, 0.85),
    &"telephone": Color(0.3, 0.3, 0.35),
    &"porte": Color(0.55, 0.35, 0.2),
    &"pret": Color(0.3, 0.8, 0.35),
    &"frigo": Color(0.2, 0.45, 0.8),
    &"cuisson_1": Color(0.85, 0.8, 0.2),
    &"cuisson_2": Color(0.8, 0.7, 0.15),
    &"cuisson_viande": Color(0.75, 0.45, 0.15),
    &"pain": Color(0.7, 0.5, 0.25),
    &"extincteur": Color(0.8, 0.15, 0.15),
    &"sauces": Color(0.75, 0.4, 0.75),
    &"caisse": Color(0.8, 0.8, 0.8),
    &"viandes": Color(0.45, 0.28, 0.15),
    &"poubelle": Color(0.4, 0.4, 0.4),
}
## The 3/4 view (docs/ART_PLAN.md): turned 45° so both grid axes are symmetric diagonals on
## screen, looking down at camera_pitch degrees from camera_distance. A narrow field of view
## as in the artist's scene (Readme_SettingsV2), so the room looks flatter.
const CAMERA_FOV := 25.0
## Colours of the floor squares: as they are, under a player, under a station not in use.
const SQUARE := Color(1, 1, 1, 60 / 255.0)
const SQUARE_TAKEN := Color("FFF0D8", 120 / 255.0)
const SQUARE_IDLE := Color(0.1, 0.1, 0.12, 0.35)
## A PRÊT cell's square, green.
const SQUARE_READY := Color(0.3, 0.85, 0.35, 0.55)
const SQUARE_SIZE := Vector3(0.7, 0.108, 0.7)
## The artist's model each station owns (its door, lid or look), by name.
const ART_MODELS := {
    &"frigo": "DoubleCooked_Fridge",
    &"poubelle": "DoubleCooked_Trash",
    &"pain": "DoubleCooked_BreadBag",
    &"caisse": "DoubleCooked_CashRegister",
    &"extincteur": "DoubleCooked_FireCase",
}
## Where the fryers' names float in the artist's kitchen.
const ART_LABEL_HEIGHT := 1.1
## A quarter of a cell: from its middle to the middle of its half.
const SHELF_QUARTER := 0.25

@export var layout := PackedStringArray()
@export var names := PackedStringArray()
## Kenney floor tiles under each cell (the kitchen has the artist's floor instead).
@export var floor_tiles := true
## How far station boxes stand from their cell, behind the top row and in front of the bottom one.
@export var back_offset := 0.8
@export var front_offset := 0.8
@export var camera_pitch := 45.0
@export var camera_distance := 10.0
## -1 or 1: which front corner the camera looks from.
@export var camera_side := 1.0
## How far the camera turns from straight in front of the grid, in degrees (45: both axes
## symmetric).
@export var camera_yaw := 45.0
## Where the camera looks, from the grid's centre (in the room's own axes), e.g. to take in
## the line of customers outside.
@export var camera_target := Vector3.ZERO
## The artist's scene the room stands in (tools/scene_export.gd), if any: its camera replaces the
## room's own, its models go to the stations they belong to (the FRIGO's door and beers, the
## bin's lid, the fryer's baskets and cooked fries), and the stations' boxes hide.
@export var art: Node3D
## The artist's floor squares, one per cell (Readme_SettingsV3): white, warmer under a player,
## dark under a station with nothing to do tonight (show_squares).
@export var squares := false
## Every station keeps its name over it, e.g. in the lobby, where its look doesn't tell it apart;
## otherwise, with art, only the fryers do.
@export var labels := false

var camera: Camera3D
var _anchors: Node3D
var _spawns: Array[String] = []
## Columns and rows of the grid.
var _size := Vector2i.ONE
## One floor square per cell, in the anchors' order (squares).
var _squares: Array[MeshInstance3D] = []
## Each square's own colour, when nobody stands on it.
var _square_colors: Array[Color] = []
## Square colour -> its material, shared by every square.
static var _square_materials := {}


## The parent of the room's Anchors, built on first use (Night reads it in its own _ready).
func anchors_root() -> Node3D:
    if not _anchors:
        _build()
    return _anchors


## The names of the anchors where players start, in slot order.
func spawn_names() -> Array[String]:
    anchors_root()
    return _spawns


func _build() -> void:
    _anchors = Node3D.new()
    _anchors.name = "Anchors"
    add_child(_anchors)
    var stations := Node3D.new()
    stations.name = "Stations"
    add_child(stations)
    var grid := []
    for row in layout.size():
        var cells := layout[row].split(" ", false)
        var cell_names := names[row].split(" ", false) if row < names.size() else PackedStringArray()
        var line := []
        var previous: Interactible = null
        for column in cells.size():
            var cell := cells[column]
            if cell == "-":
                line.append(null)
                previous = null
                continue
            var anchor: Anchor = ANCHOR_SCENE.instantiate()
            anchor.name = cell_names[column] if column < cell_names.size() else "Cell%d_%d" % [row, column]
            # Right on screen is -x, the top row is +z.
            anchor.position = Vector3(-column, 0, -row) * SPACING
            _anchors.add_child(anchor)
            if squares:
                _squares.append(_square(anchor))
                _square_colors.append(SQUARE_READY if cell.trim_suffix("@") == "pret" else SQUARE)
            if floor_tiles:
                var floor_tile: Node3D = FLOOR.instantiate()
                floor_tile.position = anchor.position
                add_child(floor_tile)
            if cell.ends_with("@"):
                _spawns.append(anchor.name)
                cell = cell.trim_suffix("@")
            if cell == "+" and previous:
                _widen(previous)
                anchor.interactible = previous
            elif cell != "." and cell != "":
                var side := 0.0
                if row == 0:
                    side = back_offset
                elif row == layout.size() - 1:
                    side = -front_offset
                previous = _station(stations, StringName(cell), anchor.position, side)
                anchor.interactible = previous
            else:
                previous = null
            line.append(anchor)
        grid.append(line)
    for row in grid.size():
        for column in grid[row].size():
            var anchor: Anchor = grid[row][column]
            if not anchor:
                continue
            if row > 0 and column < grid[row - 1].size():
                anchor.up = grid[row - 1][column]
            if row + 1 < grid.size() and column < grid[row + 1].size():
                anchor.down = grid[row + 1][column]
            if column > 0:
                anchor.left = grid[row][column - 1]
            if column + 1 < grid[row].size():
                anchor.right = grid[row][column + 1]
    _size = Vector2i(grid[0].size() if not grid.is_empty() else 1, grid.size())
    if art and art.get_node_or_null("Camera"):
        camera = art.get_node("Camera")
        _use_art(stations)
        return
    camera = Camera3D.new()
    camera.fov = CAMERA_FOV
    add_child(camera)
    place_camera()


## Puts the camera where the camera_* settings say, e.g. again after changing them.
func place_camera() -> void:
    if art:
        return
    var centre := Vector3(-(_size.x - 1) / 2.0, 0, -(_size.y - 1) / 2.0) * SPACING + camera_target
    # From the front (-z), turned camera_yaw towards camera_side, looking down camera_pitch.
    var pitch := deg_to_rad(camera_pitch)
    var flat := Vector3(0, 0, -1).rotated(Vector3.UP, -camera_side * deg_to_rad(camera_yaw)) * cos(pitch)
    var eye := centre + (flat + Vector3.UP * sin(pitch)) * camera_distance
    camera.transform = Transform3D.IDENTITY.looking_at(centre - eye, Vector3.UP).translated(eye)


## offset: how far the box stands from its cell, + behind (top row), - in front (bottom row),
## 0 on the cell itself.
func _station(parent: Node3D, kind: StringName, at: Vector3, offset: float) -> Interactible:
    var station := Interactible.new()
    station.kind = kind
    station.name = String(kind).capitalize().replace(" ", "")
    var box := CSGBox3D.new()
    box.name = "CSGBox3D"
    var material := StandardMaterial3D.new()
    material.albedo_color = COLORS.get(kind, Color.GRAY)
    box.material = material
    if kind == &"pret":
        # A tile to stand on.
        station.position = at
        box.size = Vector3(0.8, 0.04, 0.8)
        box.position.y = 0.02
    else:
        station.position = at + Vector3(0, 0, offset)
        var tall := kind in [&"porte", &"frigo"]
        box.size = Vector3(0.8, 1.8 if tall else 0.9, 0.5)
        box.position.y = box.size.y / 2
    station.add_child(box)
    var label := Label3D.new()
    label.name = "Label"
    label.text = LABELS.get(kind, String(kind).to_upper())
    label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    label.font_size = 36
    label.outline_size = 8
    label.position.y = box.size.y + 0.25 if kind != &"pret" else 0.3
    station.add_child(label)
    parent.add_child(station)
    return station


## One more cell to the right for this station: its box and label stretch over it.
func _widen(station: Interactible) -> void:
    var box: CSGBox3D = station.get_node("CSGBox3D")
    box.size.x += SPACING
    box.position.x -= SPACING / 2
    var label: Label3D = station.get_node("Label")
    label.position.x -= SPACING / 2


func _square(anchor: Anchor) -> MeshInstance3D:
    var square := MeshInstance3D.new()
    square.name = "Square"
    var mesh := BoxMesh.new()
    mesh.size = SQUARE_SIZE
    square.mesh = mesh
    square.material_override = _square_material(SQUARE)
    anchor.add_child(square)
    return square


## taken: nodes (anchor indices) a player stands on; idle: nodes at a station with nothing to
## do tonight. Only on change: a material swap, never a rebuild.
func show_squares(taken: Dictionary, idle: Dictionary) -> void:
    for index in _squares.size():
        var color := SQUARE_TAKEN if taken.has(index) else SQUARE_IDLE if idle.has(index) else _square_colors[index]
        var material := _square_material(color)
        if _squares[index].material_override != material:
            _squares[index].material_override = material


static func _square_material(color: Color) -> StandardMaterial3D:
    if not _square_materials.has(color):
        var material := StandardMaterial3D.new()
        material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
        material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
        material.albedo_color = color
        _square_materials[color] = material
    return _square_materials[color]


## Hands the artist's models to the stations they belong to, the nearest of each kind, and hides
## the stations' boxes. Only the fryers keep their name: the cooking stations look alike.
func _use_art(stations: Node3D) -> void:
    for station: Interactible in stations.get_children():
        var box: CSGBox3D = station.get_node("CSGBox3D")
        box.visible = false
        var label: Label3D = station.get_node("Label")
        label.visible = labels or station.kind in Interactible.FRYERS
        # A PRÊT tile's name stays low, on its tile.
        label.position.y = ART_LABEL_HEIGHT if station.kind != &"pret" else label.position.y
        var model_name: String = ART_MODELS.get(station.kind, "")
        if model_name != "":
            station.models = _nearest(station, art.get_children().filter(
                    func(node: Node) -> bool: return node.name.begins_with(model_name)))
        match station.kind:
            &"frigo":
                if station.models:
                    station.stock_models = _sorted(station.models.find_children("*_Beers0*", "", true, false))
            &"cuisson_1":
                var fryer := art.get_node_or_null("DoubleCooked_DeepFryer")
                if fryer:
                    station.cooked_models = _sorted(fryer.find_children("DoubleCooked_FriesCooked*", "", true, false))
                    _share_shelf(station, fryer.find_child("DoubleCooked_FriesRaw", true, false), station.cooked_models)
            &"cuisson_viande":
                var fryer := art.get_node_or_null("DoubleCooked_DeepFryer")
                if fryer:
                    station.basket_model = _nearest(station, fryer.find_children("DoubleCooked_DeepFryer_Basket*", "", true, false))
                    var player := fryer.find_child("AnimationPlayer", true, false) as AnimationPlayer
                    if station.basket_model and player and not player.get_animation_list().is_empty():
                        station.basket_model.set_meta(StationModels.EJECT, StationModels.eject_frames(
                                player.get_animation(player.get_animation_list()[0]), station.basket_model.name))


## The batch's portions wait on CUISSON 1 (GDD §7.1), but the artist drew them over CUISSON 2.
## They share CUISSON 1's shelf with the raw fries: the raw pile, squashed to half its length, on
## the half away from CUISSON 2, the portions on the other half.
func _share_shelf(station: Node3D, raw: Node3D, cooked: Array) -> void:
    if not raw or cooked.is_empty():
        return
    var cell := _world(station).z
    var middle := 0.0
    for portion: Node3D in cooked:
        middle += _world(portion).z / cooked.size()
    # Towards CUISSON 2: where the artist put the portions.
    var towards := signf(middle - cell)
    for portion: Node3D in cooked:
        var where := _world_transform(portion)
        where.origin.z += cell + towards * SHELF_QUARTER - middle
        _set_world_transform(portion, where)
    var pile := _world_transform(raw)
    pile.basis = Basis.from_scale(Vector3(1, 1, 0.5)) * pile.basis
    pile.origin.z = cell - towards * SHELF_QUARTER
    _set_world_transform(raw, pile)


## The node nearest to the station on the floor, null if there is none.
func _nearest(station: Node3D, nodes: Array) -> Node3D:
    var best: Node3D = null
    var at := _world(station)
    for node: Node3D in nodes:
        if not best or _flat_distance(_world(node), at) < _flat_distance(_world(best), at):
            best = node
    return best


static func _flat_distance(a: Vector3, b: Vector3) -> float:
    return Vector2(a.x - b.x, a.z - b.z).length()


static func _sorted(nodes: Array) -> Array:
    nodes.sort_custom(func(a: Node, b: Node) -> bool: return String(a.name) < String(b.name))
    return nodes


## Like global_transform, before the room is in the tree.
static func _world_transform(node: Node) -> Transform3D:
    var transform := Transform3D.IDENTITY
    var current: Node = node
    while current is Node3D:
        transform = (current as Node3D).transform * transform
        current = current.get_parent()
    return transform


static func _set_world_transform(node: Node3D, transform: Transform3D) -> void:
    node.transform = _world_transform(node.get_parent()).affine_inverse() * transform


## Like global_position, before the room is in the tree (Night reads it in its own _ready).
static func _world(node: Node3D) -> Vector3:
    var transform := Transform3D.IDENTITY
    var current: Node = node
    while current is Node3D:
        transform = (current as Node3D).transform * transform
        current = current.get_parent()
    return transform.origin
