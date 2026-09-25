class_name SimRules
extends RefCounted
## The numbers of a night, to tune by playing (GDD §11). Tests shrink them for short scenarios.
## Durations are in ticks (Simulation.TICK_RATE per second).

const SECOND := Simulation.TICK_RATE

## 18:00 to 04:00 in this many ticks.
var night_ticks := 7 * 60 * SECOND
## Where the Soirée ends and the Rush ends, as fractions of the night (GDD §4).
var rush_start := 0.4
var after_start := 0.7

## Time between two customers, for one player; more players make it shorter.
var arrival_min := 12 * SECOND
var arrival_max := 22 * SECOND
## Arrivals come faster in the Rush.
var rush_arrival_factor := 0.6
var first_arrival := 3 * SECOND
var max_line := 6
## How many customers, from the front of the line, show their order (GDD §6.2). One per stage of
## the fries (first fry, second fry, ready), so players can start the next basket in time.
var visible_orders := 3
## Weights of one-, two- and three-line orders (GDD §6.2).
var order_sizes := PackedFloat32Array([0.5, 0.35, 0.15])

## A customer walks out when this runs out. The front of the line drains it much faster.
var patience := 4 * 45 * SECOND
var front_drain := 4
var back_drain := 1

## The mood meter goes from 0 (calme) to riot, which ends the night.
var riot := 1000
var mood_good_item := -50
var mood_bad_item := 20
var mood_walk_out := 150
## The mood creeps up on its own: +1 every this many ticks, in each phase.
var drift_every_soiree := 2 * SECOND
var drift_every_rush := SECOND
var drift_every_after := 15
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
