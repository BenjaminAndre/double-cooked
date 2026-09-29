# Art integration plan

The artist's first delivery (models, textures, UI, logo, font, concept boards) replaces the Kenney blockout. Some of it was made with AI. This plan says what goes where, what was refused and what to ask the artist for. Decisions were taken with the project owner on 2026-09-29; the GDD is updated as each step lands.

## Decisions

- **Hosting.** The assets are committed under `art/` (reference pictures in `docs/art/`, which Godot ignores) with a `CREDITS.md` (author, licence, mention of AI use). The artist agreed on 2026-09-29. The repo is private, so **real brands are accepted** (Coca-Cola, Jupiler, AC/DC). Caveat: a GitHub Pages site stays public, so the web build shows them to anyone with the link, and Pages from a private repo needs a paid GitHub plan.
- **Camera.** A 3/4 view like the artist's: 40° down, turned 59°. The arrows stay aligned with the grid: "up" goes towards the back, on a diagonal on screen. Characters face the camera square on (full billboards), and the room is drawn behind everything (`Backdrop`) so they never clip into it.
- **Characters are paper cut-outs**: Sprite3D billboards that turn around the vertical axis only, so they stay upright. The 3D figurines were placeholders.
  - `MainCharacter01`–`04` are the players. **PEINTURE chooses one of the four characters** (blue, red, green or yellow T-shirt), unique in the team. `Looks.COLORS` shrinks to these four, and the colour still stands for the player everywhere.
  - `Character01`–`05` are the customers, picked from the customer id so every peer sees the same one.
  - `DrunkCharacter01` is the boss. The concept board literally says "un baraki demande une grosse commande".
- **End-of-night stars instead of points.** Each criterion is worth one star:
  - held until closing;
  - the room still in the green at the end (mood under half);
  - all three of the boss's orders served.

  A lost night gets no stars. There are no points, money or +100 / -20 pop-ups.
- **Patience** becomes the artist's horizontal bar (angry face, red → green, happy face), bottom right. The "Patience" label goes.
- **Station menus** become a bubble over the **station**, as on the concept board (FRIGO with the selection frame and the key cap). This works because only one player stands on a node.
- **Menu layout.** A menu opens on its first option, in the centre, and grows by steps without moving the existing options. On a 3 × 3 grid, as (column, row) with the start at (1, 1):

  | Option | Cell |
  |---|---|
  | 1 | (1, 1), the start |
  | 2 | (2, 1), right |
  | 3 | (0, 1), left |
  | 4 | (1, 2), below the start |
  | 5 | (2, 2) |
  | 6 | (0, 2) |
  | 7 | (1, 0), above the start |
  | 8 | (2, 0) |
  | 9 | (0, 0) |

  The arrows move to the neighbouring cell when it holds an option. Option order therefore matters: the most common choice goes first. This replaces the single row and the 3 × 3 special case (`Menu.GRID_COLUMNS`).
- **Menu.** Take everything drawn:
  - ketchup, as a third sauce;
  - boulette and brochette, meats fried in CUISSON 2;
  - the burger, a bun and a patty cooked from raw, assembled like the mitraillette.

  In the campaign, they unlock night after night.
- **No title screen.** The logo shows big over the lobby until the first step. `MenuBackground` and the `Pub_*` pictures go to the readme, Pages and itch.
- **Refused:**
  - the on-screen buttons (close, home, help, retry, pause);
  - the tutorial box with OK (no pause, keyboard only);
  - the team's hearts in a corner (hearts stay over each player);
  - money.

  The dialogue frame is kept for announcements that go away on their own, such as "Le boss arrive !". The home and retry icons can mark the Entrée hint on the end banner.

## Asset map

| Game element | Asset |
|---|---|
| Kitchen shell, street | `Room01`, `GroundAtlas_BC` (checkered floor shows the grid: `GridView` goes) |
| FRIGO | `Fridge` (opens with its menu: frames 1–10, closes 11–24) |
| CUISSON 1 / 2 | `DeepFryer` (basket ejects when lifting, frames 1–30), `FryingOilSheet` 5 × 5 while frying |
| Fire | `FireSheet` 5 × 3 |
| POUBELLE | `Trash` (opens when trashing) |
| EXTINCTEUR | `FireCase`, `Item_Extincteur` when held |
| CAISSE | `Counter` + `CashRegister` + `PaperBag` |
| VIANDES | `Counter` + `Glass_*` display case with the raw meats |
| SAUCES | `Counter` with the sauce bottles (`Sauce*`) |
| PAIN | `BreadBag`, `BreadBurger` |
| Plain counter | `Furniture` (1 m module) |
| Customers' cans | `FoledCan` |
| Held item | `Item_*.png` icon over the player, instead of the text |
| Orders | `UX_FrameOrder01`–`03` (1–3 icons) + `UX_SliderGreen` / `Red` for patience |
| Fryer gauge | `CookedSlider` colours: yellow, then green when ready, then red. Our zones stay dynamic. |
| Hearts | `UX_Life`, `UX_LifeEmpty` |
| Clock | `UX_Time` |
| Room mood | `UX_MoodSlider01` + `UX_MoodSlider02` (cursor) |
| Menu selection | `UX_Selection01` / `02`, key caps on `UX_Button01` / `02` |
| Fryer about to burn | `UX_Alert` (siren), `UX_Warning` |
| Aim | `UX_Arrow` |
| Announcements | `UX_FrameTextInfo` |
| End of night | `UX_Frame` notebook, `UX_Star` / `UX_StarEmpty`, `UX_Gold` / `Silver` / `Bronze` for fun trophies |
| Font | Bebas Kai (OFL). It has every French accent, `×` and `·`. |
| Logo | `Logo.png` over the lobby; `MenuBackground*`, `Pub_*` for pages |

Rendering follows the artist's readme: unlit materials, everything in the textures, and a `DCF6FF` background. A post-import script sets the FBX materials to unshaded. This should also make the web build lighter.

## Steps (one version each)

The art comes before the rest of the roadmap. Steps 1–4 are 0.1.32–0.1.35; step 5 completes the art and is **0.2.0**. The later roadmap (reconnect, campaign, mitraillette, debug tools) follows as 0.2.1–0.2.4.

1. **Intake** (0.1.32).
   - Copy the assets, write `CREDITS.md`, add the unlit import script and the Bebas Kai theme.
   - Implement the menu layout rule (in `Menu` and `Simulation._use_menu`, with tests).
2. **Room and camera** (0.1.33).
   - Put the `Room01` shell around the grid, aligned on the floor tiles, and the queue outside along the street.
   - Set the isometric camera, the background colour, and unlit rendering.
   - Remove the Kenney floor and `GridView`.
3. **Paper characters** (0.1.34).
   - Players, customers and the boss become billboards.
   - PEINTURE offers four characters.
   - Fat widens the sprite, K.O. lays it on the floor, and stun keeps the stars.
   - The beer helmet becomes an overlay.
4. **Stations** (0.1.35).
   - Models on their cells, with the fridge, bin and basket animations.
   - Oil and fire particles, and the alert siren.
5. **Items and HUD** (0.2.0).
   - Held-item icons, order bubbles, menu bubbles over stations.
   - Gauges, hearts, clock and mood bar.
   - Announcements, the end notebook with stars, and the logo over the lobby.
6. **Menu**, within the campaign (0.2.2): ketchup first, then boulette and brochette, then the burger recipe.

## To ask the artist

- **Items for the failed states:**
  - soggy, burnt and cold fries;
  - lukewarm and burnt cervelas;
  - undercooked and burnt fricadelle;
  - burnt versions of the new meats.
- **Characters:**
  - the four players without their cap (the "none" hat at CASQUETTE);
  - the beer helmet as a sprite;
  - a lying pose for the knock-out, if flipping the sprite doesn't look right.
- **Fryer:** a 1 m module, or a split of the 3 m unit, to fit our 4 fryer cells (CUISSON 1 over 2 cells, two CUISSON 2).
- **Credits:** the name and wording to put in `CREDITS.md` (their agreement was given on 2026-09-29).
