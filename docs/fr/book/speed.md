# Vitesse

Cette page dit ce que coûte chaque étape de Ceti, et où va le temps. Chaque nombre a été mesuré sur une seule machine (8
cœurs, Linux 7.2, Cesia 1.1.0+dev, Firefox headless, c'est-à-dire sans fenêtre), contre les mêmes étapes pilotées par
WebDriver BiDi brut depuis Node 26 : la même page, le même Firefox. BiDi brut est le plancher : les propres messages du
protocole, écrits à la main, sans attente, sans vérification et sans bibliothèque autour. Les étapes de la v1 ont été
mesurées le 12 novembre 2026 avec Firefox 159.0 et Ceti v1, qui démarrait chaque Firefox sur un profil vide ;
[Le template de profil](#le-template-de-profil) donne le démarrage et la fin de Firefox depuis que Ceti copie un template
(un profil modèle), et [Les étapes de l'automatisation complète](#les-étapes-de-lautomatisation-complète)
les étapes venues ensuite, le 13 novembre avec Firefox 160.0.

## Comment cela a été mesuré

Un lancement démarre Firefox, ouvre une page, va à une page locale servie sur 127.0.0.1, tape trois lettres dans un champ,
clique sur un bouton, lit un texte, lit les textes d'une liste, prend une capture d'écran, ferme la page et quitte. Dans le
même navigateur, il répète ensuite 21 fois : aller à la page, cliquer, lire, capturer, et `Eval("1")` ; la médiane des 21
est le temps à chaud de ce lancement. Ceti et BiDi brut ont tourné l'un après l'autre, 21 fois chacun, en alternance,
chaque paire pendant qu'aucun autre travail lourd ne tournait sur la machine. Chaque chiffre est la médiane des 21
lancements, puis le premier et le troisième quartile entre crochets : la moitié des lancements se trouvent entre eux. Pour
le scénario entier et le démarrage, la différence des médianes a son intervalle à 95 %, tiré de 5 000 rééchantillonnages
des lancements (le bootstrap) : un intervalle qui contient 0 ne montre aucune différence que ces lancements puissent voir.

## Les chiffres

Temps en millisecondes. « À froid » est le premier appel dans un nouveau navigateur ; « à chaud » est la médiane de 21
appels dans le même navigateur.

| Étape | Ceti | BiDi brut |
|---|---:|---:|
| prêt : démarrer Firefox, son WebSocket, la session | 2 436 [2 088–2 699] | 2 052 [1 922–2 646] |
| `NewPage` (user context et page) | 89,3 [79,1–104,9] | 94,6 [81,6–107,5] |
| `Go`, à froid / à chaud | 94,6 / 15,6 | 101,2 / 15,4 |
| `Type` de 3 lettres, à froid (brut : trouver le champ, puis les touches) | 50,9 [44,6–56,8] | 29,4 [27,8–34,6] |
| `Click`, à froid (brut : trouver le bouton, puis la souris) | 19,1 [18,0–23,2] | 26,2 [23,7–30,7] |
| `Click`, à chaud | **10,9** [10,1–11,9] | 7,9 [7,0–8,5] |
| `Text`, à froid / à chaud | 2,0 / **1,6** [1,5–1,6] | 4,9 / 1,1 |
| `Texts` de 3 éléments | 1,5 [1,3–1,6] | 2,0 [1,6–2,2] |
| `Screenshot` 1366×682, à froid / à chaud | 24,7 / **19,2** [18,8–20,3] | 19,4 / 18,8 |
| `Eval("1")`, à chaud | 1,2 [1,1–1,2] | 1,1 [1,1–1,1] |
| `ClosePage` | 18,0 [16,5–21,1] | 14,7 [13,4–15,8] |
| quitter : fermer Firefox, attendre sa fin, supprimer le profil | 598 [564–837] | 566 [528–618] |
| le scénario entier | 3 451 [3 016–3 837] | 2 918 [2 757–3 454] |

Le démarrage diffère de +384 ms, intervalle à 95 % [−330 ; +585], et le scénario entier de +533 ms, [−39 ; +889] : les
deux contiennent 0, puisque le démarrage propre de Firefox varie de 1,7 s à 7 s d'un lancement à l'autre. Le démarrage
médian de Ceti était plus haut dans une série antérieure de 21 lancements aussi (+246 ms, [−408 ; +640]), et le programme
Cesia n'a utilisé aucun temps du processeur pendant que Firefox démarrait (moins de 10 ms, lu dans `/proc`) : si la
différence est réelle, elle tient à la façon dont Firefox démarre, pas à un travail que fait Ceti.

## Où va le temps

- **Le démarrage et la fin de Firefox** : sur un profil vide, environ 2,4 s pour être prêt, puis 0,6 s pour finir, sur
  les 3,5 s. Le protocole n'y a aucune part. Sur le template de profil, environ 1,0 s et 0,5 s
  ([Le template de profil](#le-template-de-profil)).
- **Une commande coûte au moins environ 1,1 ms** : le WebSocket, le JSON et le propre travail de Firefox. La part de Ceti
  lui-même, son JSON, ses fibers et son client WebSocket en Cesia, est la différence sur `Eval("1")` : 0,1 ms, intervalle
  à 95 % [0,0 ; 0,1].
- **Un `Click` à chaud coûte 10,9 ms**, contre 7,9 pour la recherche et le clic de BiDi brut : environ 6 ms dans Firefox
  pour les événements de souris de `input.performActions`, les mêmes dans les deux, et 4 à 5 ms pour l'attente, là où BiDi
  brut ne fait que trouver l'élément. L'attente est le premier script d'une page qui vient de se charger, ce qui coûte à
  Firefox environ 1 ms de plus que les suivants, et sa vérification que l'élément est visible fait calculer à Firefox la
  mise en page, environ 1 ms de plus. Un second clic sur la même page a pris 6,8 ms (la médiane de 21, en un lancement).
- **`Text` coûte 0,5 ms de plus que la lecture de BiDi brut**, pour la même raison : il vérifie que l'élément est visible.
- **Une capture d'écran coûte 19 ms**, presque toutes dans Firefox, qui dessine la page et écrit le PNG en Base64. Cesia
  décode le Base64 en OCaml, en environ 0,1 ms.

## Ceti dans le démarrage d'un programme

Un programme Cesia lit un package quand il utilise l'un de ses noms. Un programme qui utilise Ceti démarre en 7,0 ms contre
2,5 ms pour `io.Print(1)`, donc +4,5 ms, intervalle à 95 % [+4,4 ; +4,7] (21 lancements de chacun, en alternance) : 2,2 ms
pour les packages de Cesia qu'il utilise (le client WebSocket, std/encode, std/json) et 2,4 ms pour son propre code. C'est
un cinquième de pour cent des 2,4 s que Firefox prend ensuite pour être prêt.

Le template de profil a ajouté environ 60 lignes de code à Ceti : un programme qui l'utilise démarre 0,18 ms plus tard,
intervalle à 95 % [+0,06 ; +0,41] (8,40 ms contre 8,22 ms pour la v1, le 12 novembre, 21 lancements de chacun, en
alternance), contre 1,1 s gagnée à chaque démarrage de Firefox. Cesia compile une fonction à son premier appel, mais lit,
analyse et résout chaque ligne d'un package quand un programme le charge : le coût suit les lignes de code, et les
commentaires ne coûtent rien.

## Les étapes de l'automatisation complète

Mesuré le 13 novembre 2026, avec Firefox 160.0 et le template de profil : 21 tours, tous pendant une seule prise du verrou
de la machine, si bien qu'aucun autre travail lourd ne tournait pendant ce temps. À chaque tour, le Ceti de main (la
branche principale), qui n'a que les étapes de la v1, et ce Ceti-ci ont lancé le même programme à tour de rôle, l'ordre
inversé à chaque tour ; puis ce Ceti a lancé chaque nouvelle étape une fois à froid et 11 fois à chaud dans un même
navigateur, et BiDi brut depuis Node a lancé les mêmes étapes sur la même page et de la même façon. Une case est la
médiane des 21 tours, puis le premier et le troisième quartile ; une différence est celle des médianes, avec son
intervalle à 95 % tiré de 5 000 rééchantillonnages : un intervalle qui contient 0 ne montre aucune différence que ces tours
puissent voir. Temps en millisecondes.

### Les étapes de la v1

Les nouvelles parties ne doivent rien coûter aux anciennes étapes. Depuis la v1, la session demande les événements des
dialogues et de la console, refuse les téléchargements, et le chercheur d'éléments tourne dans une sandbox de BiDi (un
bac à sable que les scripts de la page ne voient pas), mise là par la première attente dans chaque document :

| Étape | main | ce Ceti | différence |
|---|---:|---:|---:|
| prêt : démarrer Firefox, son WebSocket, la session | 1 021 [996–1 074] | 981 [946–1 022] | -39,5 [-83,3 ; +6,4] |
| `NewPage` | 152 [131–160] | 118 [106–130] | -33,7 [-44,3 ; -15,5] |
| `Go`, à froid | 142 [129–161] | 116 [109–125] | -25,8 [-37,0 ; -14,6] |
| `Go`, à chaud | 28,5 [26,5–31,4] | 28,4 [25,8–33,1] | -0,1 [-2,9 ; +4,2] |
| `Type`, à froid | 63,3 [59,4–70,7] | 75,8 [62,7–82,2] | +12,4 [-0,1 ; +18,2] |
| `Click`, à froid | 19,1 [17,3–21,9] | 18,7 [16,9–19,8] | -0,3 [-2,4 ; +1,3] |
| `Click`, à chaud | 6,0 [5,0–7,3] | 5,0 [4,6–5,6] | -1,0 [-2,0 ; -0,1] |
| `Text`, à chaud | 1,3 [1,0–1,6] | 0,9 [0,8–1,2] | -0,3 [-0,6 ; -0,1] |
| `Eval("1")`, à chaud | 0,6 [0,5–0,7] | 0,6 [0,6–0,7] | +0,0 [-0,1 ; +0,1] |
| `Screenshot`, à chaud | 21,4 [20,0–23,7] | 21,4 [20,2–24,2] | -0,0 [-2,2 ; +2,2] |
| `ClosePage` | 19,8 [18,0–22,6] | 16,9 [16,7–18,9] | -2,8 [-4,6 ; -1,1] |
| quitter | 303 [285–368] | 294 [284–342] | -8,5 [-38,2 ; +27,3] |
| le lancement entier | 2 654 [2 461–2 992] | 2 396 [2 335–2 593] | -258 [-485 ; -62,6] |

### Les nouvelles étapes

BiDi brut est le plancher : les messages du protocole écrits à la main, sans attente, sans vérification et sans
correspondance de noms. « À froid » est le premier appel dans le navigateur :

| Étape | Ceti, à chaud | Ceti, à froid | BiDi brut, à chaud | Ceti − brut, à chaud | ce que fait BiDi brut |
|---|---:|---:|---:|---:|---|
| `Click("#save")` | 5,4 [5,0–6,1] | 57,3 | 6,0 [5,4–6,6] | -0,6 [-1,0 ; +0,2] | trouver le bouton, cliquer |
| `Click(ByRole("button", name = "Save"))` | 4,8 [4,5–5,9] | 6,3 | 11,9 [11,5–12,8] | -7,1 [-7,8 ; -6,3] | le locator `accessibility` de Firefox, cliquer |
| `Text(ByTestId("said"))` | 1,0 [0,9–1,3] | 1,5 | 0,8 [0,7–1,0] | +0,2 [+0,1 ; +0,4] | `script.evaluate` de `innerText` |
| `Text(ByText("Task 2"))` | 1,2 [1,1–1,6] | 1,9 | — | — | — |
| `Type(ByLabel("Email"), ...)`, 15 touches | 16,1 [15,4–17,7] | 25,2 | — | — | — |
| `Value(ByLabel("Email"))` | 1,2 [1,1–1,4] | 1,6 | — | — | — |
| `Select(ByLabel("Country"), "Spain")` | 1,2 [1,2–1,5] | 1,4 | 0,7 [0,7–0,8] | +0,5 [+0,4 ; +0,7] | choisir l'option, envoyer les événements |
| `Check` / `Uncheck` | 6,9 [6,5–7,5] | 9,3 | 11,1 [11,0–12,1] | -4,3 [-5,0 ; -3,6] | trouver la case, cliquer |
| `Upload` | 2,1 [1,8–2,3] | 2,7 | 1,7 [1,6–1,8] | +0,4 [+0,1 ; +0,5] | trouver le champ, `input.setFiles` |
| `Hover` | 2,6 [2,2–2,9] | 3,4 | 2,4 [2,3–2,7] | +0,2 [-0,3 ; +0,3] | trouver, bouger la souris |
| `Drag` | 83,8 [83,6–86,0] | 80,7 | 83,4 [83,2–83,7] | +0,4 [+0,1 ; +1,6] | trouver les deux, les mêmes mouvements |
| `Wheel("#box", 100)` | 33,3 [33,2–33,3] | 30,7 | 1,5 [1,4–1,6] | +31,8 [+31,7 ; +31,8] | l'action de la molette seule |
| `Frame("#pay")` | 0,8 [0,8–0,9] | 1,7 | 0,4 [0,3–0,4] | +0,5 [+0,4 ; +0,5] | `browsingContext.getTree` |
| `Text` dans une frame | 0,8 [0,7–0,8] | 5,4 | 0,6 [0,6–0,7] | +0,2 [+0,1 ; +0,3] | `script.evaluate` dans la frame |
| `Dialog(true, click)` | 43,4 [40,9–47,4] | 71,1 | 44,4 [40,4–48,9] | -1,1 [-6,7 ; +3,9] | clic, événement, `handleUserPrompt` |
| `Console` | 0,0 [0,0–0,0] | 0,0 | — | — | — |
| `Response("/api/data", click)` | 14,8 [14,1–16,3] | 39,8 | 17,3 [15,3–20,5] | -2,5 [-4,5 ; -0,8] | s'abonner, collecteur, clic, événement, données, se désabonner |
| un `fetch` de la page | 2,3 [2,2–2,4] | 2,8 | 2,8 [2,6–3,2] | -0,6 [-0,8 ; -0,4] | le même |
| un `fetch` auquel répond une `Route` | 3,1 [2,9–4,0] | 3,5 | 3,6 [3,3–4,2] | -0,4 [-1,0 ; +0,0] | intercepter, événement, `provideResponse` |
| `Popup(click)` et `ClosePage` | 81,7 [76,5–95,0] | 102 | 86,2 [71,3–97,6] | -4,5 [-15,0 ; +9,9] | s'abonner, clic, création, chargement, fermeture |
| `NewTab` et `ClosePage` | 207 [202–215] | 195 | 216 [202–223] | -9,5 [-15,0 ; +3,7] | créer une fenêtre, la fermer |
| `State` | 2,0 [1,5–3,3] | 25,5 | 2,2 [1,8–2,9] | -0,2 [-0,9 ; +0,4] | `getCookies`, `localStorage` |
| `NewPage(b, state = s)` et `ClosePage` | 363 [344–383] | 331 | — | — | — |
| `NewPage` et `ClosePage` | 219 [211–225] | 220 | 232 [216–241] | -13,4 [-22,2 ; -0,8] | user context, fenêtre, suppression |
| `Emulate(viewport = ...)` | 3,5 [1,8–7,8] | 32,0 | 5,8 [2,1–10,8] | -2,3 [-6,9 ; +0,9] | `setViewport` |
| `Download(click, to)` | 27,1 [25,5–32,5] | 63,5 | — | — | — |
| `Screenshot(of = "#list")` | 7,0 [6,8–7,5] | 12,3 | 7,1 [6,7–8,0] | -0,1 [-0,7 ; +0,2] | trouver, `captureScreenshot` avec `clip` |
| `Pdf` | 1 828 [1 827–1 831] | 1 844 | 1 826 [1 824–1 828] | +1,4 [-0,6 ; +4,6] | `browsingContext.print` |

Ce que disent les chiffres :

- **Nommer par le rôle ne coûte rien.** `Click(ByRole("button", name = "Save"))` prend ce que prend un clic par CSS,
  puisque Ceti fait correspondre les rôles et les noms dans la page, dans le round trip (l'aller-retour avec Firefox) de
  son attente. Le moyen propre de BiDi brut, le locator `accessibility` de Firefox, prend 2,5 fois plus de temps à chaud,
  et son premier appel, qui démarre le service d'accessibilité de Firefox, 156 ms contre 6,3.
- **La plupart des étapes sont à moins d'une demi-milliseconde de BiDi brut**, attentes et vérifications comprises :
  `Text`, `Select`, `Upload`, `Hover`, `Drag`, `Frame`, un `fetch` routé, `State`, `Screenshot(of =)` ; `Response`,
  `Popup`, `NewTab`, `NewPage` et `Emulate` sont ici un peu plus rapides que les formes écrites à la main, qui attendent
  chaque réponse à son tour.
- **`Check` est plus rapide que la recherche et le clic de BiDi brut**, qui demande la case à l'arbre d'accessibilité de
  Firefox par son label : Ceti la trouve dans la page.
- **`Wheel` coûte environ 30 ms de plus** que l'action de la molette seule : Firefox fait défiler sur un thread à lui et
  la page l'apprend une frame ou deux plus tard, et `Wheel` répond une fois que la page l'a vu, si bien que ce qui vient
  ensuite voit la page défilée.
- **`Drag` prend environ 84 ms**, dans les deux : son déplacement vers la cible dure 60 ms, par étapes, puisque les
  bibliothèques de listes triables ont besoin de plusieurs mouvements pour commencer un glisser.
- **`Pdf` prend environ 1,8 s**, toutes dans Firefox. **`NewPage(b, state = s)`** ajoute environ 0,14 s à `NewPage` : un
  cookie est une commande, et le stockage d'une origine une page à laquelle Ceti répond lui-même.
- **La première attente dans un document met le chercheur dans sa sandbox**, environ 3 ms une fois par document, que
  contiennent les étapes à froid. Avant que le chercheur ne vive là, chaque attente envoyait ses 11,7 KB de JavaScript, que
  Firefox relisait à chaque appel : `Text` prenait 2,5 ms. Un preload script (un script que Firefox met d'avance dans
  chaque document) qui l'aurait mis dans chaque document coûtait 2,7 ms à chaque `Go` et 15 ms à chaque `NewPage` (11
  tours), alors c'est la première attente qui le fait.

### Après un clic qui charge une autre page

Un clic ou une touche qui emmène la page vers un autre document répond une fois ce document chargé, comme le fait `Go`
(voir le guide). Mesuré le 13 novembre 2026 avec Firefox 160.0 : 21 tours pendant une seule prise du verrou, le Ceti de
main et ce Ceti à tour de rôle, l'ordre inversé à chaque tour, chaque tour dans un nouveau Firefox, puis la médiane de 21
appels à chaud de chaque étape. La page contient 20 images que le serveur interdit de garder (`no-store`), si bien que
chaque chargement les récupère à nouveau :

| Étape | main | ce Ceti | différence |
|---|---:|---:|---:|
| `Go` de la page de 20 images | 36,4 [34,2–42,2] | 35,0 [32,8–39,3] | -1,3 [-7,3 ; +1,2] |
| `Click` d'un bouton qui ne charge rien | 5,5 [5,3–6,0] | 8,0 [7,8–9,1] | +2,5 [+2,2 ; +3,4] |
| `Eval("1")` | 0,7 [0,6–1,1] | 0,6 [0,6–0,7] | -0,1 [-0,3 ; +0,0] |
| `Text` | 1,1 [1,0–1,5] | 1,0 [0,9–1,1] | -0,1 [-0,4 ; +0,0] |
| `Click` d'un lien, seul | 16,1 [15,5–17,6] | 32,9 [31,9–34,2] | +16,8 [+15,0 ; +18,0] |
| `Click` d'un lien, puis `Text` de la nouvelle page | 37,4 [34,2–39,9] | 45,7 [43,3–48,0] | +8,3 [+4,3 ; +12,3] |
| le même, vers une page de 20 images | 49,7 [48,0–52,5] | 59,8 [56,9–63,3] | +10,1 [+6,7 ; +13,2] |
| le démarrage d'un programme qui charge Ceti | 5,69 [5,41–5,89] | 5,60 [5,51–5,76] | -0,09 [-0,27 ; +0,18] |

Ce que disent les chiffres :

- **Un clic sur un lien attend maintenant le chargement** que le clic de main laissait à l'étape suivante : 17 ms de plus
  pour le clic seul. Avec un `Text` de la nouvelle page après lui, la différence est de 8 à 10 ms : le `Text` de main
  trouvait son élément dès que le nouveau document l'avait, là où ce Ceti attend l'événement `load`, qui vient plus tard,
  après les images aussi, et paie les 2,5 ms du point suivant.
- **Un clic ou une touche pressée coûte environ 2,5 ms de plus**, même quand il ne charge rien : Ceti demande
  `network.fetchError` à Firefox juste avant et arrête juste après, le seul signe que Firefox 160 donne d'une navigation
  qui finit sur une réponse 204 ou un arrêt, et Firefox prend ce temps pour appliquer les deux.
- **Une page se charge aussi vite que sur main.** La première version de cette attente demandait `network.fetchError` une
  fois, pour toute la session. Tant qu'un événement du réseau est demandé, Firefox suit chaque requête de chaque page,
  environ 1 ms chacune : dans un seul Firefox, 8 tours de chacun, médianes de 11 appels à chaud :

| Étape | sans `fetchError` | autour de chaque clic (ce Ceti) | pour toute la session |
|---|---:|---:|---:|
| `Go` de la page de 20 images | 43,2 | 41,7 | 65,6 |
| `Click` d'un bouton qui ne charge rien | 5,8 | 9,1 | 5,7 |
| `Click` d'un lien, puis `Text` de la nouvelle page | 43,1 | 47,7 | 55,7 |
| le même, vers une page de 20 images | 66,1 | 68,1 | 86,9 |

### Le démarrage d'un programme qui charge Ceti

Un programme qui charge Ceti et affiche un nombre démarre en 10,9 ms [10,6–11,2] contre 8,1 ms [8,0–8,4] avec le Ceti de
main : +2,9 ms, intervalle à 95 % [+2,5 ; +3,0] (21 lancements de chacun, en alternance, pendant la même prise du verrou).
Ceti a 657 lignes de Cesia de plus que main, ses docstrings (ses textes de documentation) comptées, donc environ 4 µs par
ligne : Cesia lit, analyse et résout chaque ligne d'un package quand un programme le charge. Le JavaScript, 11,7 KB de
texte, en coûte environ 0,15 ms (les cinq lancements les plus rapides de chacun, avec lui et avec un seul caractère à sa
place). C'est environ un tiers de pour cent de la seconde que Firefox prend ensuite pour être prêt, et le cache de
packages chargés de Cesia, en construction, en enlèverait la plus grande part.

## Le template de profil

Firefox passe environ une seconde de son démarrage sur un travail qu'il fait une fois pour un profil : il enregistre ses
modules intégrés, crée ses bases de données, et remplit son startup cache (son cache de démarrage). Ceti le fait une fois
par dossier, dans le template, et chaque démarrage copie le template ([le guide](guide.md#le-template-de-profil) dit
comment). Ces chiffres comparent Ceti avec le template et Ceti v1, qui démarrait chaque Firefox sur un profil vide : 21
tours, chacun pendant qu'aucun autre travail lourd ne tournait sur la machine, l'ordre des deux inversé à chaque tour.
« Prêt » est le temps qui va de l'appel de `browser.Firefox` au début de la fonction qu'il appelle ; « un test » est
`cesia test` d'un fichier qui contient le test du README (une page, trois lettres tapées, un clic, un texte lu), du début
du processus à sa fin, la v1 avec `test.Temp()` et Ceti avec son dossier gardé.

| Étape | v1, profil vide | Ceti, template | Ceti, premier démarrage dans un dossier |
|---|---:|---:|---:|
| prêt | 2 092 [2 011–2 523] | **980** [918–1 125] | 4 223 [3 885–5 073] |
| fin : fermer Firefox, attendre sa fin, supprimer le profil | 748 [695–1 169] | 530 [515–749] | 622 [567–982] |
| démarrage et fin, sans page | 3 124 [2 738–3 922] | 1 649 [1 443–1 857] | 5 398 [4 742–5 914] |
| un test, du début de `cesia test` à sa fin | 2 737 [2 541–2 886] | **1 709** [1 569–1 905] | pas mesuré |

Temps en millisecondes, la médiane de 21 lancements et les quartiles entre crochets. Ceti avec le template moins la v1, la
différence des médianes avec son intervalle à 95 % tiré de 5 000 rééchantillonnages : prêt −1 112 [−1 390 ; −955], fin
−218 [−502 ; −3], un test −1 029 [−1 171 ; −849]. Le premier démarrage dans un dossier est prêt +2 131 [+1 714 ; +2 911]
après celui de la v1.

Le premier démarrage dans un dossier crée le template : un démarrage de Firefox sur un profil vide, sa session, sa fin, et
la suppression de ce que ce démarrage a laissé qui lui est propre, avant le démarrage du lancement lui-même. Un dossier
jeté après chaque lancement, comme `test.Temp()`, le paie à chaque démarrage.

Avant que Firefox ne démarre, Ceti demande sa version, `firefox --full-version`, en 30 ms, et copie le template, 36 MB, en
21 ms (médianes de 21, en Cesia) ; il supprime la copie en 3 ms une fois que Firefox s'est terminé.

### Ce que le template doit contenir

À titre indicatif, 7 tours de BiDi brut depuis Node, chaque partie laissée hors du template à son tour ; le temps pour
être prêt, médiane et quartiles, en ms :

| Template | Prêt |
|---|---:|
| aucun : un profil vide | 1 839 [1 726–2 175] |
| le profil entier d'un premier démarrage | 939 [907–1 035] |
| **celui de Ceti** : ce profil sans ce que son démarrage a laissé qui lui est propre | **916** [881–942] |
| le même, d'un premier démarrage qui a attendu 3 s avant de fermer | 953 [935–1 063] |
| celui de Ceti, sans le startup cache | 1 460 [1 428–2 060] |
| celui de Ceti, sans les bases de données de l'historique et des icônes | 1 077 [990–1 480] |

Le startup cache, les scripts compilés de l'interface propre de Firefox, fait plus de la moitié du gain. Les bases de
données de l'historique et des icônes, 10 MB des 36, font gagner environ 0,16 s : Firefox les recréerait. Ce que le
premier démarrage laisse qui lui est propre, son cache HTTP, sa télémétrie, ses rapports de plantage et sa session, ne fait
rien gagner, alors Ceti l'enlève. Un premier démarrage qui attend 3 s avant de fermer laisse les mêmes fichiers, alors le
démarrage du template ferme aussitôt.
