# Double Cooked — Game Design Document

> Status: draft, being designed with the user. **(proposal)** marks items not decided yet.
> Decided items have no marker. Open questions are listed at the end.

## 1. Pitch

A cramped Belgian fritkot on a busy night. One to four friends run the kitchen with nothing but the keyboard: fry the fries twice, stack mitraillettes and calm a crowd that gets drunker and ruder as the night goes on. Serve well and the room stays calm. Serve badly and cans start flying and the fryer catches fire. The goal is to **survive until closing time**.

Inspired by the interaction model of *An Average Day at the Cat Cafe*: keyboard navigation between stations, recipes learned from a menu board, impatient customers.

## 2. Pillars

Every feature is checked against these.

1. **Keyboard only.** Every action is a keypress: navigation between nodes plus a few action keys. No mouse, no aiming, and no menus during a night.
2. **The space is the enemy.** The kitchen is deliberately cramped. A node holds only one player, so players block each other and knock each other over. The chaos comes from the layout, not from extra rules.
3. **Calm the room or it turns on you.** Service quality changes the level of danger. That is the only economy: no money, no upgrades.
4. **Short, loud nights.** Players are expected to talk to each other outside the game (voice chat), so the game has no chat, pings or other communication tools. One night lasts about 6–8 minutes, with an instant rematch.

## 3. Core loop

Take an order at the CAISSE → prepare it across the stations → hand it over → the room mood goes down or up → hazards appear accordingly → deal with the hazards while repeating the loop. This runs until closing time or until the whole crew is down.

## 4. Session: one night

- One game is one night, with the clock compressed to about 6–8 minutes of real time.
- **(proposal)** The clock runs from 18:00 to 04:00, in three phases:
  - **Soirée** (18–22h): families and calm regulars; teaches the menu.
  - **Rush** (22–01h): the bar crowd; many orders at once.
  - **After** (01–04h): drunks and barakis; fewer orders, much more danger.
- **(proposal)** Variety comes from difficulty levels and random events, not from progression between nights.
- **End of night:** a win or loss ("closed at 04:00" or "crew down at 01:37") plus a short recap of fun stats: orders served, fires, bumps per player, who was knocked out most. Bragging material, with no economy behind it.

## 5. Players

- **1 to 4 players, in the same kitchen.** Solo is roomy and four players is packed; the layout does not change. The customer rate scales with the player count.

### 5.1 Health and knock-out
- Each player has 3 hearts (already implemented).
- At 0 hearts a player is **knocked out**. They lie on their node and **block it**, until a teammate gets them back up by interacting with them.
- The night is **lost when every player is knocked out at the same time**.
- The SOINS station restores hearts.
- **Solo play is supported.** A knocked-out player can **crawl** slowly toward SOINS to get back up alone. In solo this is the only way to recover, and the night is lost if the room riots first.
- **(proposal)** A revived player comes back with 1 heart. Crawling speed: one node every few seconds.

### 5.2 Movement
- Players move from node to node with the arrow keys, and moves can be queued (already implemented: `Anchor` graph, `future_path`).
- A node holds one player at a time.

### 5.3 Collisions (knocking)
- Knocking happens **through collisions only**, with no dedicated key.
- Moving into an occupied node bumps its occupant.
- The bumped player drops the item in their **non-focused hand** (see §5.4). If that hand is empty, they lose nothing. The item in the focused hand is always safe.
- **(proposal)** The player who bumps stops. A dropped drink or sauce leaves a spill. On a wet floor, the bumped player instead slides to the next node in the direction of the push.

### 5.4 Hands and interaction
- Each player has two hands. **Q and F choose the focused hand** (left or right). The focused hand is the one the next interaction changes.
- **Space interacts** with the station at the player's node, and the station **transforms or fills the focused hand directly**. Items are never put down on the counter first; there are no intermediate steps.
  - Example: press Q to focus the left hand, which holds a bread, then interact at VIANDES. The left hand now holds a pain-saucisse.
- Station rules:
  - With an empty focused hand, interacting at a supply station (PAIN, BOISSONS, EXTINCTEUR…) takes the base item.
  - Interacting at the POUBELLE empties the focused hand.
  - Serving means interacting at the CAISSE with an ordered item in the focused hand (see §6.2).
  - Fryers keep their own state (§7.1).
- Tactical depth: you choose which item you protect (focused) and which one you risk (non-focused) whenever you move through a crowd.

## 6. The room mood (ambiance)

- The whole fritkot shares **one mood meter**.
- Orders served on time lower it. Late, wrong or abandoned orders raise it.
- A higher mood means more frequent and nastier hazards.
- **(proposal)** Mood levels: *Calme → Tendu → Chaud → Émeute*. The meter also drifts upward on its own as the night goes on, so the After phase is dangerous even for a good crew.

### 6.1 Customer types
- Customers differ in two values:
  - **baseline misbehaviour:** how likely they are to cause trouble even when the room is calm;
  - **mood sensitivity:** how much the room mood amplifies their behaviour.
- **Barakis** have a high baseline and high sensitivity. A baraki can throw a can even when the room is calm, and a room that turns *Chaud* with barakis present gets bad very quickly. (Visuals to come later.)
- **(proposal)** Other types: regulars (low/low), students (low baseline, high sensitivity) and families (low/low, but impatient).

### 6.2 Queue and orders
- Customers wait in a single line at the counter.
- An order has **one or two items at most** (e.g. frites + bière, or two mitraillettes).
- **Only the customer at the front of the line shows a ticket**: their order plus a patience bar, above their head. The rest of the line is visible, but their orders stay unknown until they reach the front.
- **Everyone in the line loses patience**, slowly, and the customer at the front loses it much faster. A long line raises the mood on its own, even if nobody is served badly.
- **Items are handed over one at a time.** Each interaction at the CAISSE delivers the focused item, and the ticket ticks it off. A two-item order can be served with both hands in a row (switching focus with Q/F), or the second item can be brought later.

## 7. Cooking

### 7.1 Double cuisson (signature mechanic)
Fries go through a first fry at CUISSON 1, then rest, then a second fry at CUISSON 2. Every step is one interaction with the focused hand.

**CUISSON 1: first fry**
1. **Put in.** Interacting with an empty CUISSON 1 **spawns a basket of raw fries** straight into the oil, and the cooking timer starts. No supply station is needed.
2. **Lift.** Interacting again lifts the basket. What happens depends on the timing:
   - **Too early:** you get **cold fries** in your hand, fit only for the bin.
   - **Just in time:** the basket **stays on the fryer, resting**, with a rest timer.
   - **Too late:** you get **overcooked fries** in your hand, fit only for the bin.
3. **Take.** On a basket that is resting, a third interaction puts it in your hand. The **rest timer keeps running in your hand**.

**CUISSON 2: second fry**
4. **Put in.** The outcome depends on the rest timer at that moment:
   - **Rested too little:** the fries will come out **soggy**, even if the second fry goes well.
   - **Rested enough:** the fries will come out **good**, if the second fry goes well too.
5. **Lift.** Same as at CUISSON 1: too early gives **soggy** fries, too late gives **burnt** fries, and in time gives the result decided at step 4 (soggy or good). The fries go straight into the focused hand.

**Rules around the fryers**
- A basket left in the oil far too long, at either fryer, starts a **grease fire**. That makes the first slice's only hazard come out of the cooking itself.
- Resting fries **never spoil**, on the fryer or in a hand. The punishment for forgetting them is the lost time and the occupied fryer or hand.
- A resting basket **occupies CUISSON 1** until someone takes it, which puts pressure on the team to keep the fryer free.
- Bad fries (cold, overcooked, soggy, burnt) **can be served**, at a mood penalty. The bin is the clean way out.
- **Reading the timing:** a small gauge over each fryer shows the cook progress and a coloured "just right" zone, readable at a glance. A sound cue will be added once there is audio.
- The fryers are shared between players (CUISSON 1 and the two CUISSON 2 / VIANDES fryers in the demo level).

Fry states: raw (in oil), cold, overcooked, resting, soggy, good, burnt.

### 7.2 Menu
- **(proposal)** Frites with sauce (mayo, andalouse, samouraï…), fried snacks (fricadelle, boulette), a mitraillette (bread + meat + fries + sauce), and canned drinks and beer.
- Recipes are shown on a menu board in the kitchen, as in Cat Cafe.

## 8. Hazards

| Hazard | Cause | Effect | Counter |
|---|---|---|---|
| Spill | Dropped drinks/sauce, bumps, customers | Wet node: players slide through it **(proposal)** | Mop? Avoid it? |
| Thrown can | Customer misbehaviour | 1 heart of damage to the targeted player **(proposal:** telegraphed, dodged by leaving the node) | Keep the mood low |
| Grease fire | A basket left in the oil far too long (§7.1) | Blocks the fryer. Standing on its node costs 1 heart every ~2 s. Spreads to a neighbouring station after ~10 s | EXTINCTEUR in the focused hand, one interaction |
| Beer | A player drinks one | **(proposal)** Heals 1 heart but scrambles controls for a while (input delay or swapped keys) | Temptation |

## 9. Technical notes

- Godot 4.7, GDScript, Web export first (GitHub Pages), with GL Compatibility rendering.
- In-game text is **French only**: stations, tickets and the menu, like a real fritkot.
- Multiplayer: peer-to-peer WebRTC through the Tube addon, with sessions shared by ID.
- **(proposal)** The host is authoritative over node occupancy, collisions, the mood meter and hazards. Movement on discrete nodes is cheap to synchronise and makes conflicts easy to resolve: the host decides who got to a node first.

### 9.1 Deterministic simulation

The whole game runs as a **deterministic simulation**, separate from the Godot scenes. The same starting state, seed and inputs always produce the same night. That enables Factorio-style scenario tests, and it lets a bug seen in a real game be replayed exactly.

- **Fixed tick.** The simulation advances in integer ticks (**(proposal)** 30 per second). Every timer is a count of ticks, never a float `delta`, and nothing reads the wall clock.
- **Inputs are commands.** Players only affect the simulation through per-tick commands: *move up/down/left/right*, *focus left/right*, *interact*. The keyboard layer turns keys into commands; the network layer carries commands. The simulation never calls `Input`.
- **Seeded randomness.** All randomness (customers, orders, misbehaviour) comes from one seeded generator owned by the simulation.
- **Explicit tie-breaks.** Simultaneous events are resolved by a fixed rule. **(proposal)** Commands are applied in player-slot order, so when two players enter the same node on the same tick, the lower slot gets it and the other is bumped.
- **Level as data.** The anchor graph and station types are read from the scene into plain data. The simulation doesn't depend on nodes, so a test can build a tiny three-node kitchen by hand or load the real level.
- **Scenes only display.** Scenes read the simulation state and draw it: positions, gauges, hearts, tickets. This extends the readme's "decouple UI" principle to the whole game.
- **Networking.** The host runs the simulation; clients send their commands and receive the state or events back. Clients never need to run the simulation themselves, so the exact tick-by-tick agreement a lockstep network needs is not required, even though the simulation is deterministic.

### 9.2 Testing

- Tests use **GUT 9.7.1**, which targets Godot 4.7. Tests are written in GDScript and run headless (`godot --headless -s addons/gut/gut_cmdln.gd`), so CI runs them before building. A failing test blocks the deploy.
- **Unit tests** cover the rule classes: fryer states and windows, item transformations, mood meter, bump resolution, order matching.
- **Scenario tests** (Factorio-style) run a full multiplayer game in one process with no network. A scenario is: a level (built in the test or loaded), a seed, a timeline of `{tick, player, command}`, and assertions at given ticks.
  - Example: *two players both move into the CAISSE node on tick 100; at tick 101, slot 0 is on it, slot 1 is bumped and dropped its non-focused item.*
  - Example: *a basket left in CUISSON 1 for N ticks catches fire; the extinguisher puts it out; the mood rose by X.*
- **Replays:** the host records the seed and the command log of real games. A bug report becomes a replay file, and the replay becomes a scenario test.
- The actual network transport (Tube/WebRTC) is tested by hand with two local instances, since everything above it is covered by scenarios.

## 10. First playable slice (v0.1.x)

Goal: prove the core loop **with multiplayer**.

- Double cuisson frites with one sauce.
- Two-hand interaction model (§5.4).
- One hazard: grease fire + EXTINCTEUR.
- Mood meter (§6), with one customer type and a single queue with front-customer tickets.
- Hearts, knock-out, revive and crawl-to-SOINS.
- Node occupancy and bumps (§5.3).
- Online play through Tube, host-authoritative.
- Win at closing time, lose when the whole crew is down.

## 11. Open questions

To tune by playing the slice, not on paper:

1. Fry timings: how long are the first fry, the rest and the second fry, and how wide is each window?
2. Mood values: how much each event moves the meter, the level thresholds, and how fast it drifts upward.
3. Patience speeds (front and rest of the line), and the customer rate per player count.
4. Fire timings (damage interval, spread delay).

To decide after the slice: the other hazards (§8), the rest of the menu (§7.2), customer types beyond the first (§6.1), and whether customers can walk out.
