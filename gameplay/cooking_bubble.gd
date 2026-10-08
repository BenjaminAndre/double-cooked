class_name CookingBubble
extends Control
## Over a fryer, on screen so nothing in the kitchen hides it (the artist's ConceptBoard02): a
## cream bubble with what is in the oil and the artist's cooking bar, yellow while undercooked,
## green when ready, red up to the fire, with a cursor for the progress. In its top-right
## corner, the siren blinks in the last second of the green, then the warning in the red. A
## batch waiting on CUISSON 1 shows its portions left instead of the bar. The key hint of a player
## standing at the fryer goes at the bottom (show_hints), rather than over their head, where the
## bubble would hide it.

const PICTURE_SIZE := 30
const BAR_SIZE := Vector2(76, 9)
const KNOB_SIZE := Vector2(6, 15)
## Where the bands of CookedSlider.png end, as fractions of its width: yellow, then green; red
## runs to the end. The cursor moves through each band at its own pace, so it enters the green
## exactly when the food is ready, whatever the item.
const READY_FROM := 0.268
const READY_UNTIL := 0.744
const ALERT_SIZE := 24
## Between two bubbles pushed apart, in pixels.
const GAP := 4.0
## Room inside the frame: its border is thick, and its tail takes the bottom.
const PADDING := Vector4(12, 8, 12, 20)
const BLINK_MS := 250
## How far above the station the bubble's tail points, in metres.
const HEIGHT := 1.1
## Over the key hints, hearts and customers' tickets (canvas layer 1), so the hint of a player
## standing at a fryer never hides its bar; under the station menus (MenuBubble.CANVAS_LAYER).
const CANVAS_LAYER := 2

enum Alert { NONE, ALERT, WARNING }

var _panel: PanelContainer
var _picture: TextureRect
var _count: Label
var _bar: Control
var _knob: TextureRect
var _alert: TextureRect
var _alert_kind := Alert.NONE
var _hints: PlayerPanel
var _kind := &""


func _init() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    visible = false
    var style := ArtUi.bubble_down().duplicate() as StyleBoxTexture
    style.content_margin_left = PADDING.x
    style.content_margin_top = PADDING.y
    style.content_margin_right = PADDING.z
    style.content_margin_bottom = PADDING.w
    _panel = ArtUi.panel(style)
    add_child(_panel)
    var column := VBoxContainer.new()
    column.alignment = BoxContainer.ALIGNMENT_CENTER
    column.add_theme_constant_override("separation", 2)
    _panel.add_child(column)
    var row := HBoxContainer.new()
    row.alignment = BoxContainer.ALIGNMENT_CENTER
    column.add_child(row)
    _picture = ArtUi.picture(null, PICTURE_SIZE)
    row.add_child(_picture)
    _count = Label.new()
    _count.add_theme_font_size_override("font_size", 22)
    _count.add_theme_color_override("font_color", ArtUi.INK)
    row.add_child(_count)
    _bar = Control.new()
    _bar.custom_minimum_size = BAR_SIZE + Vector2(0, KNOB_SIZE.y - BAR_SIZE.y)
    column.add_child(_bar)
    var slider := TextureRect.new()
    slider.texture = load("res://art/textures/CookedSlider.png")
    slider.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    slider.stretch_mode = TextureRect.STRETCH_SCALE
    slider.size = BAR_SIZE
    slider.position.y = (KNOB_SIZE.y - BAR_SIZE.y) / 2
    _bar.add_child(slider)
    _knob = TextureRect.new()
    _knob.texture = ArtUi.texture("MoodSlider02")
    _knob.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    _knob.stretch_mode = TextureRect.STRETCH_SCALE
    _knob.size = KNOB_SIZE
    _bar.add_child(_knob)
    _hints = PlayerPanel.new()
    _hints.art_style = true
    _hints.compact = true
    column.add_child(_hints)
    _alert = TextureRect.new()
    _alert.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    _alert.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    _alert.size = Vector2.ONE * ALERT_SIZE
    _alert.visible = false
    add_child(_alert)


## Something in the oil: cook against its window (Fryer.window) and the tick it catches fire.
func show_cooking(item_kind: StringName, cook: int, window: Vector2i, fire: int) -> void:
    _show_item(item_kind)
    _count.visible = false
    _bar.visible = true
    _knob.position.x = progress(cook, window, fire) * BAR_SIZE.x - KNOB_SIZE.x / 2
    _show_alert(alert_for(cook, window))


## A batch waiting on CUISSON 1: its portions left.
func show_waiting(item_kind: StringName, portions: int) -> void:
    _show_item(item_kind)
    _count.visible = true
    _count.text = "×%d" % portions
    _bar.visible = false
    _show_alert(Alert.NONE)


func hide_bubble() -> void:
    visible = false


## rows: [key name, verb] pairs of the player standing at the fryer, [] for none.
func show_hints(rows: Array) -> void:
    _hints.show_hints(rows)


## Where the cursor is on the bar, from 0 to 1, for cook ticks into a window ending in a fire.
static func progress(cook: int, window: Vector2i, fire: int) -> float:
    if cook <= window.x:
        return READY_FROM * cook / maxf(window.x, 1.0)
    if cook <= window.y:
        return lerpf(READY_FROM, READY_UNTIL, float(cook - window.x) / maxf(window.y - window.x, 1.0))
    return lerpf(READY_UNTIL, 1.0, minf(float(cook - window.y) / maxf(fire - window.y, 1.0), 1.0))


## The siren in the last second of the green, the warning once in the red.
static func alert_for(cook: int, window: Vector2i) -> Alert:
    if cook > window.y:
        return Alert.WARNING
    if cook >= window.y - Simulation.TICK_RATE and cook >= window.x:
        return Alert.ALERT
    return Alert.NONE


## Pushes the bubbles shown side by side apart, left to right, so none hides another. They
## stay at their height; each keeps its place unless the one before it is in the way.
static func separate(bubbles: Array) -> void:
    var shown := bubbles.filter(func(bubble: CookingBubble) -> bool: return bubble.visible)
    shown.sort_custom(func(a: CookingBubble, b: CookingBubble) -> bool: return a.position.x < b.position.x)
    for index in range(1, shown.size()):
        var before: CookingBubble = shown[index - 1]
        var bubble: CookingBubble = shown[index]
        var mine := Rect2(bubble.position, bubble._panel.size)
        var theirs := Rect2(before.position, before._panel.size)
        if mine.intersects(theirs):
            bubble.position.x = theirs.end.x + GAP


## Puts the bubble's tail over this point of the world, kept on screen.
func place_over(at: Vector3, camera: Camera3D) -> void:
    if not visible or not camera:
        return
    var panel_size := _panel.get_combined_minimum_size()
    _panel.size = panel_size
    var tail := camera.unproject_position(at + Vector3.UP * HEIGHT)
    var corner := tail - Vector2(panel_size.x - ArtUi.BUBBLE_TAIL_FROM_RIGHT, panel_size.y)
    var screen := get_viewport_rect().size
    position = corner.clamp(Vector2.ONE * PlayerPanel.MARGIN,
            (screen - panel_size - Vector2.ONE * PlayerPanel.MARGIN).max(Vector2.ZERO))
    _alert.position = Vector2(panel_size.x - ALERT_SIZE * 0.6, -ALERT_SIZE * 0.4)


func _show_item(item_kind: StringName) -> void:
    visible = true
    if item_kind != _kind:
        _kind = item_kind
        _picture.texture = ItemIcons.picture(item_kind)
        _picture.modulate = ItemIcons.tint(item_kind)


func _show_alert(alert: Alert) -> void:
    if alert != _alert_kind:
        _alert_kind = alert
        if alert != Alert.NONE:
            _alert.texture = ArtUi.texture("Alert" if alert == Alert.ALERT else "Warning")
    # Both blink.
    _alert.visible = alert != Alert.NONE and (Time.get_ticks_msec() / BLINK_MS) % 2 == 0
