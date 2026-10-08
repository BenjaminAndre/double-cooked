Info : Ceci est une proposition d'aménagement des scènes avec quelques proposition de gameplay. Pour les gros changements de gameplay qui pourraient rentrer en conflit avec le gameplay déjà fait, demander à l'utilisateur avant changement.

Scene settings :
- Post process : Vignette intensity 0.2, Color Adjustments post exposure 0.14, contrast 2, saturation 13

Meshes position :
- Il y a 3 fichiers .md avec un export de tous les objets de chaque scène à récupérer à analyser pour la position des objets. (SceneExport_DoubleCooked_SoloOrMulti2Players.md et SceneExport_DoubleCooked_Multi3Players.md et SceneExport_DoubleCooked_Multi4Players.md)

Scene gameplay info :
- Par exemple dans la scène Solo ou Multi 2 players, se trouve du coup 12 zone d'actions qui sont représentés par les cases avec un material untli transparent (FFFFFF alpha 60) et quand un personnage est dessus ça change la couleur de la case (FFF0D8 alpha 120)
1 : Le frigo avec animation de la porte quand on se place devant pour prendre quelque chose
2 : Première cuisson des frites (Mesh FriesRaw toujours visible, à volonté)
3 : Deuxième cuisson des frites (Il y a 5 mesh FriesCooked01-05 qui seront masqué au lancement du jeu et après chaque première cuisson ça fait apparaitre 5 FriesCooked et qui se masque à chaque utilisation de la 2ème cuisson pour faire cuire une frite double cuisson)
4 : Bac à cuisson des viandes 1 avec animation du basket quand on récupère une viande
5 : Bac à cuisson des viandes 2 avec animation du basket quand on récupère une viande
6 : Poubelle avec animation de la trappe quand on jette un objet
7 : Sac à pain à burger
8 : Donner la commande au client
9 : Sélection des sauces
10 : Choisir une viande crue
11 : 2ème zone pour choisir une viande crue
12 : Exctincteur
- C'est devant le cash register que les clients viennent chercher leur commande et font la file, donc en -0.25/0/0 de la scène, puis le prochain client qui fait le file se mettra en -0.25/0/-1, puis le prochain en -0.25/0/-2, puis en -0.25/0/-3, puis en -1/0/-1, puis dehors de la friterie en -1.75/0/-1, puis -1.75/0/-2, puis -1.75/0/-3, puis -1.75/0/-4
Mais bien sur quand le client au tout début de la file voit sa commande achevé, terminé ou plus le temps et qu'il part, tous les clients qui font la file avance d'une place,...
- Pour la scène multi 3 players ça reste la même chose juste qu'il y a une ligne de case en plus au milieu pour que les joueurs puissent se déplacer plus aisément, mais avec le même nombre d'actions possible. La file d'attente des clients est décalé du coup.
- Pour la scène multi 4 players il y a une colonne en plus avec un frigo supplémentaire et une caisse enregistreuse supplémentaire. La file d'attente des clients est décalée comme pour la scène multi 3 players.

Materials settings :
- Tous les materials sont en unlit, pas de lumière dans la scène
- DoubleCooked_Room01 a le material "GroundAtlas" avec la texture "GroundAtlas_BC"
- Tous les autres assets ont le material "PropsAtlas" avec la texture "PropsAtlas_BC"
SAUF les mesh avec _Glass (Donc le DoubleCooked_Counter_Glass et DoubleCooked_Fridge_Door_Glass) qui ont le material "Glass" en shader unlit/Transparent avec la texture Glass_Opacity
- Il y a aussi un material "Fire" en shader particles/standard unlit avec la texture FireSheet, avec un render queue plus élevé que le transparent glass pour qu'il soit au-dessus de tout objet dans la scène.
- Il y a aussi un material "FryingOil" en shader particles/standard unlit avec la texture FryingOilSheet
- Tous les mesh d'items existant BouletteCooked/raw, brochette, bread burger, bruger, cercelas, fricadelle, fries, sauces, coca, foledcan, jupiler utilisent le material PropsAtlas, on peut en faire des prefabs et les utiliser plus tard où sont utiliser quand le joueur lance l'objet dans le jeu. Par contre dans les menus d'utilisation des zones,.. Ca utilise bien la version png.

Particle System :
- Un système de particules FryingOil, texture sheet animation grid tiles 5/5, whole sheet, rotation over lifetime angular velocity 90, size over lifetime 0.5/1, color over lifetime transparency 0 au début à la fin 15% et 85% au milieu à 1, shape rectangle scale 0.3/0.2/0.2, emission 10, start size à 0.2, start speed à 0.05.
- Le système de particules FryingOil se trouve au-dessus des 4 zones de cuissons des frites et des viandes
- Un système de particules Fire, texture sheet animation grid tiles 5/3, start size 1, emission 1 pour avoir une flamme en continu.
- Le système de particules Fire peuvent se trouver au-dessus de chaque zone d'action, donc toutes les zones où le joueur peut intéragir et qui peuvent prendre feu sauf l'endroit où prendre l'extincteur.

Animation models frame :
- Fridge :
0 - 1 : idle close
1 - 10 : opening
10 - 11 : idle open
11 - 24 : closing

- Trash :
0 - 1 : idle close
1 - 10 : opening
10 - 11 : idle open
11 - 24 : closing

- Deep Fryer Basket :
0 - 1 : idle
1 - 30 : eject food

UX info :
- Il y a un écran de démarrage du jeu avec juste une image "MenuBackground" de fond qui prend toute la taille de l'écran.
Il y a le logo "Logo.png" qui en haut de l'écran, centré, qui a une taille de genre 30% de la hauteur de l'écran.
Il y a 2 boutons "UX_Button02.png" en-dessous du logo, aussi centré, l'un au-dessus de l'autre, l'un avec du texte blanc contour noir sur le boutton "Solo" qui lance une partie simple et l'autre avec un texte "Multi" qui lance le jeu en multi joueur. 
- Pour la scène de sélection de perso/accessoir,.. On peut réutiliser la même scène avec DoubleCooked_Room01, même vue caméra,... Juste sans les autres éléments counter,deepfryer,....
- Pour la scène ingame :
Les 3 coeurs seront placé en bas à gauche de l'écran (UX_Life et UX_LifeEmpty quand on perd un point de vie).
La jauge de bonheur des clients sera placé en bas à droite de l'écran avec le slider tout à gauche client pas content, tout à droite client content.
En haut à droite il y aura aligné l'un à la suite de l'autre en commencant à gauche le score avec UX_Scoreboard03 et du texte dessus en blanc, contour noir pour indiqué le score actuel, puis à droite UX_Time avec l'heure en texte blanc, contour noir.
En haut à gauche il y aura 3 boutons aligné l'un à la suite de l'autre en commençant par le bouton UX_Lose pour quitter la partie et revenir à l'écran de démarrage, puis le bouton UX_Retry pour recommencer la partie, puis le bouton UX_Pause pour mettre en pause le jeu avec un écran noir à 55% d'opacité et le même bouton UX_Pause en plus gros sur l'écran au milieu centré pour reprendre la partie.
- Après une partie finie (donc plus de vie), le jeu se met en pause, il y a un écran noir par-dessus le jeu à 55% d'opacité, la texture UX_Frame centré à l'écran avec par dessus un système d'étoiles UX_Star/StarEmpty, ainsi qu'un score écris en-dessous en texte blanc, contour noir et une médaille UX_Gold/Silver ou Bronze en fonction du système de point/score.
En-dessous de ce UX_Frame se trouve centrée et aligné 2 boutons UX_Home et UX_Retry pour soit retourner à l'écran de démarrage ou relancer la partie dans le mode où on était.

Gameplay supplémentaire :
- Quand un personnage player ou client avance à droite, la "texture" du personnage ne bouge pas, mais s'il se déplace à gauche, la texture du personne est mirroré pour donner l'impression qu'il aille bien dans l'autre sens.
- Chaque joueur à 4 niveau de "grosseur", normal, fat01, fat02, fat03 dans les textures qui change quand le joueur mange ou boit de trop,...
- Il y a une image pour chaque item de friterie en mode raw, cooked, burned et pour les frites, raw, firstcooked, doublecooked, burned.
- Pour faire un burger il faut cuire la viande à burger, puis aller chercher un pain burger pendant que la viande cuit et quand elle est cuite là on peut récupérer la viande et transformer les deux en burger fini. Si la viande est cramé ou crue, on ne peut pas la récupérer avec le pain. Mais si on récupère juste la viande a burger cuite et qu'on va chercher le pain, ça fonctionne aussi.
- Une petite icone au-dessus du frame de cuisson apparaitra juste en haut à droite du frame pour alerter que le timer est presque dépassé et va bruler l'aliment UX_Alert, une fois totalement dépassé et dans la zone rouge ou c'est cramé, l'icone se transforme en UX_Warning qui préviens que si la jauge se rempli ça lancera un feu. Ces 2 icones là "clignottent".
- Tous les personnages ainsi que les joueurs ont la même taille. Dans Unity tous les png sont en Sprite (2D and UI) à 750 pixels per unity, à voir comment c'est dans Godot.
- Il y a un event sdf qui demande une grosse commande avec le gameplay déjà prévu
- Il y a aussi un event "groupe de collègues d'entreprise" qui peut arriver, mais pas en même temps que le sdf. Il y a un groupe de clients qui attendent à l'extérieur (EventCharacter02.png -03 -04 -05 -06) et seulement le EventCharacter01.png fait la file comme les autres clients, c'est seulement lui qui prend la grosse commande pour tout le monde. Lui fait bien la file et ne dépasse pas. 
- Une icone pope et disparait après qu'un client ai eu sa commande ou pas, +20 points UX_Score20.png ou -20 points UX_ScoreM20.png ou pour le sdf "boss" ou l'évent "entreprise" +100 points UX_Score100.png.