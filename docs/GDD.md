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
- The pace follows the clock (changed after the second playtest):
  - **18:00–23:00, calm:** few customers, a slow mood drift; time to learn the kitchen.
  - **23:00–01:00, rising:** customers come faster and faster.
  - **After 01:00, mad:** flat out, the drunks and barakis hour.
  - Tunables: `SimRules.calm_until`, `mad_from` and the calm / mad factors.
- **(proposal)** Variety comes from difficulty levels and random events, not from progression between nights.
- **End of night:** a win or loss ("closed at 04:00" or "crew down at 01:37") plus a short recap of fun stats: orders served, fires, bumps per player, who was knocked out most. Bragging material, with no economy behind it.

## 5. Players

- **1 to 4 players, in the same kitchen.** Solo is roomy and four players is packed; the layout does not change. The customer rate scales with the player count.

### 5.1 Health and knock-out
- Each player has 3 hearts (already implemented).
- At 0 hearts a player is **knocked out**. They lie on their node and **block it**, until a teammate gets them back up by interacting with them.
- The night is **lost when every player is knocked out at the same time**, or **when the room riots**: the mood meter reaches its top (§6).
- The SOINS station restores hearts.
- **Solo play is supported.** A knocked-out player can **crawl** slowly toward SOINS to get back up alone. In solo this is the only way to recover, and the night is lost if the room riots first.
- A revived player comes back with 1 heart. Crawling takes about 2 s per node.
- Getting a knocked-out neighbour up takes priority over using your own station. A knocked-out player can only use SOINS.
- **(slice default)** Losing "when every player is knocked out" applies from two players up. A solo player who is knocked out keeps crawling toward SOINS.

### 5.2 Movement
- Players move from node to node with the arrow keys, and moves can be queued (already implemented: `Anchor` graph, `future_path`).
- A node holds one player at a time.

### 5.3 Collisions (knocking)
- Knocking happens **through collisions only**, with no dedicated key.
- Moving into an occupied node **stops the bumper**, who has to pick another path, and **stuns the bumped player for 0.5 s**: they can neither move nor act (stars and a shake show it). Nobody drops anything.
- The pressure comes from the space itself: more players mean more orders, and more collisions in the same cramped kitchen (changed after the second playtest, which dropped the second hand).
- **(proposal)** A dropped drink or sauce leaves a spill. On a wet floor, the bumped player slides to the next node in the direction of the push.

### 5.4 Hand and interaction
- Each player has **one hand** (changed after the second playtest: two hands were too hard at first).
- **Space interacts** with the station at the player's node, and the station **transforms or fills the hand directly**. Items are never put down on the counter first; there are no intermediate steps.
- **Station menus:** SAUCES, FRIGO and VIANDES offer a choice. The first press opens a menu. While it is open, the arrows move the selection instead of the player, a second press takes the selected option, and Échap closes the menu without taking anything (Backspace for P2 in duo).
- Station rules:
  - With an empty hand, interacting at a supply station (FRIGO, VIANDES, EXTINCTEUR…) takes an item.
  - Interacting at the POUBELLE empties the hand.
  - Interacting at the CAISSE serves whatever is held to the front customer (§6.2).
  - Fryers keep their own state (§7.1).
- The station a player stands at is highlighted, with a hint of what their interact key does there (`Simulation.action_for`). Text for now; the aim is icons, and as little text as possible overall.

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
- **Each customer orders a single line** that fits in one hand: fries with a sauce, a meat with a sauce, or a drink (changed after the second playtest).
- **The first 3 customers in line show a ticket** (order + patience bar) under them; the rest of the line is visible, but their orders stay unknown. One ticket per stage of the fries (first fry, second fry, ready), so players can start the next basket in time. Tunable: `SimRules.visible_orders`.
- **Everyone in the line loses patience**, slowly, and the customer at the front loses it much faster. A long line raises the mood on its own, even if nobody is served badly.
- A customer whose patience runs out **walks out**, which raises the mood a lot.
- **Interacting at the CAISSE is serving:** the held item always goes to the front customer. The right order (dish **and** sauce), done right, sends them off happy and calms the room. The wrong order, or anything badly done (burnt, soggy, undercooked, lukewarm), sends them off **angry**, which raises the mood.
- **A beer always pleases** (the one exception): if it wasn't their order, it buys back some patience and they keep waiting.

## 7. Cooking

### 7.1 Double cuisson (signature mechanic)

Fries go through a first fry at CUISSON 1, in **batches of 5 portions**, then a second fry at CUISSON 2, one portion at a time. Every step is one interaction with the focused hand. (Revised after the first playtest: resting was removed, and the first fry now makes a batch so both CUISSON 2 get used.)

**CUISSON 1: first fry (ready from 8 to 20 s)**
1. **Drop.** Interacting with an empty CUISSON 1 drops a batch of raw fries into the oil. No supply station is needed.
2. **Lift.** Interacting again lifts the batch:
   - **Too early:** the whole batch comes into the hand as **cold fries**, fit only for the bin.
   - **Just in time:** the batch stays on the fryer, blanched and ready.
   - **Too late:** the whole batch comes into the hand as **overcooked fries**, fit only for the bin.
3. **Take.** Each further interaction takes **one blanched portion** into the hand. CUISSON 1 stays occupied until all 5 portions are taken.

**CUISSON 2: second fry (ready from 3 to 7 s)**
4. **Put in** a blanched portion.
5. **Lift:** too early gives **soggy** fries, in time **good** fries, too late **burnt** fries.

**Rules around the fryers**
- Anything left in the oil 10 s past the end of its window starts a **grease fire**.
- Bad fries (soggy, burnt) can be served, at a mood penalty. The bin is the clean way out.
- **Reading the timing:** a horizontal gauge over each fryer, 25% transparent: yellow while undercooked, blue when ready, red from too late up to the fire at its end, with a white line for the progress. A batch waiting on CUISSON 1 shows its portions left (×5).
- The fryers are shared between players.

### 7.2 Menu
- **Now on the menu:**
  - **frites** with a sauce;
  - **fricadelle** (raw from VIANDES, fried once in a CUISSON 2) with a sauce;
  - **cervelas**: served **cold** straight from VIANDES, or **warm** after a fry in a CUISSON 2, with a sauce;
  - **cola** or **bière** from the FRIGO.
- The sauces are **mayo** and **andalouse**, or **nature** (no sauce), which customers order too.
- Nothing with sauce goes into a fryer.
- CUISSON 2 lifts meats with the same window as fries: too early gives undercooked (fricadelle) or lukewarm (cervelas), too late gives burnt. Both are served at a mood penalty.
- Later: samouraï and other sauces, boulette, a mitraillette (bread + meat + fries + sauce), a menu board in the kitchen as in Cat Cafe.

## 8. Hazards

| Hazard | Cause | Effect | Counter |
|---|---|---|---|
| Spill | Dropped drinks/sauce, bumps, customers | Wet node: players slide through it **(proposal)** | Mop? Avoid it? |
| Thrown can | A customer leaving angry (wrong order, badly done, patience run out) throws one on the way out; past Chaud, waiting customers also throw at random, more often the worse the mood | The can flies a visible arc (dotted line) to a red ring where the target stood; 1 heart to every player inside the ring when it lands, **no bump** | Step out of the ring; keep the mood low |
| Grease fire | A basket left in the oil far too long (§7.1) | Blocks the station. **Standing** on its node costs 1 heart every ~2 s (walking past is safe). Spreads to a neighbouring station after ~10 s; EXTINCTEUR itself never burns | Take the extinguisher at EXTINCTEUR (it stays in your hand and goes back on its station), then one interaction at the fire |
| Beer (throwing) | A player holding a beer holds interact | Aim: a ▼ over a customer in line, moved with the arrows; release to throw. Whoever stands where it lands catches it: their order is served if they asked for a beer, otherwise it buys back a quarter of their patience. A beer that lands on nobody is lost. A quick tap still uses the station | A breather for an impatient line |
| Beer (drinking) | **(proposal)** A player drinks one | Heals 1 heart but scrambles controls for a while | Temptation |

## 9. Technical notes

- Godot 4.7, GDScript, Web export first (GitHub Pages), with GL Compatibility rendering.
- In-game text is **French only**: stations, tickets and the menu, like a real fritkot.
- Multiplayer: peer-to-peer WebRTC through the Tube addon, with sessions shared by ID.
- The host is authoritative: it decides which tick every command applies on, so it settles who got to a node first.

### 9.1 Deterministic simulation

The whole game runs as a **deterministic simulation**, separate from the Godot scenes. The same starting state, seed and inputs always produce the same night. That enables Factorio-style scenario tests, and it lets a bug seen in a real game be replayed exactly.

- **Fixed tick.** The simulation advances in integer ticks (**(proposal)** 30 per second). Every timer is a count of ticks, never a float `delta`, and nothing reads the wall clock.
- **Inputs are commands.** Players only affect the simulation through per-tick commands: *move up/down/left/right*, *focus left/right*, *interact*. The keyboard layer turns keys into commands; the network layer carries commands. The simulation never calls `Input`.
- **Seeded randomness.** All randomness (customers, orders, misbehaviour) comes from one seeded generator owned by the simulation.
- **Explicit tie-breaks.** Simultaneous events are resolved by a fixed rule. **(proposal)** Commands are applied in player-slot order, so when two players enter the same node on the same tick, the lower slot gets it and the other is bumped.
- **Level as data.** The anchor graph and station types are read from the scene into plain data. The simulation doesn't depend on nodes, so a test can build a tiny three-node kitchen by hand or load the real level.
- **Scenes only display.** Scenes read the simulation state and draw it: positions, gauges, hearts, tickets. This extends the readme's "decouple UI" principle to the whole game.
- **Networking.** The host runs the simulation and relays the **command stream** (every tick's commands, in the order it applied them) to the clients, who run the same deterministic simulation from it. Every second the host also sends a state fingerprint, so a client notices any desync. Clients never wait for each other (no lockstep), but a client's own key presses take a round trip before they apply, because there is no client-side prediction yet. Players join between nights, not during one. The command stream is also the replay (§9.2).

### 9.2 Testing

- Tests use **GUT 9.7.1**, which targets Godot 4.7. Tests are written in GDScript and run headless (`godot --headless -s addons/gut/gut_cmdln.gd`), so CI runs them before building. A failing test blocks the deploy.
- **Unit tests** cover the rule classes: fryer states and windows, item transformations, mood meter, bump resolution, order matching.
- **Scenario tests** (Factorio-style) run a full multiplayer game in one process with no network. A scenario is: a level (built in the test or loaded), a seed, a timeline of `{tick, player, command}`, and assertions at given ticks.
  - Example: *two players both move into the CAISSE node on tick 100; at tick 101, slot 0 is on it, slot 1 is bumped and dropped its non-focused item.*
  - Example: *a basket left in CUISSON 1 for N ticks catches fire; the extinguisher puts it out; the mood rose by X.*
- **Replays:** the host records the seed and the command log of real games. A bug report becomes a replay file, and the replay becomes a scenario test.
- The actual network transport (Tube/WebRTC) is tested by hand with two local instances, since everything above it is covered by scenarios.

## 10. First playable slice (v0.1.x) — implemented in 0.1.8

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

To decide after the slice: the other hazards (§8), the rest of the menu (§7.2), and customer types beyond the first (§6.1).

From the first playtest:

- **Batch frying?** In a real fritkot a whole batch is fried, then served from continuously. One basket = one portion (now) keeps every order a small cooking puzzle; batches would shift the game towards stock management and anticipation. Not decided.
- **The start is slow**: the first customer waits while the first basket cooks. Maybe fine as a calm opening (Soirée phase); revisit with the batch question.
