class_name UiPanel
extends RefCounted
## Rounded screen-space panels, so text always sits on a background it can be read on.

## Dark background for tickets, hints and menu options.
const DARK := Color(0, 0, 0, 0.75)
## A selected menu option: bright, so it stands out at a glance.
const SELECTED := Color(1.0, 0.82, 0.2)
## A key cap, as in "Espace".
const KEY := Color(0.92, 0.92, 0.92)


static func make(color: Color, margin: float, radius := 4) -> PanelContainer:
    var panel := PanelContainer.new()
    set_color(panel, color, margin, radius)
    return panel


## Restyles a panel from make(), e.g. when a menu option gets selected.
static func set_color(panel: PanelContainer, color: Color, margin: float, radius := 4) -> void:
    var style := StyleBoxFlat.new()
    style.bg_color = color
    style.set_content_margin_all(margin)
    style.set_corner_radius_all(radius)
    panel.add_theme_stylebox_override("panel", style)


static func label(text: String, size: int, color := Color.WHITE) -> Label:
    var result := Label.new()
    result.text = text
    result.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    result.add_theme_font_size_override("font_size", size)
    result.add_theme_color_override("font_color", color)
    return result
