class_name ArtBar
extends TextureProgressBar
## A patience bar in the artist's style: green, turning red once it runs low.

const LOW := 0.3
const MARGIN := 12


func _init(width: float, height: float) -> void:
    texture_under = ArtUi.texture("SliderEmpty")
    texture_progress = ArtUi.texture("SliderGreen")
    nine_patch_stretch = true
    stretch_margin_left = MARGIN
    stretch_margin_right = MARGIN
    stretch_margin_top = 4
    stretch_margin_bottom = 4
    custom_minimum_size = Vector2(width, height)
    max_value = 1.0
    step = 0.0


## fraction: 1 full, 0 empty.
func show_fraction(fraction: float) -> void:
    value = clampf(fraction, 0.0, 1.0)
    var low := value < LOW
    if low != get_meta(&"low", false):
        set_meta(&"low", low)
        texture_progress = ArtUi.texture("SliderRed" if low else "SliderGreen")
