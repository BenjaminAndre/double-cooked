class_name UnlitArt
extends Node3D
## The artist's models are drawn unlit: everything is in their textures, with no real light
## (docs/art/Readme_Settings.txt). This node turns the materials of everything under it
## unshaded when it enters the tree; UnlitArt.apply() does it for models added later.

## Material -> its unshaded copy, so models sharing a material keep sharing one.
static var _unlit := {}


func _ready() -> void:
    apply(self)


static func apply(node: Node) -> void:
    for mesh: MeshInstance3D in node.find_children("*", "MeshInstance3D", true, false):
        if not mesh.mesh:
            continue
        for surface in mesh.mesh.get_surface_count():
            var material := mesh.get_active_material(surface) as BaseMaterial3D
            if material and material.shading_mode != BaseMaterial3D.SHADING_MODE_UNSHADED:
                mesh.set_surface_override_material(surface, _unshaded(material))


static func _unshaded(material: BaseMaterial3D) -> BaseMaterial3D:
    if not _unlit.has(material):
        var copy := material.duplicate() as BaseMaterial3D
        copy.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
        _unlit[material] = copy
    return _unlit[material]
