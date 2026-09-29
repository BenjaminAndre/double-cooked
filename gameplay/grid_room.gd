class_name GridRoom
extends Node3D
## A room built in code from a grid layout, instead of placing every Anchor and station by
## hand: the lobby (GDD §4.1) and the kitchen, later kitchens sized for the player count.
##
## layout holds one string per row, the top row first (the far side, seen from the camera).
## Each cell is one of:
## - a station kind, e.g. "caisse";
## - "+": the station of the cell on its left, which spans both cells (CUISSON 1);
## - "." for bare floor.
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
    &"pain": Color(0.7, 0.5, 0.25),
    &"extincteur": Color(0.8, 0.15, 0.15),
    &"sauces": Color(0.75, 0.4, 0.75),
    &"caisse": Color(0.8, 0.8, 0.8),
    &"viandes": Color(0.45, 0.28, 0.15),
    &"poubelle": Color(0.4, 0.4, 0.4),
}
## The 3/4 view (docs/ART_PLAN.md): turned 45° so both grid axes are symmetric diagonals on
## screen, looking down at camera_pitch degrees from camera_distance.
const CAMERA_FOV := 35.0

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
## Where the camera looks, from the grid's centre (in the room's own axes), e.g. to take in
## the line of customers outside.
@export var camera_target := Vector3.ZERO

var camera: Camera3D
var _anchors: Node3D
var _spawns: Array[String] = []


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
            var anchor: Anchor = ANCHOR_SCENE.instantiate()
            anchor.name = cell_names[column] if column < cell_names.size() else "Cell%d_%d" % [row, column]
            # Right on screen is -x, the top row is +z.
            anchor.position = Vector3(-column, 0, -row) * SPACING
            _anchors.add_child(anchor)
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
            if row > 0 and column < grid[row - 1].size():
                anchor.up = grid[row - 1][column]
            if row + 1 < grid.size() and column < grid[row + 1].size():
                anchor.down = grid[row + 1][column]
            if column > 0:
                anchor.left = grid[row][column - 1]
            if column + 1 < grid[row].size():
                anchor.right = grid[row][column + 1]
    camera = Camera3D.new()
    camera.fov = CAMERA_FOV
    var width: int = grid[0].size() if not grid.is_empty() else 1
    var centre := Vector3(-(width - 1) / 2.0, 0, -(grid.size() - 1) / 2.0) * SPACING + camera_target
    # From the front (-z), on one side, turned 45°.
    var pitch := deg_to_rad(camera_pitch)
    var flat := Vector3(camera_side, 0, -1).normalized() * cos(pitch)
    var eye := centre + (flat + Vector3.UP * sin(pitch)) * camera_distance
    camera.transform = Transform3D.IDENTITY.looking_at(centre - eye, Vector3.UP).translated(eye)
    add_child(camera)


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
