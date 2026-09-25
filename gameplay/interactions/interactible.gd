class_name Interactible
extends Node3D
## A station the player interacts with from an Anchor. What it does is a Simulation rule
## keyed by kind; this node only shows the station's state, such as the fryer gauges.

const FRYERS: Array[StringName] = [&"cuisson_1", &"cuisson_2"]
const GAUGE_CELLS := 10
## The gauge runs a bit past the end of the window, so "too late" stays visible.
const GAUGE_OVERSHOOT := 1.4
const TOO_EARLY := Color(0.8, 0.8, 0.8)
const JUST_RIGHT := Color(0.3, 1.0, 0.3)
const TOO_LATE := Color(1.0, 0.3, 0.2)

## Station kind: cuisson_1, cuisson_2, sauces, poubelle, soins, caisse, extincteur, boissons,
## pain, viandes. Empty means the station does nothing yet.
@export var kind : StringName = &""

var _state_label: Label3D


## Shows the fryer gauge: grey while too early, green in the window, red once too late.
func show_station(station: SimStation) -> void:
    if not kind in FRYERS:
        return
    if not _state_label:
        _state_label = Label3D.new()
        _state_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
        _state_label.position = Vector3(0, 1.3, 0)
        _state_label.font_size = 40
        _state_label.outline_size = 10
        add_child(_state_label)
    _state_label.visible = station.basket != null
    if not station.basket:
        return
    if station.frying:
        var first := kind == &"cuisson_1"
        var low := Fryer.FIRST_FRY_MIN if first else Fryer.SECOND_FRY_MIN
        var high := Fryer.FIRST_FRY_MAX if first else Fryer.SECOND_FRY_MAX
        _state_label.text = "CUISSON\n" + _bar(station.cook / (high * GAUGE_OVERSHOOT))
        _state_label.modulate = TOO_EARLY if station.cook < low \
                else JUST_RIGHT if station.cook <= high else TOO_LATE
    else:
        var rest := station.basket.rest
        _state_label.text = "REPOS\n" + _bar(float(rest) / Fryer.REST_NEEDED)
        _state_label.modulate = JUST_RIGHT if rest >= Fryer.REST_NEEDED else TOO_EARLY


func _bar(fraction: float) -> String:
    var filled := clampi(roundi(fraction * GAUGE_CELLS), 0, GAUGE_CELLS)
    return "■".repeat(filled) + "□".repeat(GAUGE_CELLS - filled)
