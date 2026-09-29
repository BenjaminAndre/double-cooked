class_name Overhead
extends Control
## Over a player's head, on screen so nothing in the kitchen hides it: their hearts, a word when
## they are knocked out or starving, and what they hold as a speech bubble (an "infobulle")
## pointing down at them.

const HEART := preload("res://art/textures/UX_Life.png")
const HEART_EMPTY := preload("res://art/textures/UX_LifeEmpty.png")
const HEART_SIZE := 22
const ITEM_SIZE := 44
const SAUCE_SIZE := 30
const FONT := 18
const GAP := 2.0

var _hearts: HBoxContainer
var _status: Label
var _bubble: PanelContainer
var _item: TextureRect
var _sauce: TextureRect
var _count: Label
var _shown_item := []
var _shown_health := -1


func _init() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    _hearts = HBoxContainer.new()
    _hearts.add_theme_constant_override("separation", 0)
    for index in SimPlayer.MAX_HEALTH:
        _hearts.add_child(ArtUi.picture(HEART, HEART_SIZE))
    add_child(_hearts)
    _status = Label.new()
    _status.add_theme_font_size_override("font_size", FONT)
    _status.add_theme_constant_override("outline_size", 6)
    _status.add_theme_color_override("font_outline_color", Color.BLACK)
    add_child(_status)
    _bubble = ArtUi.panel(ArtUi.bubble_down())
    var row := HBoxContainer.new()
    row.alignment = BoxContainer.ALIGNMENT_CENTER
    row.add_theme_constant_override("separation", 2)
    _item = ArtUi.picture(null, ITEM_SIZE)
    _sauce = ArtUi.picture(null, SAUCE_SIZE)
    _count = Label.new()
    _count.add_theme_font_size_override("font_size", FONT)
    _count.add_theme_color_override("font_color", ArtUi.INK)
    _count.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    row.add_child(_item)
    row.add_child(_sauce)
    row.add_child(_count)
    _bubble.add_child(row)
    add_child(_bubble)
    _bubble.visible = false


## item: what the hand holds, null for nothing. status: e.g. "(K.O.)", "" for none.
func show_player(item: SimItem, health: int, status: String, status_color := Color.WHITE) -> void:
    if health != _shown_health:
        _shown_health = health
        for index in _hearts.get_child_count():
            (_hearts.get_child(index) as TextureRect).texture = HEART if index < health else HEART_EMPTY
    if _status.text != status:
        _status.text = status
        _status.reset_size()
    _status.add_theme_color_override("font_color", status_color)
    var shown := [item.kind, item.sauce, item.portions] if item else []
    if shown == _shown_item:
        return
    _shown_item = shown
    _bubble.visible = item != null
    if not item:
        return
    var picture := ItemIcons.picture(item.kind)
    _item.visible = picture != null
    _item.texture = picture
    _item.modulate = ItemIcons.tint(item.kind)
    var sauce := ItemIcons.picture(item.sauce) if item.sauce != &"" else null
    _sauce.visible = sauce != null
    _sauce.texture = sauce
    # Items the artist hasn't drawn yet show their name; batches their portions.
    if not picture:
        _count.text = ItemNames.of(item)
    elif item.portions > 1:
        _count.text = "×%d" % item.portions
    else:
        _count.text = ""
    _count.visible = _count.text != ""
    _bubble.reset_size()


## Stacks everything upwards from the top of the head, at this point of the screen.
func place(head: Vector2) -> void:
    var y := head.y
    _hearts.reset_size()
    y -= _hearts.size.y
    _hearts.position = Vector2(head.x - _hearts.size.x / 2, y)
    if _status.text != "":
        y -= _status.size.y
        _status.position = Vector2(head.x - _status.size.x / 2, y)
    if _bubble.visible:
        y -= _bubble.size.y + GAP
        # The tail's tip over the head.
        _bubble.position = Vector2(head.x - _bubble.size.x + ArtUi.BUBBLE_TAIL_FROM_RIGHT, y)


## The top of what is shown, on screen: where a local player's key hints go.
func top() -> float:
    if _bubble.visible:
        return _bubble.position.y
    if _status.text != "":
        return _status.position.y
    return _hearts.position.y
