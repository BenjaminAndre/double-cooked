class_name GridRoom
extends Node3D
## A room built in code from a grid layout, instead of placing every Anchor and station by
## hand: first the lobby (GDD §4.1), later kitchens sized for the player count.
##
## layout holds one string per row, the top row first (the far side, seen from the camera);
## each cell is a station kind, "." for bare floor, or "@" for bare floor where players start.
## Top-row stations stand behind their cell, bottom-row ones in front of it; a "pret" cell is a
## tile on the floor. Columns run to the right of the screen.

const ANCHOR_SCENE := preload("res://gameplay/anchor.tscn")
const FLOOR := preload("res://assets/kenney_prototype-kit/Models/GLB format/floor-small-square.glb")
const SPACING := 1.0
## Station boxes stand this far from their cell, towards the room's edge.
const STATION_OFFSET := 0.8
const LABELS := {
    &"peinture": "PEINTURE",
    &"casquette": "CASQUETTE",
    &"telephone": "TÉLÉPHONE",
    &"porte": "PORTE",
    &"pret": "PRÊT",
}
const COLORS := {
    &"peinture": Color(0.85, 0.35, 0.6),
    &"casquette": Color(0.35, 0.55, 0.85),
    &"telephone": Color(0.3, 0.3, 0.35),
    &"porte": Color(0.55, 0.35, 0.2),
    &"pret": Color(0.3, 0.8, 0.35),
}
## Seen like the kitchen: the same camera angle, from this offset to the room's centre.
const CAMERA_OFFSET := Vector3(1.0, 5.07, -3.2)
const CAMERA_ZOOM_OUT := 1.2
const CAMERA_BASIS := Basis(Vector3(-0.963453, 7.188714e-08, -0.26787755),
        Vector3(-0.22027381, 0.56906426, 0.79224074), Vector3(0.15243961, 0.82229304, -0.54826665))

@export var layout := PackedStringArray()

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
        var line := []
        for column in cells.size():
            var cell := StringName(cells[column])
            var anchor: Anchor = ANCHOR_SCENE.instantiate()
            anchor.name = "Cell%d_%d" % [row, column]
            # Right on screen is -x, the top row is +z (see the kitchen's camera).
            anchor.position = Vector3(-column, 0, -row) * SPACING
            _anchors.add_child(anchor)
            var floor_tile: Node3D = FLOOR.instantiate()
            floor_tile.position = anchor.position
            add_child(floor_tile)
            if cell == &"@":
                _spawns.append(anchor.name)
            elif cell != &".":
                var side := 1.0 if row == 0 else -1.0 if row == layout.size() - 1 else 0.0
                anchor.interactible = _station(stations, cell, anchor.position, side)
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
    camera.fov = 45.0
    var width: int = grid[0].size() if not grid.is_empty() else 1
    # The top-row stations stand behind the grid: frame them too, from a little further back.
    var centre := Vector3(-(width - 1) / 2.0, 0, -(grid.size() - 1) / 2.0 + STATION_OFFSET / 2) * SPACING
    camera.transform = Transform3D(CAMERA_BASIS, centre + CAMERA_OFFSET * CAMERA_ZOOM_OUT)
    add_child(camera)


## side: 1 behind the cell (top row), -1 in front of it (bottom row), 0 on the cell itself.
func _station(parent: Node3D, kind: StringName, at: Vector3, side: float) -> Interactible:
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
        station.position = at + Vector3(0, 0, side * STATION_OFFSET)
        var tall := kind == &"porte"
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
