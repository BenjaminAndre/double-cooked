class_name SimRules
extends RefCounted
## The numbers of a night, to tune by playing (GDD §11). Tests shrink them for short scenarios.
## Durations are in ticks (Simulation.TICK_RATE per second).

const SECOND := Simulation.TICK_RATE

## 18:00 to 04:00 in this many ticks (just under 6 minutes). At 04:00 the door closes: no one
## comes in any more, and the night ends once the last customer has left (GDD §4).
var night_ticks := 350 * SECOND
## The lobby (GDD §4.1): the same rules for walking and station menus, but no customers,
## no clock, no hunger and no end.
var lobby := false
## Which night of a campaign this is (GDD §4.2), 0 for a single night. Each night after the
## first brings customers busier_per_night faster.
var night_number := 0
var busier_per_night := 0.05
## What customers can order tonight (Menu.FULL_MENU for a single night): dishes, sauces, drinks.
var menu: Array[StringName] = Menu.FULL_MENU.duplicate()
## The night's intensity, from 0 (calm) to 1 (mad), follows the clock: calm until calm_until
## (20:00), then rising steadily to its peak at mad_from (04:00) (GDD §4). Fractions of the night.
var calm_until := 0.2
var mad_from := 1.0

## Time between two customers, for one player; more players make it shorter. (Two thirds of
## the first values, 12 to 22 s: 50% more customers after a playtest found the nights empty.)
var arrival_min := 8 * SECOND
var arrival_max := 15 * SECOND
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
## The breads (burger, burger complet, mitraillette) take longer: their customers wait this
## much longer (the artist gives +4 s a step of an order).
var bread_patience := 1.3
## A beer that wasn't ordered gives back this much patience (15 s at the front of the line, the
## artist's figure), at most beer_gifts times; one more puts the customer to sleep beer_sleep ticks.
var beer_patience := 15 * 4 * SECOND
var beer_gifts := 2
var beer_sleep := 10 * SECOND

## The mood meter goes from 0 (calme) to riot, which ends the night.
var riot := 1000
var mood_served := -50
## A customer served the wrong thing, or something badly done, leaves angry.
var mood_angry := 120
## A wrong dish is refused: it stays in hand, and the customer loses this much patience (5 s at
## the front of the line, the artist's figure).
var wrong_delivery := 5 * 4 * SECOND
var mood_walk_out := 150
## +1 per customer waiting behind the front one, every this many ticks.
var line_pressure_every := 2 * SECOND

## A basket left in the oil this long past the end of its window starts a grease fire (GDD §8).
var fire_margin := 10 * SECOND
## Standing on a burning station's node costs a heart this often.
var fire_damage_every := 2 * SECOND
## A fire left burning this long spreads to a neighbouring station.
var fire_spread_after := 8 * SECOND
## The extinguisher sprays this long at a fire before it is out; then it goes back by itself.
var spray_ticks := 2 * SECOND
## Stations fire never reaches, so the crew can always fight back.
var fireproof: Array[StringName] = [&"extincteur"]
## A knocked-out player crawls one node in this many ticks, to a beer.
var crawl_ticks := 2 * SECOND
## A bumped player is stunned this long: no moving, no acting (GDD §5.3).
var bump_stun := 15
## Body mass index (GDD §5.1): everyone starts healthy, each thing eaten or drunk adds a point,
## and every moves_per_bmi nodes walked burns one. At knockout_bmi they collapse, undernourished.
var start_bmi := 21
var knockout_bmi := 16
var moves_per_bmi := 25
## Over start_bmi a player gets fatter by stages (the artist's fat01 to fat03 drawings), from
## fat_stages points over it, and walks at the stage's fat_speeds (theirs: 95%, 85%, 70%).
var fat_stages: Array[int] = [1, 3, 5]
var fat_speeds: Array[float] = [0.95, 0.85, 0.7]

## Beers in the FRIGO: it starts full and gets one back every fridge_restock ticks.
var fridge_beers := 5
var fridge_restock := 12 * SECOND

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


## Tonight's events (NightEvents, GDD §6.4), in their order: [when, as a fraction of the night,
## kind]. A campaign night has its day's (Campaign.events_for); a single night none so far.
var night_events: Array = []
## The fridge breakdown: no beer comes back to the FRIGO for this long.
var fridge_breakdown := 25 * SECOND
## The Diables Rouges' half-time: this many customers, one every rush_every ticks, each with this
## fraction of the usual patience (in a hurry, the artist's -20%).
var rush_customers := 6
var rush_every := 20 * SECOND / 6
var rush_patience := 0.8
## The AFSCA inspection: this long; then the room cheers up if no fire burnt meanwhile, and
## sours by a quarter of a riot if one did.
var inspection_ticks := 20 * SECOND
var mood_inspection_passed := -150
var mood_inspection_failed := 250


## The boss (GDD §6.3): one per night, at boss_at through the night (02:00). He cuts to the
## front of the line and orders boss_orders dishes one after the other, each with
## boss_patience_factor times the usual patience. 0 orders: no boss.
var boss_at := 0.8
var boss_orders := 3
var boss_patience_factor := 2
## Each missed order: this much worse mood, and a salvo of boss_cans cans at the crew.
var mood_boss_miss := 200
var boss_cans := 3
## All his orders served right: the room cheers up this much.
var mood_boss_served := -300
## While waiting he throws a can at a random player every boss_can_every ticks.
var boss_can_every := 6 * SECOND
## His drink ticket: ordered boss_drink_again ticks after the last one; it waits
## boss_drink_patience ticks, then the current order loses boss_drink_penalty patience.
var boss_drink_again := 8 * SECOND
var boss_drink_patience := 20 * SECOND
var boss_drink_penalty := 4 * 15 * SECOND


## 0 at a healthy weight or under, then 1 to 3: how fat a player with this BMI is.
func fat_stage(bmi: int) -> int:
    var stage := 0
    while stage < fat_stages.size() and bmi - start_bmi >= fat_stages[stage]:
        stage += 1
    return stage


## How fast a player with this BMI walks, 1 at a healthy weight; thinner isn't faster.
func walk_speed(bmi: int) -> float:
    var stage := fat_stage(bmi)
    return 1.0 if stage == 0 else fat_speeds[stage - 1]


## The tick the boss walks in.
func boss_tick() -> int:
    return int(night_ticks * boss_at)


## 0 while calm, 1 once mad, for a tick of the night.
func intensity(tick: int) -> float:
    var progress := float(tick) / night_ticks
    return clampf((progress - calm_until) / (mad_from - calm_until), 0.0, 1.0)
