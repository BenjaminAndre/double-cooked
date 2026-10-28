NOUVEAUX :
- Ajout des sons. Dans le dossier sons se trouvent tous les sons généré par IA avec un fichier texte pour la description des sons et comment les rajouter proprement.
- Vu que les sons ne sont pas de très bonne qualité, il faut impérativement rajouter une icone de son en jeu à côté des autres bouton play/pause/retry,... UX_Sound.png qui devient UX_SoundMute.png quand on veut mute le son.
- Un nouveau DrunkCharacter03 en plus pour plus de variante
- Des skins de chapeaux, casquette, casque à bière,... Pour la sélection de personnage, Hat01,02,03,04 qu'on pourra choisir à la place du casque à bière et de la casquette actuel sans skin. Ce ne sont pas des objets 3D, mais des sprites à mettre par dessus le personnage joueur au niveau de la tête.
- Deux nouveaux MainCharacter avec leur évolution, MainCharacter05 et 06. Mais toujours garder le nombre maximal de 4 joueurs en multi. Juste plus de choix de skin.
- Nouvelles boissons, Sprite (soda comme le coca) et Maes (même mécanique que la bière Jupiler)
- Nouvelle sauce riche
- Nouvelle viande grizzly
- Ajout mitraillette crudité
- Ajout mitraillette grizzly
- Ajout mitraillette grizzly crudité
- La mitraillette par défaut est à la sauce mayo, maintenant il y a l'ajout de toutes les mitraillettes que ça soit avec ou sans crudités, fricadelle ou grizzly, le choix de la sauce mayo (par défaut), ketchup, andalouse, riche
- Ajout icon player 01 -> 06 pour la sélection de personnage dans le menu, la tête de chaque perso associé sur un fond de couleur associé au personnage en quesiton
- Ajout du mesh DoubleCooked_SauceRiche.fbx
- Ajout FlyingBird.png et CrashedCar.png
- Ajout d'un model DoubleCooked_Phone (Material PropsAtlas) pour la scène de sélection des personnages/choix du multi
L'emplacement du téléphone "Multi" en 3.87/0/-2
- DoubleCooked_Locker (Material PropsAtlas), un vestiaire pour la scène de sélection des personnages, accesoires,... Remplacer le texte "Peinture" par "Skin" et "Casquette" par "Chapeau" et "Téléphone" par "Multi".
Le locker a une porte animé avec les même frame que la porte du frigo
Il y a 2 emplacements des lockers, le "Skin" en 3.683/0/0, le 2ème "Chapeau" en 3.683/0/-1

MODIFICATIONS : 
- Item baguette png à été changé par une nouvelle version
- DoubleCooked_Room01.fbx et 02 et 03 ont été modifiés sans changement important, juste rajouter de la géométrie sur les côtés pour éviter de voir le vide sur d'autres résolution d'écran, sans changer le pivot ou quoi, aucune modification à faire dans la scène
- La texture PropsAtlas_BC.png a été modifié
- Modifs du mesh, juste changement visuel, DoubleCooked_Coca.fbx, DoubleCooked_Counter.fbx, DoubleCooked_FoledCan.fbx, DoubleCooked_Jupiler.fbx, 
- Modifs du mesh DoubleCooked_Fridge.fbx avec en enfant les nouvelles bières Maes au nombre de 5 comme les bières jupiler initial, donc même fonctionne que la jupiler dans la mécanique du jeu

ANIMATIONS :
Propositions d'animations pour rajouter du feedback au joueur.
- Quand on lance une bière à quelqu'un, quand il la reçoit faire pivoter le perso légèrement en rotation avec son point de pivot au pied pour avoir un effet de "coup reçu"
- Au même moment que le hit de la bière sur un client ou un joueur, ça fait également jouer un système de particules avec Particle_BeerDrop.png, une goute en png unique, sans sheet, start size random entre 0.08 et 0.12, start speed 0.5, start lifetime 0.5, emission burst 8, shape sphere radius 0.2, force over lifetime à -4 en Y world (unity), color over lifetime fade start et end
- Quand un client dort, au lieu d'affiché l'icone EtatZzzzz, jouer un système de particules avec Particle_Z.png qui spawn tout petit vers le haut du personnage et l'icone Z qui grandit jusqu'à disparaitre et avoir plusieurs petit Z qui spawn pour avoir l'effet Zzzz en particules.
- Quand un client a eu sa commande, lancer un système de particules qui fait spawn des billets sur lui en "explosion" avec le png MoneySheet.png en grille de 3x3 un billet random de cette sheet avec une rotation overlifetime et qui s'efface en fade, une émission de 20 particules en bursts avec une shape sphere petite de 0.2, un starte size a 0.3 et une start speed à 0.5, une rotation by speed à 45 d'angular velocity
- Quand un client n'a pas eu sa commande et part, lancer un système de particules qui fait spawn des icones de grawlix sur le personnage avec le png GrawlixSheet.png en grille de 4x4 une icon randm de cette sheet avec une rotation over lifetime et qui s'efface en fade, une émision de de 10 particules en bursts, avec une shape sphere de 0.65, une start size de 0.5, une start speed à 0.2, une rotation by speed à 45 d'angular velocity

PROPOSITION GAMEPLAY :
- L'event Contrôle AFSCA ferait que toute la nourriture en main, toutes les frites précuites et toutes les bières du frigo serait supprimé instant car "Pas frais" et faut refaire les commandes en cours et réattendre l'approvisionnement du frigo
- L'event MiTempsDiablesRouges ferais que d'un coup tous les clients demandent une bière (Jupiler ou Maes) d'office dans leur commande en plus de ce qu'ils commandaient de base

BUGS REMONTÉS :
- Les images UX_Time et UX_Day sont étirée, il faut pas les ajuster, elles doivent rester uniformément scale 1/1/1 pour pas déformer l'image.
- Il n'y a pas les boutons Exit, Retry et Pause en haut à gauche de l'écran
- Mettre le logo du jeu au chargement de Godot à la place du logo de Godot
- Les particules de frying oil sont un peu petites, légèrement agrandir le système de particules pour mieux les voir à l'écran
- Il y a un léger décalage pour le frites raw dans la scène 3D, ça n'est pas la bonne position donné par les fichiers SceneExport.md
- Il y a encore les textes au-dessus de certaine zone (Bière x5, cuisson 1, cuisson 2, cuisson viande,..) on peut les enlever vu que toutes la 3D est là et visuel compréhensible à elle même