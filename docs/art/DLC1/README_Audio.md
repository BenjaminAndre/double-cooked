# Double Cooked : pack d'effets sonores, guide d'intégration et de mixage

Document destiné à l'IA (ou au développeur) qui intègre les sons dans le jeu. Il contient tout ce qu'il faut : contenu du pack, réglages d'import, architecture audio, règles de mixage, table complète des sons avec leur volume, et séquences de déclenchement.

Le GDD du jeu (v1.0) prévoit Godot : les exemples sont en GDScript pour Godot 4.x. Adapter si le moteur est différent, les valeurs de mixage restent valables.

---

## 1. Contenu du pack

- Le dossier **`Sounds`** contient **77 fichiers WAV** (mono, 44,1 kHz, 16 bits, environ 5 Mo au total) et la musique `MainTheme.mp3`, le tout à plat. Dans le projet, placer ce dossier où l'on veut (par exemple `res://audio/`) et adapter la constante `DIR` du §9 en conséquence.
- Les sons sont **synthétisés** (pas d'enregistrements) : cohérents entre eux, mais certains sons organiques sont approximatifs (`burp`, `customer_sleep`, `group_cheer`, `halftime_horn`, `sauce_squirt`). Remplaçables plus tard sans toucher au code si les noms de fichiers restent identiques.
- **Trois fichiers sont des boucles** : `fry_sizzle_loop`, `meat_sizzle_loop`, `fire_loop` (voir §2).
- **La musique est incluse dans le pack** : `MainTheme.mp3`, dans le même dossier `Sounds` que les WAV. Elle est jouée pendant toute la partie (voir §4).
- Tous les fichiers WAV sont normalisés au même pic (environ -1,9 dBFS) : **leur niveau perçu n'est donc pas équilibré entre eux**. Le mixage se fait avec la colonne `volume_db` de la table du §7, à appliquer sur chaque lecteur.

## 2. Import dans le moteur

- Garder le format WAV (latence minimale, pas de décodage). Si la taille de l'APK devient un problème, convertir en OGG Vorbis qualité 5, sauf les trois boucles qui restent en WAV.
- **Boucles** : dans l'onglet Import, mettre `Loop Mode = Forward` sur `fry_sizzle_loop`, `meat_sizzle_loop` et `fire_loop`. Leur raccord est déjà fondu, il n'y a pas de clic à la jonction.
- **Tous les autres sons** : `Loop Mode = Disabled`.
- Les sons sont mono : ils fonctionnent sur les haut-parleurs mono des téléphones. Ne pas les spatialiser en stéréo forte (voir §5.6).

## 3. Architecture des bus audio

```
Master            (effet : AudioEffectLimiter, ceiling_db = -1.0)
├── Music          volume de départ : -6 dB
└── SFX            volume de départ :  0 dB   (bouton de réglage global des effets)
    ├── SFX_Alert      0 dB   alertes, danger, annonces d'événements
    ├── SFX_Stinger    0 dB   jingles de début et de fin de journée
    ├── SFX_Feedback   0 dB   retours de gameplay importants
    ├── SFX_Action     0 dB   actions fréquentes et discrètes, interface
    └── SFX_Loops      0 dB   grésillements et feu
```

- Les niveaux **relatifs** entre sons sont déjà réglés par le `volume_db` de chaque lecteur (§7). Les sous-bus restent à 0 dB : ils servent au **ducking** (baisser un groupe pendant qu'un autre parle) et à de futurs curseurs de volume.
- Le GDD indique « Settings : volume pour l'instant ». Brancher le curseur de volume sur `Master` (`linear_to_db`). Pour plus tard : un curseur Musique (bus `Music`) et un curseur Effets (bus `SFX`).
- Le `Limiter` sur Master est un filet de sécurité contre l'écrêtage quand beaucoup de sons se superposent. Ce n'est pas un outil de mixage : si le limiter travaille en permanence, baisser le bus `SFX` de quelques dB.

## 4. Musique : MainTheme.mp3

- Jouée **pendant toute la partie**, sur le bus `Music`, en boucle, sans redémarrer entre les journées de la semaine. `process_mode = Always` pour qu'elle ne s'arrête pas quand le jeu est en pause.
- **Raccord de boucle** : le MP3 ajoute un petit silence au début et à la fin, ce qui crée un trou audible à chaque boucle. Convertir `MainTheme.mp3` en **OGG Vorbis** (et activer `loop`), ou vérifier qu'il boucle proprement. Si la boucle est de toute façon longue (plusieurs minutes), ce défaut est négligeable.
- **Fondu d'entrée** de 1 s au début de la partie, fondu de sortie de 1 s au Game Over définitif ou au retour au menu.
- **Pause** : baisser `Music` de 6 dB et ajouter temporairement un `AudioEffectLowPassFilter` (cutoff 1200 Hz) pour un effet « étouffé » ; retirer à la reprise. Les boucles de grésillement et de feu sont mises en pause (`stream_paused = true`).
- **Récap de fin de journée** : `Music` baissée de 6 dB pendant le récap pour laisser la place aux jingles et aux étoiles.
- **Hypothèse de mixage** : le niveau de `MainTheme.mp3` n'a pas pu être mesuré. Les volumes de ce document supposent une musique masterisée « normalement », autour de -14 LUFS (niveau courant d'un MP3 du commerce). Avec `Music` à -6 dB, la musique tourne alors autour de -20 dBFS RMS. Si la musique est nettement plus forte ou plus faible, **ajuster uniquement le bus `Music`**, pas chaque son (voir le protocole de calibration, §8).

## 5. Règles de mixage

### 5.1 Hiérarchie des niveaux (tiers)

Le but : que le joueur entende d'abord ce qui est urgent, puis ce qui récompense, et que tout ce qui se répète reste sous la musique. Les cibles sont des niveaux RMS, mesurés sur chaque fichier :

| Tier | Rôle | Niveau cible RMS | Position par rapport à la musique (à -20 dBFS) | Bus |
|---|---|---|---|---|
| A | Danger et annonces : ce qu'il ne faut jamais rater | -18 dBFS | environ +2 dB au-dessus | `SFX_Alert` |
| J | Jingles de début et de fin de journée | -20 dBFS | au niveau de la musique, qui est baissée pendant ce temps | `SFX_Stinger` |
| B | Retours de gameplay qui récompensent ou informent | -23 dBFS | environ 3 dB sous la musique, bien audibles | `SFX_Feedback` |
| C | Actions fréquentes (pas, prises, dépôts, interface) | -29 dBFS | environ 9 dB sous la musique, présents sans fatiguer | `SFX_Action` |
| L | Boucles d'ambiance (grésillement, feu) | -35 dBFS | environ 15 dB sous la musique, un fond de cuisine | `SFX_Loops` |

Écart A à C : 11 dB. C'est volontaire : un écart de 10 dB est perçu comme « deux fois moins fort ». Les sons les plus fréquents du jeu (pas, prises) sont ainsi les plus discrets.

### 5.2 Ce qui se superpose en même temps (analyse du pire cas)

Les moments les plus chargés du GDD, et comment les contenir :

- **Vendredi, 4 joueurs** : 4 joueurs qui bougent (pas), des cuissons en cours (2 boucles), des clients qui arrivent, une cloche, des bières lancées, des bulles de commande. Risque : un mur de petits sons. Réponse : limite de voix par son, délai minimum entre deux déclenchements (colonnes `Voix max` et `Délai min`), atténuation des pas en multi (§5.5), boucles agrégées (§5.3).
- **SDF en plein rush, avec un feu** : `event_announce`, `sdf_arrive`, `can_warning` (sifflement qui monte), `can_impact`, `player_stun`, `heart_lost`, `fire_ignite`, `fire_loop`, extincteur. Tous de tier A ou B, donc audibles : c'est le seul moment où la hiérarchie des niveaux est vraiment sollicitée. Réponse : ducking de la musique et des boucles (§5.4), et jamais plus de 2 sons de tier A en même temps (le plus ancien est coupé).
- **Mi-temps des Diables Rouges** : 6 clients en 20 s, soit 6 `customer_arrive` (cloche de 1,6 s) qui se chevauchent. Réponse : `customer_arrive` limité à 1 déclenchement par 700 ms et 2 voix.
- **Groupe de collègues** : `event_success` + `group_toast` + `group_cheer` + `order_served` quasi simultanés. Réponse : les décaler dans le temps (§6) plutôt que les jouer ensemble.
- **Alerte de jauge** : `gauge_alert` et `gauge_warning` clignotent plusieurs fois par seconde, sur jusqu'à 4 zones. Réponse : délai minimum de 150 à 200 ms et 3 voix maximum. Ce sont des sons très aigus et courts, volontairement pas trop forts malgré leur rôle.

### 5.3 Boucles agrégées (grésillement et feu)

Ne pas créer une boucle par zone de cuisson. Une seule instance par boucle, dont le volume dépend du nombre de zones actives :

- 0 zone active : fondu de sortie de 0,3 s puis arrêt.
- 1 zone : `volume_db` de la table.
- 2 zones ou plus : `volume_db` + 2 dB (maximum). Ne pas empiler au-delà, ça n'apporte rien et ça couvre le reste.
- Même règle pour `fire_loop` (+2 dB maximum quel que soit le nombre de feux).

### 5.4 Ducking (baisser un groupe pour laisser passer un autre)

| Déclencheur | Ce qui baisse | Quantité | Attaque, maintien, relâche |
|---|---|---|---|
| `event_announce` | `Music` | -6 dB | 0,1 s, 1,5 s, 0,8 s |
| `can_warning` | `SFX_Loops` | -6 dB | 0,05 s, 1,0 s, 0,4 s |
| `halftime_horn` | `Music` | -6 dB | 0,1 s, durée du son, 0,6 s |
| Jingles (`day_start`, `day_win`, `game_over`, `closing_bell`, `medal`) | `Music` | -10 dB | 0,1 s, durée du son, 0,8 s |
| Pause | `Music` | -6 dB + filtre passe-bas | 0,2 s |

Implémentation simple : un `Tween` sur le volume du bus (en gardant la référence du tween précédent pour le tuer si un nouveau ducking arrive). Variante plus propre : un `AudioEffectCompressor` sur le bus `Music` avec `sidechain = SFX_Alert`.

### 5.5 Multijoueur local (2 à 4 joueurs)

Plus il y a de joueurs, plus les mêmes sons se répètent :

- `step_a` et `step_b` : -3 dB par joueur au-delà de 2 (soit -3 dB à 3 joueurs, -6 dB à 4). Ne jouer un pas qu'une case sur deux à 4 joueurs.
- `item_pick`, `item_drop`, `beer_take` : -2 dB par joueur au-delà de 2.
- Le tier A et les jingles ne changent jamais, quel que soit le nombre de joueurs.
- Le cap global de **12 voix SFX simultanées** reste valable. Au-delà, couper d'abord les voix de tier C, puis B. Jamais A.

### 5.6 Spatialisation

- **Globaux, non spatialisés** : tier A, jingles, interface, annonces. Le joueur doit les entendre pareil quelle que soit sa position.
- **Panoramique léger possible** pour les actions de cuisine (tier C et certains B) selon la position de la zone ou du joueur à l'écran : amplitude maximale de ±0,3. Beaucoup de téléphones ont un seul haut-parleur : ne jamais compter sur le stéréo pour l'information importante.
- Les basses (`step`, `heart_lost`, `trash_flap`, `fridge_blackout`) sont peu restituées par les haut-parleurs de téléphone : elles paraîtront plus faibles que sur un casque. Ne pas compenser sur le casque, ça saturerait.

### 5.7 Variations pour éviter l'effet répétitif

Appliquer un pitch aléatoire (colonne `Pitch ±`) à chaque déclenchement des sons très fréquents. Alterner `step_a` et `step_b`. Ne pas appliquer de pitch aléatoire aux sons d'information (`gauge_*`, `can_warning`, `order_*`, `combo_*`) : leur hauteur fait partie du message.

## 6. Séquences de déclenchement

Les décalages sont en millisecondes depuis l'événement. Ils servent à étaler les sons pour qu'ils restent lisibles.

**Cuisson**
1. Mise en cuisson : `fry_drop` (frites) ou `meat_drop` (viande) à 0, et démarrer la boucle correspondante (§5.3).
2. La jauge entre dans le vert : `cook_ready`.
3. Dernière seconde de vert : `gauge_alert` à chaque clignotement.
4. Zone rouge : `gauge_warning` à chaque clignotement (remplace `gauge_alert`).
5. Récupération de l'item : `basket_eject` à 0 puis `item_pick` à +80. Si centre du vert : `perfect_fry` à +150 puis `score_pop` à +350. Retirer la zone du compteur de boucle.
6. Feu : `fire_ignite` à 0, démarrer `fire_loop`, retirer la zone de cuisson du compteur de grésillement. Propagation : `fire_spread`. Extinction : `extinguisher_pickup`, puis `extinguisher_spray` pendant 2 s, puis `fire_out` à la fin du jet et arrêter `fire_loop` s'il n'y a plus de feu.
7. Raté jeté : `trash_flap`. Raté mangé : `eat_burnt` (le niveau de gourmandise monte, voir plus bas).

**Livraison à la caisse**
- Correcte : `order_served` à 0, puis `score_pop` à +120 si livraison rapide, puis `combo_1/2/3` à +250 si un palier de combo est atteint.
- Mauvaise : `order_wrong` à 0 (la patience baisse de 5 s).
- Client qui part furieux : `customer_angry`. Il peut tomber en même temps qu'un `order_served` pour un autre client : accepté, ce sont des tiers B.
- Arrivée d'un client : `customer_arrive` à 0 et `order_bubble` à +350.

**Bières et grosseur**
- Lancer : `throw_beer` à 0. Réception à +180 : `beer_give` (client), `drink_gulp` (coéquipier) ou `sdf_calmed` (SDF).
- Boisson depuis le frigo : `fridge_open` puis `beer_take` à +120 (ou `coke_take`).
- Gourmandise : à chaque passage de palier (fat01, fat02, fat03), jouer `fat_up` à +500 après le `drink_gulp` ou l'`eat_bite`. `burp` : tirage 1 chance sur 3 après une bière bue, à +400 du `drink_gulp`.
- 3e bière d'un client : `beer_give` puis `customer_sleep` à +400. `customer_wake` à la fin des 10 s.

**SDF (« Le Baraki »)**
- `event_announce` à 0, puis `sdf_arrive` à +1200 (quand il se place à la caisse).
- Canette : `can_throw` à 0, `can_warning` à +0 (le sifflement dure 1 s, comme l'ombre au sol), `can_impact` à +1000. Si un joueur est touché : `player_stun` à +1000 et `heart_lost` à +1050. Si le sol : `can_bounce` à +1100.
- Calmer le SDF : `throw_beer`, `sdf_calmed` à +180.
- Fin : `event_success` (servi) ou `event_fail` (raté).

**Groupe de collègues (« Le Vendredi »)**
- `event_announce` à 0. Pendant les 20 s de frigo ×2, `fridge_regen` à chaque bière régénérée (plus fréquent).
- Livraison : `order_served` à 0, `event_success` à +300, `group_cheer` à +600. S'il reste une bière : `group_toast` à +1100 (au lieu de `group_cheer` seul, ne pas jouer les deux).
- Échec : `event_fail`.

**Autres événements**
- Mi-temps des Diables Rouges : `event_announce` puis `halftime_horn` à +1300.
- Contrôle AFSCA : `event_announce` puis `afsca_arrive` à +1300. Cuisine propre : `event_success`. Sinon : `event_fail`.
- Panne de frigo : `fridge_blackout` au début, `fridge_restore` à la fin des 25 s.

**Journée et récap**
- 18:00 : `day_start`. 04:00 : `closing_bell`.
- Récap : `day_win` (ou `game_over`) à 0, puis `star_earned` à +900, +1400, +1900 (une par étoile gagnée), puis `medal` après la dernière étoile + 500.
- `heart_gain` au moment où le cœur gagné apparaît.
- Boutons du récap : `ui_confirm` (Continuer la semaine) et `ui_back` (Home).

## 7. Table complète des sons

`volume_db` : à appliquer sur le lecteur du son (propriété `volume_db`). `Voix max` : nombre de lectures simultanées du même son. `Délai min` : intervalle minimal entre deux déclenchements du même son, en ms (0 = aucun). `Pitch ±` : variation aléatoire de `pitch_scale`.

| Fichier | Quand | Tier | Bus | volume_db | Voix max | Délai min | Pitch ± | Durée |
|---|---|---|---|---|---|---|---|---|
| `afsca_arrive` | Arrivée de l'inspecteur AFSCA | A | `SFX_Alert` | -8.0 | 2 | 0 | - | 1.31 s |
| `can_impact` | La canette touche un joueur ou le sol | A | `SFX_Alert` | -2.0 | 2 | 0 | 3 % | 0.50 s |
| `can_warning` | Ombre au sol, 1 s avant l'impact de la canette | A | `SFX_Alert` | -8.0 | 2 | 0 | - | 1.00 s |
| `event_announce` | Pop-up d'annonce d'un événement (SDF, groupe, mi-temps, AFSCA, panne) | A | `SFX_Alert` | -8.5 | 1 | 0 | - | 1.68 s |
| `fire_ignite` | Un feu démarre sur une zone | A | `SFX_Alert` | -4.0 | 2 | 150 | 3 % | 0.90 s |
| `fridge_blackout` | Début de la panne de frigo (25 s) | A | `SFX_Alert` | -7.0 | 2 | 0 | - | 0.90 s |
| `gauge_warning` | UX_Warning : zone rouge, feu imminent (à chaque clignotement) | A | `SFX_Alert` | -10.0 | 3 | 200 | - | 0.22 s |
| `halftime_horn` | Début de la mi-temps des Diables Rouges | A | `SFX_Alert` | -6.0 | 2 | 0 | - | 1.40 s |
| `heart_lost` | Perte d'un cœur (bonheur à 0 % ou canette) | A | `SFX_Alert` | -6.0 | 1 | 0 | - | 0.45 s |
| `player_stun` | Joueur touché par une canette (étourdi 1,2 s) | A | `SFX_Alert` | -4.0 | 2 | 0 | - | 1.04 s |
| `sdf_arrive` | Le SDF arrive et prend la caisse | A | `SFX_Alert` | -5.5 | 2 | 0 | - | 0.90 s |
| `closing_bell` | 04:00, fermeture de la friterie | J | `SFX_Stinger` | -6.5 | 1 | 0 | - | 3.20 s |
| `day_start` | Début de journée (18:00) | J | `SFX_Stinger` | -7.5 | 1 | 0 | - | 1.16 s |
| `day_win` | Récap : journée gagnée | J | `SFX_Stinger` | -5.5 | 1 | 0 | - | 1.72 s |
| `game_over` | Récap : plus aucun cœur | J | `SFX_Stinger` | -8.5 | 1 | 0 | - | 1.86 s |
| `medal` | Médaille affichée au récap | J | `SFX_Stinger` | -5.5 | 1 | 0 | - | 1.50 s |
| `star_earned` | Chaque étoile révélée au récap (une par 0,5 s) | J | `SFX_Stinger` | -5.0 | 1 | 0 | - | 0.87 s |
| `beer_give` | Un client reçoit une bière (donnée ou lancée) | B | `SFX_Feedback` | -11.0 | 3 | 100 | 3 % | 0.45 s |
| `burp` | Rot, optionnel : 1 fois sur 3 après une bière bue | B | `SFX_Feedback` | -13.0 | 3 | 0 | - | 0.55 s |
| `can_bounce` | Canette vide qui rebondit au sol après l'impact | B | `SFX_Feedback` | -6.5 | 3 | 0 | - | 0.76 s |
| `can_throw` | Le SDF lance une canette | B | `SFX_Feedback` | -10.0 | 3 | 0 | - | 0.35 s |
| `combo_1` | Combo de 3 clients d'affilée | B | `SFX_Feedback` | -9.5 | 1 | 0 | - | 0.57 s |
| `combo_2` | Combo de 5 clients d'affilée | B | `SFX_Feedback` | -10.0 | 1 | 0 | - | 0.64 s |
| `combo_3` | Combo de 8 clients d'affilée | B | `SFX_Feedback` | -10.0 | 1 | 0 | - | 0.71 s |
| `cook_ready` | La jauge entre dans la zone verte | B | `SFX_Feedback` | -8.0 | 3 | 0 | - | 0.60 s |
| `customer_angry` | Client qui part furieux (-20, bonheur -15 %) | B | `SFX_Feedback` | -11.0 | 3 | 0 | - | 1.00 s |
| `customer_arrive` | Un client entre dans la friterie | B | `SFX_Feedback` | -8.0 | 2 | 700 | 2 % | 1.65 s |
| `customer_sleep` | 3e bière : le client s'endort (jouer au début du sommeil) | B | `SFX_Feedback` | -8.5 | 3 | 0 | - | 1.70 s |
| `customer_wake` | Le client se réveille | B | `SFX_Feedback` | -12.0 | 3 | 0 | - | 0.28 s |
| `drink_gulp` | Un joueur boit une bière lancée par un coéquipier | B | `SFX_Feedback` | -12.5 | 2 | 100 | 3 % | 0.60 s |
| `event_fail` | SDF ou groupe raté (-50), AFSCA raté | B | `SFX_Feedback` | -10.5 | 3 | 0 | - | 1.92 s |
| `event_success` | SDF ou groupe servi (+100), AFSCA validé (+50) | B | `SFX_Feedback` | -10.0 | 3 | 0 | - | 1.69 s |
| `extinguisher_pickup` | Zone 12, extincteur pris | B | `SFX_Feedback` | -9.5 | 3 | 0 | - | 0.15 s |
| `extinguisher_spray` | Jet de l'extincteur (2 s, calé sur la durée du jeu) | B | `SFX_Feedback` | -12.0 | 1 | 0 | - | 2.00 s |
| `fat_up` | Passage à un palier de grosseur supérieur (fat01 à fat03) | B | `SFX_Feedback` | -9.0 | 3 | 0 | - | 0.58 s |
| `fire_out` | Feu éteint | B | `SFX_Feedback` | -6.5 | 3 | 0 | - | 0.80 s |
| `fire_spread` | Le feu gagne une zone adjacente (après 8 s) | B | `SFX_Feedback` | -9.0 | 2 | 150 | 3 % | 0.50 s |
| `fire_watch` | Ceinture de sécurité : la jauge est figée 2 s | B | `SFX_Feedback` | -8.5 | 3 | 0 | - | 0.68 s |
| `fridge_restore` | Fin de la panne de frigo | B | `SFX_Feedback` | -9.5 | 3 | 0 | - | 1.20 s |
| `gauge_alert` | UX_Alert : dernière seconde de vert (à chaque clignotement) | B | `SFX_Feedback` | -15.5 | 3 | 150 | - | 0.09 s |
| `group_cheer` | Le groupe de collègues acclame (livraison réussie) | B | `SFX_Feedback` | -6.0 | 3 | 0 | - | 1.80 s |
| `group_toast` | Il reste au moins 1 bière au frigo : le groupe trinque (+25) | B | `SFX_Feedback` | -5.0 | 3 | 0 | - | 1.85 s |
| `heart_gain` | +1 cœur en fin de journée | B | `SFX_Feedback` | -10.0 | 3 | 0 | - | 0.74 s |
| `order_served` | Zone 8, commande livrée et correcte (+20) | B | `SFX_Feedback` | -8.0 | 3 | 100 | 2 % | 0.95 s |
| `order_wrong` | Zone 8, mauvais item refusé (patience -5 s) | B | `SFX_Feedback` | -13.5 | 3 | 0 | - | 0.37 s |
| `perfect_fry` | Frite sortie au centre du vert (+5) | B | `SFX_Feedback` | -9.0 | 3 | 0 | - | 0.70 s |
| `sdf_calmed` | Bière lancée sur le SDF : calme pendant 20 s | B | `SFX_Feedback` | -12.0 | 3 | 0 | - | 0.78 s |
| `slip` | Sol glissant (mécanique proposée §12) | B | `SFX_Feedback` | -12.0 | 3 | 0 | - | 0.50 s |
| `throw_beer` | Lancer de bière par un joueur | B | `SFX_Feedback` | -9.0 | 3 | 0 | - | 0.35 s |
| `basket_eject` | Le panier éjecte l'item cuit | C | `SFX_Action` | -17.0 | 2 | 100 | 4 % | 0.30 s |
| `beer_take` | Une bière prise au frigo | C | `SFX_Action` | -14.5 | 2 | 80 | 4 % | 0.30 s |
| `bread_pick` | Zone 7, pain pris | C | `SFX_Action` | -15.0 | 2 | 80 | 5 % | 0.12 s |
| `coke_take` | Un Coca pris | C | `SFX_Action` | -13.5 | 4 | 0 | - | 0.82 s |
| `eat_bite` | Un joueur mange une frite ou une viande | C | `SFX_Action` | -14.5 | 2 | 100 | 4 % | 0.48 s |
| `eat_burnt` | Un joueur mange un item cramé (+2 gourmandise) | C | `SFX_Action` | -14.0 | 4 | 0 | - | 0.57 s |
| `fridge_open` | Interaction zone 1 (frigo) | C | `SFX_Action` | -15.0 | 4 | 0 | - | 0.63 s |
| `fridge_regen` | Une bière régénérée (toutes les 12 s, ou 6 s avant le groupe) | C | `SFX_Action` | -17.0 | 1 | 500 | - | 0.38 s |
| `fry_drop` | Lancement d'une cuisson de frites (1re ou 2e) | C | `SFX_Action` | -13.5 | 4 | 0 | - | 1.40 s |
| `item_drop` | Poser ou déposer un item dans une zone | C | `SFX_Action` | -18.0 | 2 | 60 | 4 % | 0.09 s |
| `item_pick` | Prendre un item (zones 2, 3, 4, 5, 7, 10, 11) | C | `SFX_Action` | -19.0 | 2 | 60 | 4 % | 0.09 s |
| `meat_drop` | Viande mise dans un bac (zones 4-5) | C | `SFX_Action` | -14.0 | 4 | 0 | - | 1.00 s |
| `order_bubble` | La bulle de commande apparaît au-dessus du client | C | `SFX_Action` | -18.5 | 3 | 120 | 4 % | 0.12 s |
| `pause_off` | Reprise du jeu | C | `SFX_Action` | -16.5 | 4 | 0 | - | 0.18 s |
| `pause_on` | Entrée en pause | C | `SFX_Action` | -17.0 | 4 | 0 | - | 0.18 s |
| `sauce_squirt` | Zone 9, sauce ajoutée | C | `SFX_Action` | -14.5 | 2 | 100 | 4 % | 0.40 s |
| `score_pop` | Petit bonus : livraison rapide, frite parfaite (+5) | C | `SFX_Action` | -15.5 | 4 | 0 | - | 0.47 s |
| `step_a` | Pas du joueur (alterner avec step_b) | C | `SFX_Action` | -18.0 | 2 | 160 | 4 % | 0.08 s |
| `step_b` | Pas du joueur (alterner avec step_a) | C | `SFX_Action` | -18.0 | 2 | 160 | 4 % | 0.08 s |
| `trash_flap` | Zone 6, item jeté (ou raté jeté) | C | `SFX_Action` | -17.5 | 4 | 0 | - | 0.30 s |
| `ui_back` | Retour, bouton Home | C | `SFX_Action` | -17.0 | 4 | 0 | - | 0.30 s |
| `ui_click` | Tout bouton de menu | C | `SFX_Action` | -18.5 | 2 | 40 | - | 0.06 s |
| `ui_confirm` | Valider : Jouer, Continuer la semaine | C | `SFX_Action` | -16.5 | 4 | 0 | - | 0.37 s |
| `ui_error` | Action impossible : frigo vide, stock de frites plein, item refusé | C | `SFX_Action` | -17.0 | 4 | 0 | - | 0.30 s |
| `veg_add` | Zones 10-11, légumes ajoutés au burger | C | `SFX_Action` | -13.5 | 2 | 80 | 5 % | 0.27 s |
| `fire_loop` | BOUCLE : au moins un feu actif | L | `SFX_Loops` | -20.5 | 1 | 0 | - | 2.05 s |
| `fry_sizzle_loop` | BOUCLE : au moins une cuisson de frites active | L | `SFX_Loops` | -21.5 | 1 | 0 | - | 2.05 s |
| `meat_sizzle_loop` | BOUCLE : au moins une viande en cuisson | L | `SFX_Loops` | -21.0 | 1 | 0 | - | 2.05 s |

## 8. Calibration et tests de mixage

Les niveaux ci-dessus sont une **base de départ**, comme les chiffres de gameplay du GDD. À valider à l'oreille sur un vrai téléphone, haut-parleur et casque.

1. **Musique seule** : jouer `MainTheme.mp3` avec `Music` à -6 dB, volume du téléphone à environ 60 %. Régler `Music` pour que ce soit confortable en jouant (entre -10 et -3 dB selon la masterisation du fichier).
2. **Test de référence** : jouer la musique avec `order_served` (tier B) puis `can_warning` (tier A). `order_served` doit être clairement audible sans couvrir la musique ; `can_warning` doit passer au-dessus. Si les deux sont noyés ou trop forts, déplacer le bus `SFX` de ±3 dB (un seul réglage, pas tous les sons).
3. **Test du chaos** : lancer un scénario maximal (4 joueurs, 2 cuissons, un feu, le SDF qui lance des canettes, une rafale de clients). Surveiller le vumètre de `Master` : les crêtes doivent rester sous -3 dBFS la plupart du temps. Si le limiter est constamment sollicité, baisser `SFX` de 2 à 3 dB.
4. **Test des sons fréquents** : jouer 5 minutes en continu. Si les pas, prises ou clics deviennent pénibles, baisser le tier C de 2 dB (modifier la cible, pas chaque fichier). Si on ne les entend plus du tout, remonter de 2 dB.
5. **Test en pause et au récap** : la musique doit s'étouffer en pause, se baisser au récap, et les jingles doivent rester lisibles.
6. **Test du silence** : après quelques minutes, vérifier que les boucles s'arrêtent bien quand plus aucune cuisson ni aucun feu n'est actif (une boucle qui reste coincée est le bug le plus fréquent).

## 9. Squelette GDScript (Godot 4.x), à adapter

À placer dans un autoload nommé `Audio`. Cette base crée un lecteur par son (avec `max_polyphony` pour les voix), applique les volumes de la table et gère les boucles et le ducking.

```gdscript
extends Node

const DIR := "res://audio/Sounds/"   # adapter au chemin réel du dossier Sounds
const MUSIC_DB := -6.0

# nom: { bus, db, voices (max_polyphony), cd (ms), pitch (±) }
const SFX := {
	"afsca_arrive": {"bus": "SFX_Alert", "db": -8.0, "voices": 2, "cd": 0, "pitch": 0},
	"can_impact": {"bus": "SFX_Alert", "db": -2.0, "voices": 2, "cd": 0, "pitch": 0.03},
	"can_warning": {"bus": "SFX_Alert", "db": -8.0, "voices": 2, "cd": 0, "pitch": 0},
	"event_announce": {"bus": "SFX_Alert", "db": -8.5, "voices": 1, "cd": 0, "pitch": 0},
	"fire_ignite": {"bus": "SFX_Alert", "db": -4.0, "voices": 2, "cd": 150, "pitch": 0.03},
	"fridge_blackout": {"bus": "SFX_Alert", "db": -7.0, "voices": 2, "cd": 0, "pitch": 0},
	"gauge_warning": {"bus": "SFX_Alert", "db": -10.0, "voices": 3, "cd": 200, "pitch": 0},
	"halftime_horn": {"bus": "SFX_Alert", "db": -6.0, "voices": 2, "cd": 0, "pitch": 0},
	"heart_lost": {"bus": "SFX_Alert", "db": -6.0, "voices": 1, "cd": 0, "pitch": 0},
	"player_stun": {"bus": "SFX_Alert", "db": -4.0, "voices": 2, "cd": 0, "pitch": 0},
	"sdf_arrive": {"bus": "SFX_Alert", "db": -5.5, "voices": 2, "cd": 0, "pitch": 0},
	"closing_bell": {"bus": "SFX_Stinger", "db": -6.5, "voices": 1, "cd": 0, "pitch": 0},
	"day_start": {"bus": "SFX_Stinger", "db": -7.5, "voices": 1, "cd": 0, "pitch": 0},
	"day_win": {"bus": "SFX_Stinger", "db": -5.5, "voices": 1, "cd": 0, "pitch": 0},
	"game_over": {"bus": "SFX_Stinger", "db": -8.5, "voices": 1, "cd": 0, "pitch": 0},
	"medal": {"bus": "SFX_Stinger", "db": -5.5, "voices": 1, "cd": 0, "pitch": 0},
	"star_earned": {"bus": "SFX_Stinger", "db": -5.0, "voices": 1, "cd": 0, "pitch": 0},
	"beer_give": {"bus": "SFX_Feedback", "db": -11.0, "voices": 3, "cd": 100, "pitch": 0.03},
	"burp": {"bus": "SFX_Feedback", "db": -13.0, "voices": 3, "cd": 0, "pitch": 0},
	"can_bounce": {"bus": "SFX_Feedback", "db": -6.5, "voices": 3, "cd": 0, "pitch": 0},
	"can_throw": {"bus": "SFX_Feedback", "db": -10.0, "voices": 3, "cd": 0, "pitch": 0},
	"combo_1": {"bus": "SFX_Feedback", "db": -9.5, "voices": 1, "cd": 0, "pitch": 0},
	"combo_2": {"bus": "SFX_Feedback", "db": -10.0, "voices": 1, "cd": 0, "pitch": 0},
	"combo_3": {"bus": "SFX_Feedback", "db": -10.0, "voices": 1, "cd": 0, "pitch": 0},
	"cook_ready": {"bus": "SFX_Feedback", "db": -8.0, "voices": 3, "cd": 0, "pitch": 0},
	"customer_angry": {"bus": "SFX_Feedback", "db": -11.0, "voices": 3, "cd": 0, "pitch": 0},
	"customer_arrive": {"bus": "SFX_Feedback", "db": -8.0, "voices": 2, "cd": 700, "pitch": 0.02},
	"customer_sleep": {"bus": "SFX_Feedback", "db": -8.5, "voices": 3, "cd": 0, "pitch": 0},
	"customer_wake": {"bus": "SFX_Feedback", "db": -12.0, "voices": 3, "cd": 0, "pitch": 0},
	"drink_gulp": {"bus": "SFX_Feedback", "db": -12.5, "voices": 2, "cd": 100, "pitch": 0.03},
	"event_fail": {"bus": "SFX_Feedback", "db": -10.5, "voices": 3, "cd": 0, "pitch": 0},
	"event_success": {"bus": "SFX_Feedback", "db": -10.0, "voices": 3, "cd": 0, "pitch": 0},
	"extinguisher_pickup": {"bus": "SFX_Feedback", "db": -9.5, "voices": 3, "cd": 0, "pitch": 0},
	"extinguisher_spray": {"bus": "SFX_Feedback", "db": -12.0, "voices": 1, "cd": 0, "pitch": 0},
	"fat_up": {"bus": "SFX_Feedback", "db": -9.0, "voices": 3, "cd": 0, "pitch": 0},
	"fire_out": {"bus": "SFX_Feedback", "db": -6.5, "voices": 3, "cd": 0, "pitch": 0},
	"fire_spread": {"bus": "SFX_Feedback", "db": -9.0, "voices": 2, "cd": 150, "pitch": 0.03},
	"fire_watch": {"bus": "SFX_Feedback", "db": -8.5, "voices": 3, "cd": 0, "pitch": 0},
	"fridge_restore": {"bus": "SFX_Feedback", "db": -9.5, "voices": 3, "cd": 0, "pitch": 0},
	"gauge_alert": {"bus": "SFX_Feedback", "db": -15.5, "voices": 3, "cd": 150, "pitch": 0},
	"group_cheer": {"bus": "SFX_Feedback", "db": -6.0, "voices": 3, "cd": 0, "pitch": 0},
	"group_toast": {"bus": "SFX_Feedback", "db": -5.0, "voices": 3, "cd": 0, "pitch": 0},
	"heart_gain": {"bus": "SFX_Feedback", "db": -10.0, "voices": 3, "cd": 0, "pitch": 0},
	"order_served": {"bus": "SFX_Feedback", "db": -8.0, "voices": 3, "cd": 100, "pitch": 0.02},
	"order_wrong": {"bus": "SFX_Feedback", "db": -13.5, "voices": 3, "cd": 0, "pitch": 0},
	"perfect_fry": {"bus": "SFX_Feedback", "db": -9.0, "voices": 3, "cd": 0, "pitch": 0},
	"sdf_calmed": {"bus": "SFX_Feedback", "db": -12.0, "voices": 3, "cd": 0, "pitch": 0},
	"slip": {"bus": "SFX_Feedback", "db": -12.0, "voices": 3, "cd": 0, "pitch": 0},
	"throw_beer": {"bus": "SFX_Feedback", "db": -9.0, "voices": 3, "cd": 0, "pitch": 0},
	"basket_eject": {"bus": "SFX_Action", "db": -17.0, "voices": 2, "cd": 100, "pitch": 0.04},
	"beer_take": {"bus": "SFX_Action", "db": -14.5, "voices": 2, "cd": 80, "pitch": 0.04},
	"bread_pick": {"bus": "SFX_Action", "db": -15.0, "voices": 2, "cd": 80, "pitch": 0.05},
	"coke_take": {"bus": "SFX_Action", "db": -13.5, "voices": 4, "cd": 0, "pitch": 0},
	"eat_bite": {"bus": "SFX_Action", "db": -14.5, "voices": 2, "cd": 100, "pitch": 0.04},
	"eat_burnt": {"bus": "SFX_Action", "db": -14.0, "voices": 4, "cd": 0, "pitch": 0},
	"fridge_open": {"bus": "SFX_Action", "db": -15.0, "voices": 4, "cd": 0, "pitch": 0},
	"fridge_regen": {"bus": "SFX_Action", "db": -17.0, "voices": 1, "cd": 500, "pitch": 0},
	"fry_drop": {"bus": "SFX_Action", "db": -13.5, "voices": 4, "cd": 0, "pitch": 0},
	"item_drop": {"bus": "SFX_Action", "db": -18.0, "voices": 2, "cd": 60, "pitch": 0.04},
	"item_pick": {"bus": "SFX_Action", "db": -19.0, "voices": 2, "cd": 60, "pitch": 0.04},
	"meat_drop": {"bus": "SFX_Action", "db": -14.0, "voices": 4, "cd": 0, "pitch": 0},
	"order_bubble": {"bus": "SFX_Action", "db": -18.5, "voices": 3, "cd": 120, "pitch": 0.04},
	"pause_off": {"bus": "SFX_Action", "db": -16.5, "voices": 4, "cd": 0, "pitch": 0},
	"pause_on": {"bus": "SFX_Action", "db": -17.0, "voices": 4, "cd": 0, "pitch": 0},
	"sauce_squirt": {"bus": "SFX_Action", "db": -14.5, "voices": 2, "cd": 100, "pitch": 0.04},
	"score_pop": {"bus": "SFX_Action", "db": -15.5, "voices": 4, "cd": 0, "pitch": 0},
	"step_a": {"bus": "SFX_Action", "db": -18.0, "voices": 2, "cd": 160, "pitch": 0.04},
	"step_b": {"bus": "SFX_Action", "db": -18.0, "voices": 2, "cd": 160, "pitch": 0.04},
	"trash_flap": {"bus": "SFX_Action", "db": -17.5, "voices": 4, "cd": 0, "pitch": 0},
	"ui_back": {"bus": "SFX_Action", "db": -17.0, "voices": 4, "cd": 0, "pitch": 0},
	"ui_click": {"bus": "SFX_Action", "db": -18.5, "voices": 2, "cd": 40, "pitch": 0},
	"ui_confirm": {"bus": "SFX_Action", "db": -16.5, "voices": 4, "cd": 0, "pitch": 0},
	"ui_error": {"bus": "SFX_Action", "db": -17.0, "voices": 4, "cd": 0, "pitch": 0},
	"veg_add": {"bus": "SFX_Action", "db": -13.5, "voices": 2, "cd": 80, "pitch": 0.05},
	"fire_loop": {"bus": "SFX_Loops", "db": -20.5, "voices": 1, "cd": 0, "pitch": 0},
	"fry_sizzle_loop": {"bus": "SFX_Loops", "db": -21.5, "voices": 1, "cd": 0, "pitch": 0},
	"meat_sizzle_loop": {"bus": "SFX_Loops", "db": -21.0, "voices": 1, "cd": 0, "pitch": 0},
}

var _players := {}
var _last := {}
var _duck_tween: Tween
var player_count := 1   # 1 à 4, utilisé pour atténuer les sons répétitifs (§5.5)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for n in SFX:
		var d: Dictionary = SFX[n]
		var p := AudioStreamPlayer.new()
		p.stream = load(DIR + n + ".wav")
		p.bus = d.bus
		p.volume_db = d.db
		p.max_polyphony = d.voices
		add_child(p)
		_players[n] = p

func play(n: String, extra_db := 0.0) -> void:
	var d: Dictionary = SFX[n]
	var now := Time.get_ticks_msec()
	if now - _last.get(n, -100000) < d.cd:
		return
	_last[n] = now
	var p: AudioStreamPlayer = _players[n]
	p.volume_db = d.db + extra_db
	p.pitch_scale = 1.0 + randf_range(-d.pitch, d.pitch)
	p.play()

# Boucles : appeler avec le nombre de zones actives (0 = arrêt)
func set_loop(n: String, active_zones: int) -> void:
	var p: AudioStreamPlayer = _players[n]
	if active_zones <= 0:
		p.stop()
		return
	p.volume_db = SFX[n].db + (2.0 if active_zones >= 2 else 0.0)
	if not p.playing:
		p.play()

func duck_music(db: float, hold: float, attack := 0.1, release := 0.8) -> void:
	var bus := AudioServer.get_bus_index("Music")
	if _duck_tween:
		_duck_tween.kill()
	_duck_tween = create_tween()
	_duck_tween.tween_method(func(v): AudioServer.set_bus_volume_db(bus, v), AudioServer.get_bus_volume_db(bus), MUSIC_DB + db, attack)
	_duck_tween.tween_interval(hold)
	_duck_tween.tween_method(func(v): AudioServer.set_bus_volume_db(bus, v), MUSIC_DB + db, MUSIC_DB, release)
```

Exemples d'appel : `Audio.play("order_served")`, `Audio.set_loop("fry_sizzle_loop", nb_zones_frites_actives)`, `Audio.play("event_announce"); Audio.duck_music(-6.0, 1.5)`.

Les buses (`Music`, `SFX`, `SFX_Alert`, `SFX_Stinger`, `SFX_Feedback`, `SFX_Action`, `SFX_Loops`) doivent exister dans le Audio Bus Layout du projet, avec leurs sorties (« Send ») réglées comme au §3. Ajouter à la main : le `Limiter` sur `Master`, le muet de boucles en pause (`stream_paused`), le filtre passe-bas de pause.

## 10. Ce qui n'est pas dans ce pack

- Aucune voix (ni clients, ni joueurs, ni annonceur). Les sons « organiques » (rot, ronflement, acclamation) sont des approximations synthétiques.
- Pas d'ambiance de fond de friterie (extérieur, voitures, frigo qui ronronne). Possible à ajouter en boucle à -38 dB environ (sous le tier L), mais pas nécessaire avec la musique.
- Pas de son pour les mécaniques du §12 du GDD autres que `slip` (plat du jour, faux départ de friture, client tapoté pour le réveiller). À ajouter si ces mécaniques sont retenues.
- Aucune mesure de `MainTheme.mp3` : son niveau n'a pas pu être analysé ici, d'où l'hypothèse du §4 à vérifier avec le protocole du §8.

