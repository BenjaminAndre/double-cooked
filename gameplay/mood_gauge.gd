class_name MoodGauge
extends Control
## The room mood as a half-moon dial: green (calme) on the left through yellow and orange to
## red (émeute) on the right, with a needle that swings as the mood changes (GDD §6).

const COLORS: Array[Color] = [Color(0.4, 0.85, 0.4), Color(1.0, 0.85, 0.25), Color(1.0, 0.55, 0.2),
        Color(0.95, 0.2, 0.15)]
const THICKNESS := 14.0
## How fast the needle catches up with the mood, per second.
const NEEDLE_SPEED := 4.0

## 0 calm, 1 riot.
var mood := 0.0
var _shown := 0.0


func _init() -> void:
    custom_minimum_size = Vector2(150, 84)


func _process(delta: float) -> void:
    _shown = lerpf(_shown, mood, minf(1.0, NEEDLE_SPEED * delta))
    queue_redraw()


func _draw() -> void:
    var centre := Vector2(size.x / 2, size.y - 6)
    var radius := minf(size.x / 2, size.y) - THICKNESS
    var band := PI / COLORS.size()
    for index in COLORS.size():
        var from := PI + index * band
        draw_arc(centre, radius, from, from + band, 16, COLORS[index], THICKNESS, true)
    var angle := PI + clampf(_shown, 0.0, 1.0) * PI
    var tip := centre + Vector2.from_angle(angle) * (radius + THICKNESS / 2)
    draw_line(centre, tip, Color.BLACK, 6.0, true)
    draw_line(centre, tip, Color.WHITE, 3.0, true)
    draw_circle(centre, 7.0, Color.WHITE)
    draw_circle(centre, 4.0, Color.BLACK)
