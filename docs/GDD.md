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
4. **Short, loud nights.** Players are expected to talk to each other outside the game (voice chat), so the game has no chat, pings or other communication tools. One night lasts about 6 minutes, with an instant rematch.
5. **No pause menu, on purpose.** It keeps the pace: a night is only about 6 minutes, and the end-of-night screen is the natural pause.

## 3. Core loop

Take an order at the CAISSE → prepare it across the stations → hand it over → the room mood goes down or up → hazards appear accordingly → deal with the hazards while repeating the loop. This runs until closing time or until the whole crew is down.

## 4. Session: one night

- One game is one night, 18:00 to 04:00 in just under 6 minutes of real time. **At 04:00 the door closes**: nobody comes in any more, and the night only ends once every customer still inside has been dealt with.
- The pace follows the clock (revised after the fourth playtest): calm until 20:00, then a steady build-up of customers until the peak at closing time. Tunables: `SimRules.calm_until`, `mad_from` and the calm / mad factors. A customer every 8 to 15 s for one player before those factors (raised by half on 2026-10-08: the first night felt empty).
- A single night (**nuit libre** at the PORTE) has the whole menu. Progression comes from the campaign (§4.2).
- **End of night:** a win or loss ("closed at 04:00" or "crew down at 01:37"), **up to three stars** on the artist's notebook (one for holding until closing, one for a room still in the green, under half the riot, one for serving every order of the boss; a lost night has none), plus a short recap of fun stats: orders served, fires, bumps per player, who was knocked out most. Bragging material, with no points or economy behind it.

### 4.1 The lobby (after the first online playtest)
- The game opens in a **waiting room that plays like the kitchen**: the same grid, walking and station menus, with no customers, clock or hunger. Online, everyone connected is in it together; a newcomer joins it at once (during a night, they wait for the next lobby).
- **PEINTURE**: choose one of the **four characters** (their faces, laid out like any menu, §5.4). Each is unique in the team (a teammate's is greyed out). **CASQUETTE**: nothing, a cap, or a beer helmet with straws. Looks are kept between sessions, and carried into the night (§5.5).
- **TÉLÉPHONE**: create an online game, join one (type the code), two players on this keyboard or back to one, and leave the online game. It replaces the old H / J / F2 keys and the text over the screen.
- **PRÊT** tiles on the floor: a player standing on one is ready. **PORTE**: only the host opens it, once every other player is ready; the hint says what is missing. Its menu offers a **campagne** (first, §4.2) or a **nuit libre**. After a single night, Entrée takes everyone back to the lobby.

### 4.2 The campaign (0.2.3)
- Like the rounds of a zombie game: **nights one after the other, endless, until the crew falls**. A held night leads to the next one (Entrée, the host's online); a riot or the whole crew K.O. **loses the campaign** and everyone goes back to the lobby. No purchases between nights yet.
- **The score is the night reached.** The best one is the team's record, kept on this browser (`user://looks.cfg`) with the colours of that crew, and shown under the logo in the lobby.
- **Each night is busier**: arrival delays are divided by 1 + 0.05 × (night − 1) (`SimRules.busier_per_night`). The calm-to-mad curve inside a night is unchanged.
- **The menu grows** (`Campaign.UNLOCKS`): night 1 plain fries and beer (a knocked-out player always has a beer to crawl to: without it, the first night could softlock); 2 mayo, andalouse and cola; 3 cold cervelas; 4 fricadelle; 5 warm cervelas; 6 ketchup; 7 boulette; 8 brochette. Customers only order from it, and the night's announcement says what is new.
- **Station menus only offer tonight's items**, and a station with nothing to do is **greyed out and inert** (today PAIN, VIANDES before night 3, SAUCES on night 1). A menu with nothing in it never opens.
- **The summary** shows the night reached and, per player (by colour): served, missed, beers given, bumps, K.O., revives; at the end of a campaign, the record.
- Later (§12): barricades against the cans, special nights every N nights, an easter egg.

## 5. Players

- **1 to 4 players, in the same kitchen.** Solo is roomy and four players is packed; the layout does not change. The customer rate scales with the player count.

### 5.1 Health, eating and knock-out
- Each player has 3 hearts over their head (the artist's, lost ones shown empty).
- **There is no healing station** (SOINS was removed after the third playtest). A player heals by **eating or drinking what they hold**, anywhere, with **its own key** (Entrée; E for P1 and Entrée for P2 in duo), 1 heart at a time. It first shared the interact key, which made for too many accidental meals (fifth playtest). Any food works, however badly done, and so do drinks. Eating the burnt fries instead of walking to the bin is a real choice.
- **Body mass index** (after the fourth playtest): everyone starts at a healthy **21**. Every bite or drink adds **+1** (even at full health; a discreet "+Gras" pops up), and every **25 nodes walked** burn **−1**. Above 21 the player is fatter (the artist's three fatter drawings, from 22, 24 and 26) and **12% slower per point**; below 21 they are visibly thinner but not faster. At **16** they collapse, undernourished, and need a beer like any knocked-out player (their name says "affamé" from 18). Running the fritkot either drains you or fattens you.
- At 0 hearts a player is **knocked out**: they lie on their node and **block it**, crawl slowly (about 2 s per node, one node at a time), and can only eat or drink what they hold, or use the FRIGO.
- **Rescue:** a teammate throws them a beer (§8), which they drink at once to get back up with 1 heart. Alone, a knocked-out player crawls to the FRIGO and drinks a beer. Rescue beers count toward the fat too.
- The night is **lost when every player is knocked out at the same time** (from two players up), or **when the room riots**: the mood meter reaches its top (§6).

### 5.2 Movement
- Players move from node to node with the arrow keys, and moves can be queued (already implemented: `Anchor` graph, `future_path`).
- A node holds one player at a time.
- The kitchen is a **regular square grid** (6 × 2 in the demo): every node is one metre from its neighbours and the arrows always mean the same direction (fifth playtest: the irregular nodes around the CAISSE were confusing). The CAISSE sits in the bottom row like the other counters. It is built from a layout (`GridRoom`) inside the artist's room: the checkered floor shows the grid (2 × 2 tiles per node), the back row against the back wall, the CAISSE row on the street side, the customers queueing outside on the pavement, in front of the serving window, where they hide no station. The fryer is one long unit over CUISSON 1 and both CUISSON 2: raw and cooked fries on CUISSON 1, one oil well and basket on each CUISSON 2.
- **The camera is a 3/4 view** like the artist's: 40° down, turned 31° from straight in front (tried at 59°, back to 31° on 2026-09-29: the arrows read more clearly). The arrows keep following the grid: "up" goes towards the back of the kitchen, on a diagonal. The room itself (floor, walls) is drawn behind everything whatever the depth (`Backdrop`), so the tilted paper figures never sink into it, except the walls on the camera's side, drawn again in depth so they hide whoever stands behind them; counters and stations stay in depth with the figures, which are as deep as a card standing upright at their feet: they never sink into what is behind them, and a counter in front of them still hides their legs. Hearts, a word when knocked out or starving, and the held item (a speech bubble pointing down at the player) are drawn on screen over each head, so nothing in the kitchen hides them.

### 5.3 Collisions (knocking)
- Knocking happens **through collisions only**, with no dedicated key.
- Moving into an occupied node **stops the bumper**, who has to pick another path, and **stuns the bumped player for 0.5 s**: they can neither move nor act (stars and a shake show it). Nobody drops anything.
- The pressure comes from the space itself: more players mean more orders, and more collisions in the same cramped kitchen (changed after the second playtest, which dropped the second hand).
- **(proposal)** A dropped drink or sauce leaves a spill. On a wet floor, the bumped player slides to the next node in the direction of the push.

### 5.4 Hand and interaction
- Each player has **one hand** (changed after the second playtest: two hands were too hard at first).
- **Space interacts** with the station at the player's node, and the station **transforms or fills the hand directly**. Items are never put down on the counter first; there are no intermediate steps.
- **Station menus:** SAUCES, FRIGO and VIANDES offer a choice. The first press opens a menu. While it is open, the arrows move the selection instead of the player, a second press takes the selected option, and Échap closes the menu without taking anything (Backspace for P2 in duo). The options sit on a 3 × 3 grid around the first one, which is where the menu opens: the next ones go right, left, below, bottom right, bottom left, above, top right and top left (`Menu.CELLS`), so a menu grows without moving what is already there, and the first option should be the most common choice.
- Station rules:
  - With an empty hand, interacting at a supply station (FRIGO, VIANDES, EXTINCTEUR…) takes an item.
  - Interacting at the POUBELLE empties the hand.
  - Interacting at the CAISSE serves whatever is held to the front customer (§6.2).
  - Fryers keep their own state (§7.1).
- The station a player stands at is highlighted, with a hint of what their keys do there (`Simulation.action_for`): the artist's key cap and a verb, over the player. An open station menu is a **cream bubble over the station**, as on the concept: its options as the artist's pictures (sauces, drinks, meats, faces), words where there is none yet, the selected one in the yellow selection frame, and the key that chooses. The held item shows as its picture over the head, customers' orders as pictures in speech bubbles, and the room mood as the artist's bar with an angry and a happy face (bottom right).

### 5.5 Looks
- Players are **paper cut-outs** (the artist's drawings, always facing the camera): four characters, told apart by their T-shirt colour (blue, red, green, yellow), unique in the team. The colour **stands for them everywhere instead of "P1"**: the recap (a block of colour), messages ("Rouge est parti"). There is no name over their head. Fat swaps in a fatter drawing, a knock-out lays it flat on the floor, a bump shakes it. Customers are cut-outs too, and the boss is the drunk baraki, bigger.
- A **hat**, just for fun: none, a cap (the default) or a beer helmet. Both are chosen in the lobby (§4.1). The cap is drawn on the characters, so "none" still shows it until the artist draws them without.

## 6. The room mood (ambiance)

- The whole fritkot shares **one mood meter**.
- Orders served on time lower it. Late, wrong or abandoned orders raise it.
- A higher mood means more frequent and nastier hazards.
- Mood levels: *Calme → Tendu → Chaud → Émeute*. Only what happens in the fritkot moves the meter: it no longer drifts with the hour (the hour already speeds up arrivals, §4). It shows as a half-moon dial, green to red, with a needle.

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

### 6.3 The boss (after the first online playtest)
A Dark Souls style boss customer: bigger, in red instead of blue, with his own rules. Tunables are the `boss_*` values in `SimRules`.
- **Once a night, at 02:00**, just as the night turns tense. He cuts in at the counter and sends everyone back one place, **even the customer whose order the players were preparing**. The line waits behind him until he leaves.
- **Three orders, one after the other** (food only), each with twice the usual patience. His ticket shows three dots:
  - black for an order still to come, ringed in white for the current one;
  - green once served right, red once missed.
- **A missed order** (wrong, badly done, or out of patience) sours the mood a lot, and he throws a **salvo of cans** at the crew. Then he moves on to his next order.
- **A drink on the side:** a second ticket, cola or beer, with its own short patience. It is served at the CAISSE or by a thrown beer. Left waiting, or given the wrong drink, it costs his current order some patience. He orders another a little later.
- **While he waits** he throws a can at a random player every few seconds, for no reason.
- **He leaves after his third order.** All three served right cheers the room up a lot. The recap shows how many of his orders were served.

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

**CUISSON 2: second fry (ready from 3 to 11 s)**
4. **Put in** a blanched portion.
5. **Lift:** too early gives **soggy** fries, in time **good** fries, too late **burnt** fries.

**Rules around the fryers**
- Anything left in the oil 10 s past the end of its window starts a **grease fire**.
- Bad fries (soggy, burnt) can be served, at a mood penalty. The bin is the clean way out.
- **Reading the timing:** a horizontal gauge over each fryer, 25% transparent: yellow while undercooked, blue when ready, red from too late up to the fire at its end, with a white line for the progress. A batch waiting on CUISSON 1 shows its portions left (×5), and as many cooked portions on the fryer. The gauge is drawn over everything, so nothing in the kitchen hides it.
- The fryers are shared between players.

### 7.2 Menu
- **Now on the menu:**
  - **frites** with a sauce;
  - **fricadelle** (raw from VIANDES, fried once in a CUISSON 2) with a sauce;
  - **cervelas**: served **cold** straight from VIANDES, or **warm** after a fry in a CUISSON 2, with a sauce;
  - **cola** or **bière** from the FRIGO. Colas never run out; the FRIGO holds **5 beers** and gets one back every 25 s (shown over it and in its menu), so beers are a shared, scarce resource for orders, gifts, rescues and healing (after the fourth playtest: one player was spending the night gifting beers).
- **boulette** and **brochette**, raw from VIANDES and fried in a CUISSON 2 like the fricadelle.
- The sauces are **mayo**, **andalouse** and **ketchup**, or **nature** (no sauce), which customers order too. A campaign night only has part of the menu (§4.2).
- Nothing with sauce goes into a fryer.
- CUISSON 2 lifts meats with the same window as fries: too early gives undercooked (fricadelle) or lukewarm (cervelas), too late gives burnt. Both are served at a mood penalty.
- Later: samouraï and other sauces, a mitraillette (bread + meat + fries + sauce), a menu board in the kitchen as in Cat Cafe.

## 8. Hazards

| Hazard | Cause | Effect | Counter |
|---|---|---|---|
| Spill | Dropped drinks/sauce, bumps, customers | Wet node: players slide through it **(proposal)** | Mop? Avoid it? |
| Thrown can | A customer leaving angry throws one on the way out, at **whoever served them badly** (or gave them one beer too many); walk-outs and random throws past Chaud go to the **player closest to the counter** | The can flies a visible arc (dotted line) to a red ring where the target stood; 1 heart to every player inside the ring when it lands, **no bump** | Step out of the ring; keep the mood low |
| Grease fire | A basket left in the oil far too long (§7.1) | Blocks the station. **Standing** on its node costs 1 heart every ~2 s (walking past is safe). Spreads to a neighbouring station after ~10 s; EXTINCTEUR itself never burns | Take the extinguisher at EXTINCTEUR (it stays in your hand and goes back on its station), then one interaction at the fire |
| Beer (throwing) | A player holding a beer holds interact | Aim: a ▼ over a customer in line (left / right), or **up** for a teammate. Release to throw. A customer who ordered a beer is served; otherwise their **first** unordered beer buys back a quarter of their patience, and a **second** one sends them off angry. A teammate who is knocked out drinks it and gets up; otherwise it lands in an empty hand, or falls. A quick tap still uses the station | A breather for an impatient line |
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
- **Networking.** The host runs the simulation and relays the **command stream** (every tick's commands, in the order it applied them) to the clients, who run the same deterministic simulation from it. Every second the host also sends a state fingerprint, so a client notices any desync: it shows a red warning in the HUD and keeps the ticks of the failed checks in its replay. Clients never wait for each other (no lockstep), but a client's own key presses take a round trip before they apply, because there is no client-side prediction yet. Everyone says hello on connecting, with an id kept on their machine. **Joining a night under way**: the newcomer gets how the night started and every command since, replays it at full speed, and plays at once on a free spawn (up to the kitchen's spawns; the kitchen is sized again only at the next night). **A dropped player** stays in the night, idle and marked as gone, and **gets their slot back** when they reconnect (the game tries the same code again on its own). **If the host leaves**, the player with the lowest slot still there opens a session under the same code, the others rejoin it and catch up with the night where it stood, which stands still meanwhile ("Reconnexion...", up to 15 s); a client warns when the host has been silent for 2 s. On the web, a hidden tab gets no frames, so a Worker timer keeps the night and the network going there, and a red HTML banner shows any crash that kills the main loop. The command stream is also the replay (§9.2).

### 9.2 Testing

- Tests use **GUT 9.7.1**, which targets Godot 4.7. Tests are written in GDScript and run headless (`godot --headless -s addons/gut/gut_cmdln.gd`), so CI runs them before building. A failing test blocks the deploy.
- **Unit tests** cover the rule classes: fryer states and windows, item transformations, mood meter, bump resolution, order matching.
- **Scenario tests** (Factorio-style) run a full multiplayer game in one process with no network. A scenario is: a level (built in the test or loaded), a seed, a timeline of `{tick, player, command}`, and assertions at given ticks.
  - Example: *two players both move into the CAISSE node on tick 100; at tick 101, slot 0 is on it, slot 1 is bumped and dropped its non-focused item.*
  - Example: *a basket left in CUISSON 1 for N ticks catches fire; the extinguisher puts it out; the mood rose by X.*
- **Replays:** every peer records the seed and the command log of the night. F3 saves the night so far at any time (a download on the web, where `user://` is out of reach), and the end banner points at it. A bug report becomes a replay file, and the replay becomes a scenario test.
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

## 12. Towards v1.0

- **Campaign mode** (first version in §4.2): later, more complex orders (the mitraillette), barricades to build against the cans, special nights every N nights (like the dog rounds), and an easter egg: a hidden quest in the kitchen that unlocks a secret hat or colour.
- **Grid menus:** station menus as a 3×3 grid (5×5 at harder levels), the cursor starting in the middle, moved with the arrows. Efficient with a keyboard and quick to learn.
