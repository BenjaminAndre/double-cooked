class_name UnlitArt
extends Node3D
## The artist's models are drawn unlit: everything is in their textures, with no real light
## (docs/art/Readme_SettingsV2.txt). This node turns the materials of everything under it
## unshaded when it enters the tree; UnlitArt.apply() does it for models added later. Their
## "_Glass" meshes (the counter's and the fridge door's) become see-through glass.
##
## The FBX files look for their atlas in Unity's "Textures" folder, ours is "textures": on a
## case-sensitive system (the Linux build) the import can come without it, so a material with
## no texture gets its atlas back here (GroundAtlas for the rooms, PropsAtlas for the rest).

const GLASS_TEXTURE := preload("res://art/textures/Glass_Opacity.png")
const PROPS_ATLAS := preload("res://art/textures/PropsAtlas_BC.png")
const GROUND_ATLAS := preload("res://art/textures/GroundAtlas_BC.png")
## Glass draws after the other see-through things; fire goes over it.
const GLASS_PRIORITY := 1

## Material -> its unshaded copy, so models sharing a material keep sharing one.
static var _unlit := {}
static var _glass: StandardMaterial3D


func _ready() -> void:
    apply(self)


static func apply(node: Node) -> void:
    for mesh: MeshInstance3D in node.find_children("*", "MeshInstance3D", true, false):
        if not mesh.mesh:
            continue
        if mesh.name.ends_with("_Glass"):
            mesh.material_override = glass()
            continue
        for surface in mesh.mesh.get_surface_count():
            var material := mesh.get_active_material(surface) as BaseMaterial3D
            if material and material.shading_mode != BaseMaterial3D.SHADING_MODE_UNSHADED:
                var atlas := GROUND_ATLAS if mesh.name.begins_with("DoubleCooked_Room") else PROPS_ATLAS
                mesh.set_surface_override_material(surface, _unshaded(material, atlas))


## The artist's glass: their texture's alpha, seen from both sides, casting nothing.
static func glass() -> StandardMaterial3D:
    if not _glass:
        _glass = StandardMaterial3D.new()
        _glass.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
        _glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
        _glass.cull_mode = BaseMaterial3D.CULL_DISABLED
        _glass.albedo_texture = GLASS_TEXTURE
        _glass.render_priority = GLASS_PRIORITY
    return _glass


static func _unshaded(material: BaseMaterial3D, atlas: Texture2D) -> BaseMaterial3D:
    if not _unlit.has(material):
        var copy := material.duplicate() as BaseMaterial3D
        copy.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
        if not copy.albedo_texture:
            copy.albedo_texture = atlas
        _unlit[material] = copy
    return _unlit[material]
