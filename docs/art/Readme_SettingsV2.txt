Info : Toutes les infos viennent d'un setup sur Unity Engine, il faudra donc voir le comparatif avec le moteur Godot. Ceci est une proposition d'aménagement des scènes avec quelques proposition de gameplay. Pour les gros changements de gameplay qui pourraient rentrer en conflit avec le gameplay déjà fait, demander à l'utilisateur avant changement.

Scene settings :
- Camera position world position sur Unity (A adapter si le x/y/z est différent sur Godot) : (x:-7.65 y:9.65 z:3.81) Rotation(x:40.6 y:121.334 z:0)
- Field of view de la caméra : 25
- Color background en solid color : DCF6FF

Mesh settings :
- DoubleCooked_Room01 en 0/0/0, rotation -90/0/0, scale 1/1/1
- DoubleCooked_Counter en 0.62/0/-1.968, rotation -90/0/0, scale 1/1/1
- DoubleCooked_DeepFryer en 3.34/0/-1, rotation -90/0/0, scale 1/1/1
- DoubleCooked_FireCase en 3.76/0.746/-3.89, rotation -90/0/0, scale 1/1/1
- DoubleCooked_Fridge en 3.45/0/0.89, rotation -90/0/0, scale 1/1/1
- DoubleCooked_Furniture en 3.33/0/-3.04, rotation -90/0/0, scale 1/1/1
- DoubleCooked_Furniture (1), donc un duplicata du précédent, mais en 0.616/0/0.047, rotation -90/0/0, scale 1/1/1
- DoubleCooked_Trash en 0.62/0/-3.865, rotation -90/0/0, scale 1/1/1
- DoubleCooked_CashRegister en 0.560999/0.456/-0.144, rotation -90/0/0, scale 1/1/1
- DoubleCooked_PaperBag en 0.625/0.457/0.354, rotation -90/0/0, scale 1/1/1
- DoubleCooked_BreadBag en 3.348/0.462/-3.041, rotation -90/0/0, scale 1/1/1

Gameplay info :
- Dans toute cette scène, se trouve du coup 11 zone d'actions
1 : Le frigo en 2.5/0/0.9
2 : Première cuisson des frites en 2.5/0/0 (Mesh FriesRaw toujours visible)
3 : Deuxième cuisson des frites en 2.5/0/-1 (Il y a 5 mesh FriesCooked01-05 qui seront masqué au lancement du jeu et après chaque première cuisson ça fait apparaitre 5 FriesCooked et qui se masque à chaque utilisation de la 2ème cuisson pour faire cuire une frite double cuisson)
4 : Cuisson des viandes en 2.5/0/-2
5 : Sac de pain à burger en 2.5/0/-3
6 : Exctincteur en 2.5/0/-3.9
7 : Poubelle en 1.5/0/-3.9
8 : Choisir une viande crue en 1.5/0/-3
9 : 2ème zone pour choisir une viande crue en 1.5/0/-2
10 : Sélection des sauces en 1.5/0/-1
11 : Donner la commande au client en 1.5/0/0
- C'est devant le cash register que les clients viennent chercher leur commande et font la file, donc en -0.25/0/0 de la scène, puis le prochain client qui fait le file se mettra en -0.25/0/-1, puis le prochain en -0.25/0/-2, puis en -0.25/0/3, puis en -1/0/-1, puis dehors de la friterie en -1.75/0/-1, puis -1.75/0/-2, puis -1.75/0/-3, puis -1.75/0/-4
Mais bien sur quand le client au tout début de la file voit sa commande achevé, terminé ou plus le temps et qu'il part, tous les clients qui font la file avance d'une place,...

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
- Le système de particules FryingOil se trouve à 4 endroits dans la scène
1 : 3.326/0.389/-2.158
2 : 3.339/0.389/-1.727
3 : 3.326/0.389/-1.005
4 : 3.326/0.389/-0.057
- Un système de particules Fire, texture sheet animation grid tiles 5/3, start size 1, emission 1 pour avoir une flamme en continu.
- Le système de particules Fire peuvent se trouver au-dessus de chaque zone d'action, donc toutes les zones où le joueur peut intéragir et qui peuvent prendre feu sauf l'endroit où prendre l'extincteur :
1 : 3.154/0.857/0.908
2 : 3.154/0.857/-0.06
3 : 3.154/0.857/-1.008
4 : 3.154/0.857/-3
5 : 0.6/0.86/-3.91
6 : 0.6/0.86/-2.918
7 : 0.6/0.86/-2.033
8 : 0.6/0.86/-1.005
9 : 0.6/0.86/-0.005

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
A jouer d'abord le Basket01 suivi par le Basket 02 quand on reprend la viande cuite dedans, mais ça reste une seule zone d'action.

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