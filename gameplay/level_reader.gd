class_name LevelReader
## Turns the Anchor nodes of a scene into a SimLevel, so the simulation never touches nodes.


## Reads the Anchor children of anchors_root, in scene order. Scene order is the same on
## every machine, so node indices match between host and clients.
static func read(anchors_root: Node) -> SimLevel:
    var level := SimLevel.new()
    var anchors: Array[Anchor] = []
    for child in anchors_root.get_children():
        if child is Anchor:
            anchors.append(child)
    for anchor in anchors:
        var station: StringName = anchor.interactible.kind if anchor.interactible else &""
        level.add_node(_world_position(anchor), station, anchor.name)
    for index in anchors.size():
        var anchor := anchors[index]
        var neighbours := [anchor.up, anchor.down, anchor.left, anchor.right]
        for direction in neighbours.size():
            if neighbours[direction]:
                level.link(index, direction, anchors.find(neighbours[direction]))
    return level


## Like global_position, but also works on a scene that isn't in the tree (tests).
static func _world_position(node: Node3D) -> Vector3:
    var transform := Transform3D.IDENTITY
    var current: Node = node
    while current is Node3D:
        transform = (current as Node3D).transform * transform
        current = current.get_parent()
    return transform.origin
