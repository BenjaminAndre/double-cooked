class_name DrainingBar
extends ProgressBar
## A plain bar that empties: patience left, calm left before a riot. Colour tells the urgency.

const CALM := Color(0.45, 0.9, 0.45)
const WORRY := Color(1.0, 0.85, 0.3)
const DANGER := Color(1.0, 0.3, 0.2)

var _fill := StyleBoxFlat.new()


func _init(width: float, height: float) -> void:
    custom_minimum_size = Vector2(width, height)
    show_percentage = false
    max_value = 1.0
    step = 0.0
    var back := StyleBoxFlat.new()
    back.bg_color = Color(0, 0, 0, 0.6)
    back.set_corner_radius_all(3)
    _fill.set_corner_radius_all(3)
    add_theme_stylebox_override("background", back)
    add_theme_stylebox_override("fill", _fill)


## fraction: 1 full, 0 empty. Green above half, yellow above a quarter, red below.
func show_fraction(fraction: float) -> void:
    value = clampf(fraction, 0.0, 1.0)
    _fill.bg_color = CALM if value > 0.5 else WORRY if value > 0.25 else DANGER
