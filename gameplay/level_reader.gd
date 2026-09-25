class_name LevelReader
## Turns the Anchor nodes of a scene into a SimLevel, so the simulation never touches nodes.


## Reads the Anchor children of anchors_root, in scene order. Scene order is the same on
## every machine, so node and station indices match between host and clients.
static func read(anchors_root: Node) -> SimLevel:
    var level := SimLevel.new()
    var anchors := _anchors(anchors_root)
    var station_nodes := stations(anchors_root)
    for station in station_nodes:
        level.add_station(station.kind, station.name)
    for anchor in anchors:
        var station := station_nodes.find(anchor.interactible) if anchor.interactible else SimLevel.NONE
        level.add_node(_world_position(anchor), station, anchor.name)
    for index in anchors.size():
        var anchor := anchors[index]
        var neighbours := [anchor.up, anchor.down, anchor.left, anchor.right]
        for direction in neighbours.size():
            if neighbours[direction]:
                level.link(index, direction, anchors.find(neighbours[direction]))
    return level


## The stations reachable from the anchors, each once, in the order read() numbers them.
static func stations(anchors_root: Node) -> Array[Interactible]:
    var found: Array[Interactible] = []
    for anchor in _anchors(anchors_root):
        if anchor.interactible and not anchor.interactible in found:
            found.append(anchor.interactible)
    return found


static func _anchors(anchors_root: Node) -> Array[Anchor]:
    var anchors: Array[Anchor] = []
    for child in anchors_root.get_children():
        if child is Anchor:
            anchors.append(child)
    return anchors


## Like global_position, but also works on a scene that isn't in the tree (tests).
static func _world_position(node: Node3D) -> Vector3:
    var transform := Transform3D.IDENTITY
    var current: Node = node
    while current is Node3D:
        transform = (current as Node3D).transform * transform
        current = current.get_parent()
    return transform.origin
