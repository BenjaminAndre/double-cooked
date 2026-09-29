class_name MoodBar
extends Control
## The room mood as the artist's bar (GDD §6): the angry face on the left, the happy one on the
## right, and a cursor that slides left as the mood worsens. It reads without a label.

const WIDTH := 360.0
## Where the cursor runs, as fractions of the bar's width: from calm (right) to riot (left).
const CALM_AT := 0.83
const RIOT_AT := 0.17

## 0 calm to 1 riot.
var mood := 0.0:
    set(value):
        mood = clampf(value, 0.0, 1.0)
        _place_cursor()

var _bar: TextureRect
var _cursor: TextureRect


func _init() -> void:
    var bar_texture := ArtUi.texture("MoodSlider01")
    var height := WIDTH * bar_texture.get_height() / bar_texture.get_width()
    custom_minimum_size = Vector2(WIDTH, height)
    _bar = ArtUi.picture(bar_texture, 0)
    _bar.custom_minimum_size = custom_minimum_size
    add_child(_bar)
    var cursor_texture := ArtUi.texture("MoodSlider02")
    _cursor = ArtUi.picture(cursor_texture, 0)
    var cursor_height := height * 0.78
    _cursor.custom_minimum_size = Vector2(cursor_height * cursor_texture.get_width() / cursor_texture.get_height(), cursor_height)
    _cursor.size = _cursor.custom_minimum_size
    add_child(_cursor)
    _place_cursor()


func _place_cursor() -> void:
    if not _cursor:
        return
    var x := lerpf(CALM_AT, RIOT_AT, mood) * WIDTH
    _cursor.position = Vector2(x - _cursor.size.x / 2, (custom_minimum_size.y - _cursor.size.y) / 2)
