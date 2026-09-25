class_name SimLevel
extends RefCounted
## The kitchen as plain data: nodes, their links, and the stations they give access to.
## Built from a scene's Anchor graph by LevelReader, or by hand in tests.
## Several nodes can share one station (the demo's CUISSON 1 is reachable from two nodes).

enum Direction { UP, DOWN, LEFT, RIGHT }

const NONE := -1

var positions: Array[Vector3] = []
## links[node][direction] is the neighbouring node, or NONE.
var links: Array[PackedInt32Array] = []
## Station reachable from each node, or NONE.
var node_stations := PackedInt32Array()
## Anchor names, to find nodes from tests and debug output.
var names := PackedStringArray()
## Kind of each station (see Interactible.kind).
var station_kinds: Array[StringName] = []
var station_names := PackedStringArray()


func add_station(kind: StringName, station_name: String = "") -> int:
    station_kinds.append(kind)
    station_names.append(station_name)
    return station_kinds.size() - 1


func add_node(position: Vector3, station: int = NONE, node_name: String = "") -> int:
    positions.append(position)
    links.append(PackedInt32Array([NONE, NONE, NONE, NONE]))
    node_stations.append(station)
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


## Kind of the station reachable from node, &"" when there is none.
func station_kind_at(node: int) -> StringName:
    var station := node_stations[node]
    return station_kinds[station] if station != NONE else &""
