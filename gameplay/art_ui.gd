class_name ArtUi
extends RefCounted
## The artist's UI frames as Godot styles and widgets (docs/ART_PLAN.md). Frames stretch by
## their middle, so corners and the bubble's tail keep their shape.

const PATH := "res://art/textures/UX_%s.png"
## Text on the cream frames.
const INK := Color(0.2, 0.13, 0.08)

static var _styles := {}


## A frame from the artist's UI as a stylebox. margins: left, top, right, bottom pixels that
## don't stretch; content: space between the frame and what it holds.
static func frame(name: String, margins: Vector4, content := 8.0) -> StyleBoxTexture:
    var key := "%s %s %s" % [name, margins, content]
    if not _styles.has(key):
        var style := StyleBoxTexture.new()
        style.texture = load(PATH % name)
        style.texture_margin_left = margins.x
        style.texture_margin_top = margins.y
        style.texture_margin_right = margins.z
        style.texture_margin_bottom = margins.w
        style.set_content_margin_all(content)
        _styles[key] = style
    return _styles[key]


## A customer's order: a speech bubble, its tail up towards them.
static func order_bubble() -> StyleBoxTexture:
    var style := frame("FrameOrder02", Vector4(16, 22, 30, 14), 8)
    style.content_margin_top = 14
    return style


## A menu option, and the selected one.
static func option() -> StyleBoxTexture:
    return frame("FrameItem01", Vector4(16, 16, 16, 16), 6)


static func selected_option() -> StyleBoxTexture:
    return frame("Selection01", Vector4(24, 24, 24, 24), 6)


## A key cap, as in "ESPACE".
static func key_cap() -> StyleBoxTexture:
    var style := frame("Button01", Vector4(16, 12, 16, 12), 4)
    style.content_margin_left = 10
    style.content_margin_right = 10
    return style


## A cream note, e.g. the end of the night.
static func notebook() -> StyleBoxTexture:
    var style := frame("Frame", Vector4(30, 40, 34, 40), 24)
    style.content_margin_top = 40
    return style


static func texture(name: String) -> Texture2D:
    return load(PATH % name)


## A panel with this style.
static func panel(style: StyleBox) -> PanelContainer:
    var result := PanelContainer.new()
    result.add_theme_stylebox_override("panel", style)
    return result


## A picture from the art, sized to side pixels, keeping its proportions.
static func picture(texture: Texture2D, side: float, tint := Color.WHITE) -> TextureRect:
    var rect := TextureRect.new()
    rect.texture = texture
    rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    rect.custom_minimum_size = Vector2.ONE * side
    rect.modulate = tint
    return rect
