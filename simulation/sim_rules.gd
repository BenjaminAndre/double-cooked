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
## Chance that an order has two items instead of one.
var two_items_chance := 0.3

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
