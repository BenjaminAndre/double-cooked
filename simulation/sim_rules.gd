class_name SimRules
extends RefCounted
## The numbers of a night, to tune by playing (GDD §11). Tests shrink them for short scenarios.
## Durations are in ticks (Simulation.TICK_RATE per second).

const SECOND := Simulation.TICK_RATE

## 18:00 to 04:00 in this many ticks.
var night_ticks := 7 * 60 * SECOND
## The night's intensity, from 0 (calm) to 1 (mad), follows the clock: calm until calm_until
## (23:00), rising until mad_from (01:00), flat out after (GDD §4). Fractions of the night.
var calm_until := 0.5
var mad_from := 0.7

## Time between two customers, for one player; more players make it shorter.
var arrival_min := 12 * SECOND
var arrival_max := 22 * SECOND
## The arrival delay is multiplied by this at intensity 0, down to mad_arrival_factor at 1.
var calm_arrival_factor := 1.5
var mad_arrival_factor := 0.45
var first_arrival := 3 * SECOND
var max_line := 6
## How many customers, from the front of the line, show their order (GDD §6.2). One per stage of
## the fries (first fry, second fry, ready), so players can start the next basket in time.
var visible_orders := 3
## Weights of what a customer orders: fries, a meat, a drink (GDD §6.2).
var order_categories := PackedFloat32Array([0.45, 0.35, 0.2])

## A customer walks out when this runs out. The front of the line drains it much faster.
var patience := 4 * 45 * SECOND
var front_drain := 4
var back_drain := 1
## A beer that wasn't ordered gives back this much patience (a quarter).
var beer_patience := 45 * SECOND

## The mood meter goes from 0 (calme) to riot, which ends the night.
var riot := 1000
var mood_served := -50
## A customer served the wrong thing, or something badly done, leaves angry.
var mood_angry := 120
var mood_walk_out := 150
## The mood creeps up on its own: +1 every this many ticks, from intensity 0 to 1.
var calm_drift_every := 3 * SECOND
var mad_drift_every := 12
## +1 per customer waiting behind the front one, every this many ticks.
var line_pressure_every := 2 * SECOND

## A basket left in the oil this long past the end of its window starts a grease fire (GDD §8).
var fire_margin := 10 * SECOND
## Standing on a burning station's node costs a heart this often.
var fire_damage_every := 2 * SECOND
## A fire left burning this long spreads to a neighbouring station.
var fire_spread_after := 10 * SECOND
## Stations fire never reaches, so the crew can always fight back.
var fireproof: Array[StringName] = [&"extincteur"]
## A knocked-out player crawls one node in this many ticks.
var crawl_ticks := 2 * SECOND
## Hearts of a player a teammate gets back up.
var revive_health := 1
## A bumped player is stunned this long: no moving, no acting (GDD §5.3).
var bump_stun := 15

## Throwing a beer (GDD §8): hold interact this long with a beer in hand to aim instead of
## using the station; release to throw.
var aim_hold := 8
var beer_flight := 24
## Angry customers' cans: flight time (long enough to see the arc and dodge) and how close to
## the landing spot a player must be to get hit.
var can_flight := 45
var can_radius := 0.45
## Waiting customers throw at random once the mood is past can_mood (a fraction of riot):
## at most one can every can_every ticks from the whole line, at a full riot.
var can_mood := 0.5
var can_every := 8 * SECOND


## 0 while calm, 1 once mad, for a tick of the night.
func intensity(tick: int) -> float:
    var progress := float(tick) / night_ticks
    return clampf((progress - calm_until) / (mad_from - calm_until), 0.0, 1.0)
