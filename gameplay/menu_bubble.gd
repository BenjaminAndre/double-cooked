class_name MenuBubble
extends PanelContainer
## An open station menu, in a cream bubble over the station (as on the artist's concept): the
## options laid out around the first one, then the key that takes the selected one.

const BUBBLE_HEIGHT := 1.6
## Over everything in the kitchen (fryer bubbles are on 2), under the HUD (4).
const CANVAS_LAYER := 3

var content: PlayerPanel


func _init() -> void:
    add_theme_stylebox_override("panel", ArtUi.frame("FrameItem02", Vector4(20, 20, 20, 20), 12))
    content = PlayerPanel.new()
    content.art_style = true
    add_child(content)
    visible = false


## options: see PlayerPanel.show_menu; [] closes the bubble. key: the key that chooses.
func show_menu(options: Array, choice: int, disabled: Array, key: String) -> void:
    content.show_menu(options, choice, disabled)
    content.show_hints([[key, "choisir"]] if not options.is_empty() else [])
    if visible != not options.is_empty():
        visible = not options.is_empty()
    reset_size()


## Centres the bubble's bottom over this point of the world.
func place_over(at: Vector3, camera: Camera3D) -> void:
    if not visible or not camera:
        return
    var bottom := camera.unproject_position(at + Vector3.UP * BUBBLE_HEIGHT)
    var screen := get_viewport_rect().size
    var corner := bottom - Vector2(size.x / 2, size.y)
    position = corner.clamp(Vector2.ONE * PlayerPanel.MARGIN, (screen - size - Vector2.ONE * PlayerPanel.MARGIN).max(Vector2.ZERO))
