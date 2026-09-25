class_name SimLevel
extends RefCounted
## The kitchen as plain data: nodes, their links and their stations.
## Built from a scene's Anchor graph by LevelReader, or by hand in tests.

enum Direction { UP, DOWN, LEFT, RIGHT }

const NONE := -1

var positions: Array[Vector3] = []
## links[node][direction] is the neighbouring node, or NONE.
var links: Array[PackedInt32Array] = []
## Station kind at each node, &"" when there is none (see Interactible.kind).
var stations: Array[StringName] = []
## Anchor names, to find nodes from tests and debug output.
var names: PackedStringArray = []


func add_node(position: Vector3, station: StringName = &"", node_name: String = "") -> int:
    positions.append(position)
    links.append(PackedInt32Array([NONE, NONE, NONE, NONE]))
    stations.append(station)
    names.append(node_name)
    return positions.size() - 1


func link(from: int, direction: Direction, to: int) -> void:
    var node_links := links[from]
    node_links[direction] = to
    links[from] = node_links


func neighbour(node: int, direction: Direction) -> int:
    return links[node][direction]


func find(node_name: String) -> int:
    return names.find(node_name)
