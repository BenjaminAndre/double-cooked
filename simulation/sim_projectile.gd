class_name SimProjectile
extends RefCounted
## A can in the air (GDD §8): a beer a player throws to a customer, or an empty can an angry
## customer throws at a player. It flies a gravity arc from `from` to `to` in `duration` ticks,
## and what it hits is decided when it lands.

## A beer for a customer, caught by whoever stands where it lands.
const BEER := &"beer"
## An empty can at a player: whoever stands near the landing spot loses a heart.
const CAN := &"can"
## How high the arc rises above the straight line, per unit of distance, plus a minimum.
const ARC_PER_UNIT := 0.25
const ARC_MIN := 0.6

var kind: StringName
var from: Vector3
var to: Vector3
var start: int
var duration: int
## The throwing player's slot, or -1 for a customer.
var by := -1


func _init(p_kind: StringName, p_from: Vector3, p_to: Vector3, p_start: int, p_duration: int) -> void:
    kind = p_kind
    from = p_from
    to = p_to
    start = p_start
    duration = p_duration


func lands_at() -> int:
    return start + duration


## Where the can is at a (fractional) tick: straight line plus a parabola, like a real throw.
func position_at(tick: float) -> Vector3:
    var t := clampf((tick - start) / duration, 0.0, 1.0)
    var height := ARC_MIN + ARC_PER_UNIT * from.distance_to(to)
    return from.lerp(to, t) + Vector3.UP * (4.0 * height * t * (1.0 - t))


func fingerprint() -> Array:
    return [kind, from, to, start, duration, by]
