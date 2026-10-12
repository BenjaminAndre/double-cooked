class_name SimPigeon
extends RefCounted
## A pigeon in the kitchen (GDD §8): it flies in through the door to a station, then pecks at the
## fries waiting on CUISSON 1 and flies off with a portion, or just squats the station, blocking
## it, until a player shoos it (or shoots it, see the BB gun).

## Which pigeon of the night it is, for its random stream and for the display.
var id := 0
## The station it lands on (an index into Simulation.stations).
var station := 0
## Ticks before it lands; then ticks before it flies off with a portion (when it pecks).
var flying := 0
var peck := 0


func landed() -> bool:
    return flying == 0


func fingerprint() -> Array:
    return [id, station, flying, peck]
