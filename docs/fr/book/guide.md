# Piloter Firefox

Ce chapitre pilote Firefox depuis Cesia : le démarrer, ouvrir des pages, trouver des éléments, cliquer et taper, lire ce
que la page montre, lancer du JavaScript, capturer l'écran, et savoir ce qui s'est mal passé quand quelque chose se passe
mal. Les exemples utilisent le package comme le fait un programme, `use deps/www-celestial/ceti/src/browser` ; ils sont
montrés et vérifiés, pas lancés, puisqu'un site ne démarre aucun navigateur.

## Démarrer Firefox

`browser.Firefox` démarre Firefox et le donne à une fonction. Quand la fonction se termine, Firefox se ferme :

```cesia norun
use deps/www-celestial/ceti/src/browser
use std/io

defn title(b)
  p = browser.NewPage(b)?
  browser.Go("https://example.com/", p)?
  browser.Eval("document.title", p)
end

io.Print(browser.Firefox(title, "work/firefox"))
```

Cinq choses se passent, dans cet ordre :

1. Un nouveau dossier est créé dans `work/firefox` pour le **profil**, le dossier où un navigateur garde ses réglages, ses
   cookies et son cache : une copie du **template** (le profil modèle) que `work/firefox` garde pour cette version de
   Firefox, le profil d'un Firefox démarré une fois et fermé avant toute page (voir
   [Le template de profil](#le-template-de-profil)). Chaque démarrage a sa propre copie, si bien que rien d'un lancement
   n'atteint le suivant.
2. Firefox démarre **headless**, sans fenêtre, avec `--remote-debugging-port=0` : il sert WebDriver BiDi sur un port qu'il
   choisit lui-même, et écrit `WebDriver BiDi listening on ws://127.0.0.1:PORT` (WebDriver BiDi écoute sur ce port) sur sa
   sortie. Ceti lit cette ligne, pendant 30 secondes au plus.
3. Ceti ouvre le WebSocket de BiDi (une connexion qui reste ouverte, où les messages vont dans les deux sens),
   `ws://127.0.0.1:PORT/session`, et la session (`session.new`) ; il ne se connecte à aucune adresse autre que
   `127.0.0.1`. Les fenêtres de question comme `alert` et `confirm` sont écartées dès qu'elles s'ouvrent, puisque personne
   n'est là pour y répondre : `confirm` donne `false`. Les téléchargements sont refusés : sans cela, un Firefox headless
   enregistre ce qu'une page télécharge dans le dossier de téléchargements de l'utilisateur, où le programme n'a jamais
   permis d'écrire.
4. `title(b)` tourne, dans une fiber à elle (une tâche de Cesia qui tourne à côté des autres dans le même programme).
5. Quoi que `title` ait donné, un `Ok`, un `Err`, ou une panic (l'arrêt d'un programme sur un bug), Ceti ferme Firefox
   (`browser.close`), attend qu'il se soit terminé, supprime le profil, et donne ce que `title` a donné, ou fait à nouveau
   une panic si `title` en a fait une.

`headless = false` montre la fenêtre, pour regarder un problème. `program =` nomme la commande de Firefox quand ce n'est
pas `firefox`, comme `/Applications/Firefox.app/Contents/MacOS/firefox` sur macOS.

### Le template de profil

Un Firefox qui démarre sur un profil vide passe environ une seconde sur un travail qu'il ne fait qu'une fois par profil :
il enregistre ses modules intégrés, crée ses bases de données, et remplit son **startup cache** (son cache de démarrage),
où il garde les scripts de sa propre interface, compilés, pour les démarrages suivants. Ceti fait ce travail une fois par
dossier. Au premier démarrage dans `work/firefox`, il démarre Firefox sur un profil vide, headless, ouvre la session et la
ferme, avant toute page ; il garde ce profil comme template,
`work/firefox/template-Mozilla-Firefox-159.0-20261027034604-20261027034604`. Chaque démarrage le copie ensuite, environ
36 MB en 21 ms, et Firefox est prêt en environ 1,0 s au lieu de 2,1 s ([Vitesse](speed.md#le-template-de-profil)).

- **Il ne contient le travail d'aucune page.** Le démarrage qui le crée n'ouvre aucune page, et Ceti enlève ce que ce
  démarrage a laissé qui lui est propre avant de le garder : son verrou, son cache HTTP, sa télémétrie, ses rapports de
  plantage, sa session, et la liste des fichiers que le startup cache a lus, qui les nomme par le chemin du template.
- **Aucun lancement ne le modifie.** Firefox tourne sur la copie, et Ceti supprime la copie quand Firefox s'est terminé.
  Ainsi aucun lancement ne voit ce qu'un autre a fait : ses cookies, son stockage, son cache, son historique, ses réglages.
  Les tests de Ceti vérifient que le template est le même, octet pour octet, après eux tous.
- **Il y en a un par version de Firefox.** Son nom est ce qu'écrit `firefox --full-version`, la version et le build de
  Firefox, avec des tirets à la place de ses espaces ; Ceti le demande à chaque démarrage, ce qui prend 30 ms. Après une
  mise à jour de Firefox, le démarrage suivant crée le template de la nouvelle version et supprime les autres : Firefox
  refuse un profil d'une version plus récente que la sienne, et refait son travail unique sur un profil d'une version plus
  ancienne.
- **Le premier démarrage dans un dossier est prêt en environ 4,2 s**, puisqu'il crée d'abord le template. Un dossier jeté
  après chaque lancement, comme `test.Temp()`, le recrée à chaque démarrage : donnez à `Firefox` un dossier qui reste,
  comme `.cesia/firefox` dans un projet ([Dans un test](#dans-un-test)).

Deux programmes, ou deux fichiers de test, peuvent démarrer Firefox dans un même dossier en même temps. Quand le template
n'est pas encore là, chacun crée le sien dans un dossier à lui, `build-` suivi d'un nombre, et le renomme aussitôt du nom
du template : le premier le garde, et l'autre supprime le sien. Une copie ne rencontre jamais un template à moitié fait.

Le dossier peut être supprimé dès qu'aucun Firefox n'en tourne : le démarrage suivant recrée le template. À côté du
template, un dossier `profile-` est le profil d'un Firefox qui tourne, et un dossier `build-` un template en cours de
création ; un tel dossier qui reste après la fin de Firefox vient d'un Firefox tué par `kill -9`, ou d'une coupure de
courant, et peut être supprimé.

### Les permissions

Un programme Cesia ne touche rien en dehors de lui-même à moins que sa ligne de commande ne le permette. Ceti a besoin de
trois permissions :

| Permission | Pourquoi |
|---|---|
| `exec=firefox` | pour démarrer Firefox, et pour demander sa version ; `exec=` le chemin donné comme `program`, quand il y en a un |
| `net=127.0.0.1` | pour se connecter à Firefox, sur le port qu'il a choisi à son démarrage, que personne ne peut écrire d'avance |
| `read=work`, `write=work` | pour créer le template et les profils dans le dossier donné à `Firefox`, et pour supprimer les profils : supprimer un dossier le liste d'abord |

`net=127.0.0.1` ouvre au programme tous les ports de cette machine : une permission plus étroite demanderait une nouvelle
sorte de permission dans Cesia, pour les ports des programmes qu'il a démarrés.

Deux de plus, pour certaines fonctions seulement : `read=` pour les fichiers que `browser.Upload` donne à une page, et
`write=` pour le chemin où `browser.Download` enregistre un fichier.

**Des dossiers privés.** Cesia crée des dossiers que les autres utilisateurs de la machine peuvent lire (0755) et des
fichiers qu'ils peuvent lire (0644), et un profil contient les cookies et le stockage de ses pages pendant que Firefox
tourne. Gardez le dossier donné à `Firefox` sous un dossier personnel qui n'est qu'à vous, comme la plupart des systèmes
le créent (0700).

## Les pages

`browser.NewPage` ouvre une page dans un **user context** à elle (un contexte d'utilisateur) : un ensemble de cookies, de
stockage et de cache qu'aucun autre user context ne voit, comme en a une fenêtre de navigation privée. Deux pages d'un
même navigateur ne partagent pas une connexion à un compte, si bien que deux scénarios peuvent tourner côte à côte dans un
seul Firefox :

```cesia norun
defn twoUsers(b)
  ana = browser.NewPage(b)?
  bob = browser.NewPage(b)?
  browser.Go("http://127.0.0.1:8080/", ana)?
  browser.Go("http://127.0.0.1:8080/", bob)?
  browser.Eval("document.cookie", bob)
end
```

Chaque page est visible, comme la page qu'une personne regarde : Firefox fait tourner les timers d'un tab caché (un
onglet) une fois par seconde au plus, et ses frames (les images qu'il dessine) aussi rarement, ce qui rendrait les attentes
lentes et la page différente de la vraie. Ainsi la première page s'ouvre à côté du tab que Firefox a ouvert à son
démarrage, et tant qu'elle est ouverte, les autres s'ouvrent dans des fenêtres à elles. Ouvrir une page dans une fenêtre
coûte environ 0,2 s, contre 0,09 s pour la première.

`browser.ClosePage` ferme une page et son user context, avec ses tabs et ses popups. Les pages encore ouvertes se ferment
avec le navigateur, si bien qu'un programme n'en a besoin que lorsqu'il ouvre beaucoup de pages.

`browser.Go` va à une URL et attend son événement `load`, le moment où la page et ses images, ses styles et ses scripts se
sont chargés. Une adresse qui ne peut pas être atteinte est un `Err` de la sorte `"browser"`.

### L'état d'une session

Un test qui se connecte une fois puis tourne en tant que cette personne garde l'**état** de la session :
`browser.State(p)` donne les cookies du user context de `p` et le `localStorage` (le stockage durable d'une page dans le
navigateur) de l'origine de la page, en données simples, `{Cookies, Storage}`, et `browser.NewPage(b, state = s)` ouvre une
page dont le user context commence avec eux :

```cesia norun
use std/json
use std/result
use std/sys

defn saveSignIn(p)
  sys.Write(".cesia/signed-in.json", json.Text(browser.State(p)?))
end

defn asAna(b)
  s = json.Parse(sys.Read(".cesia/signed-in.json")?)!
  browser.NewPage(b, state = s)
end
```

Chaque cookie est `{Name, Value, Domain, Path, HttpOnly, Secure, SameSite, Expires}`, `Expires` en secondes depuis 1970,
ou `missing` pour un cookie qui finit avec la session. `Storage` est `{origin: {key: value}}` ; BiDi ne lit aucun
`localStorage` d'une autre origine que celle de la page. Pour l'écrire, Ceti ouvre une page vide de cette origine, à
laquelle il répond lui-même, si bien qu'aucun serveur ne voit la requête, puis laisse la nouvelle page sur `about:blank`.
Une origine qui n'est pas `http:` ou `https:` est refusée. Le fichier d'un état contient ce que contient une personne
connectée : gardez-le hors de git, comme dans `.cesia/`.

### L'émulation

`browser.Emulate(p, ...)` fait que le navigateur se présente autrement à `p` et aux pages de son user context, ses tabs et
ses popups, jusqu'à ce qu'un autre `Emulate` le change. Il prend ce qu'on lui donne, chaque élément une commande de BiDi :

| Paramètre | Ce que voit la page | Exemple |
|---|---|---|
| `viewport = [width, height]` | la taille de son viewport (la partie de la page que montre la fenêtre), en pixels CSS | `[390, 844]` |
| `scale = n` | le device pixel ratio, combien de pixels de l'écran prend un pixel CSS | `3` |
| `locale = text` | la langue, dans `navigator.language` et `Intl` | `"fr-FR"` |
| `timezone = text` | le fuseau horaire de ses dates | `"Europe/Paris"` |
| `geolocation = [latitude, longitude]` | le lieu que donne `navigator.geolocation` | `[48.8566, 2.3522]` |
| `offline = true` | un réseau coupé ; `false` le remet | `true` |

```cesia norun
defn asPhone(p)
  browser.Emulate(p, viewport = [390, 844], scale = 3, locale = "fr-FR", timezone = "Europe/Paris")?
  browser.Go("http://127.0.0.1:8080/", p)
end
```

Une page qui demande sa position reçoit celle qu'a donnée `Emulate`, sans question. Sans elle, elle reçoit aussitôt une
erreur : chaque profil coupe les moyens qu'a Firefox d'apprendre le lieu de la machine elle-même, un service réseau et
GeoClue, si bien qu'aucune page n'apprend où est la machine. Un fuseau horaire ou une langue que Firefox ne connaît pas est
un `Err` de la sorte `"browser"`. Un écran tactile n'est pas là : Firefox 160 n'a pas `emulation.setTouchOverride`.

### Les tabs et les popups

`browser.NewTab(p)` ouvre une page dans le user context de `p` : elle partage ses cookies et son stockage, comme le fait
un second tab (un second onglet) d'une même personne, pour un test de ce qu'un tab voit d'un autre. `browser.NewPage`
reste le chemin vers une autre personne.

`browser.Popup(action, p)` lance `action()` et donne la page qu'une page du user context de `p` a ouverte pendant ce temps,
par `window.open` ou par un lien dont la `target` est `_blank`, une fois qu'elle s'est chargée ; c'est une popup (une
fenêtre qu'une page ouvre d'elle-même) :

```cesia norun
defn help(p)
  h = browser.Popup(() -> browser.Click(browser.ByRole("link", name = "Help"), p), p)?
  browser.Text("h1", h)
end
```

Aucune page ouverte dans les `timeout` secondes après l'action est un `Err` de la sorte `"timeout"`. Un tab et une popup
partagent le user context de `p`, et se ferment donc avec `p` ; `browser.ClosePage` de l'un d'eux le ferme seul.

### Les frames

Une **frame**, la page qu'un `<iframe>` montre à l'intérieur d'une autre, a son propre document : un selector (ce qui
désigne un élément, voir plus bas) de la page ne regarde pas dedans. `browser.Frame(sel, p)` attend un `iframe` ou une
`frame` du selector, montré ou non, et donne sa frame comme une page, dont toutes les fonctions marchent dedans, de
l'origine de la page ou d'une autre, comme un formulaire de paiement servi par une banque :

```cesia norun
defn pay(p)
  card = browser.Frame("#payment", p)?
  browser.Type(browser.ByLabel("Card number"), "4242 4242 4242 4242", card)?
  browser.Click(browser.ByRole("button", name = "Pay"), card)
end
```

Une frame se ferme avec sa page, si bien que `browser.ClosePage` d'une frame est un bug : il fait une panic. Une frame que
sa page a enlevée donne un `Err` de la sorte `"browser"`, `no such frame` (pas de telle frame).

## Trouver un élément

Chaque fonction qui cherche un élément prend un **selector** : un texte CSS, ou un **locator**, qui nomme l'élément comme
une personne le trouve à l'écran.

Un texte est toujours un **selector CSS** (un sélecteur CSS), le langage des feuilles de style pour nommer des éléments :
`#go` est l'élément dont l'id est `go`, `.item` chaque élément de la classe `item`, `form input[type=email]` chaque champ
d'email dans un formulaire. Un selector qui n'est pas du CSS, comme `div[`, est un bug du programme : la fonction fait une
panic, et le message nomme le selector.

Un locator est fait par l'une de ces fonctions :

| Locator | Ce qu'il trouve |
|---|---|
| `browser.ByRole(role, name = missing, exact = false)` | les éléments d'un rôle ARIA, avec ce nom accessible |
| `browser.ByLabel(text, exact = false)` | les champs que nomme un label (une étiquette de champ) |
| `browser.ByText(text, exact = false)` | les éléments les plus intérieurs dont le texte contient `text` |
| `browser.ByPlaceholder(text, exact = false)` | les champs dont le placeholder (le texte grisé d'un champ vide) contient `text` |
| `browser.ByTestId(id)` | les éléments dont le `data-testid` est `id` |
| `browser.Within(container, inner)` | ce que `inner` trouve à l'intérieur de ce que `container` trouve |

```cesia norun
defn signIn(p)
  browser.Type(browser.ByLabel("Email"), "ana@example.com", p)?
  browser.Type(browser.ByLabel("Password"), "secret", p)?
  browser.Click(browser.ByRole("button", name = "Sign in"), p)
end
```

Un test écrit ainsi se lit comme la page se lit pour une personne, et continue de passer quand la page change ses ids ou
ses classes.

**Les rôles et les noms.** Un **rôle** est ce qu'est un élément pour un lecteur d'écran, un programme qui lit la page à
voix haute : un `button` (un bouton), un `link` (un lien), une `textbox` (une zone de texte), une `checkbox` (une case à
cocher), un `heading` (un titre), une `row` (une rangée). Un élément en a un par lui-même, un `<button>` est un bouton et
un `<a href>` un lien, ou par l'attribut `role` qu'écrit la page. Son **nom accessible** est ce qu'en dit un lecteur
d'écran : le `aria-labelledby` ou le `aria-label` que lui donne la page, sinon le label d'un champ, le `alt` d'une image,
ou, pour un bouton, un lien, un titre, une cellule ou une rangée, son texte, sinon son `title` ou son `placeholder`. Ceti
calcule les deux dans la page, d'après les textes du W3C WAI-ARIA 1.2, HTML-AAM (les rôles des éléments HTML) et
*Accessible Name and Description Computation 1.2* ; ses tests les vérifient contre l'arbre d'accessibilité de Firefox
lui-même, pour une quarantaine de sortes d'éléments. Deux remarques : un champ de mot de passe n'a pas de rôle, comme le
dit HTML-AAM, donc trouvez-le par son label ; et les rangées d'un tableau sont nommées par leur texte, comme le dit
ARIA 1.2, ce que Firefox ne fait pas lui-même.

**La correspondance.** Avec `name`, une partie du nom suffit, et la casse (majuscules ou minuscules) et les suites
d'espaces ne comptent pas : `name = "save"` trouve "Save" et "Save draft". `exact = true` demande le nom entier, casse
gardée. `ByLabel`, `ByText` et `ByPlaceholder` font la correspondance de la même façon. Un élément que
`aria-hidden="true"` cache aux lecteurs d'écran n'est pas trouvé par `ByRole`, et un rôle qu'ARIA n'a pas, comme
`"buton"`, est un bug : la fonction fait une panic avec la liste des rôles.

**Within.** `browser.Within` regarde à l'intérieur d'autres éléments : le bouton Buy (acheter) de la rangée de Coffee
(café), dans un tableau où chaque rangée a son propre bouton Buy :

```cesia norun
buyCoffee(p) = browser.Click(browser.Within(browser.ByRole("row", name = "Coffee"), browser.ByRole("button", name = "Buy")), p)
```

Les locators regardent aussi à l'intérieur des shadow roots de la page, les arbres cachés des web components (des
éléments que la page se définit elle-même) ; un texte CSS ne regarde que dans le document, comme le fait
`querySelectorAll`. Une erreur nomme le locator en mots, comme `role button named "Save": no element matches after 5 s`
(rôle button nommé "Save" : aucun élément ne correspond après 5 s).

### L'attente qui se fait seule

`browser.Click`, `browser.Type`, `browser.Text` et `browser.WaitFor` attendent leur élément. Chacun envoie une seule
fonction à la page, qui cherche le premier élément du selector qui est :

- attaché au document ;
- visible : sa boîte n'est pas vide, et il n'est pas en `visibility: hidden` ;
- pour cliquer dessus ou y taper, non désactivé, et pour y taper, non en lecture seule.

La fonction cherche à nouveau à chaque frame que dessine la page (`requestAnimationFrame`) et à chaque changement de la
page (`MutationObserver`), et répond dès qu'elle en trouve un, ou quand son temps est écoulé. L'attente se fait dans la
page, en un seul **round trip** (un aller-retour : un message à Firefox et sa réponse), plutôt qu'en interrogeant la page
encore et encore depuis Cesia. La fonction tourne dans la **sandbox** de Ceti dans la page (un bac à sable), un realm de
BiDi (un monde de JavaScript à part) qui voit le DOM de la page (l'arbre de ses éléments) mais pas ses scripts : une page
qui change `JSON.parse` ou `querySelectorAll` pour elle-même ne change rien pour Ceti. La première attente dans un document
y met la fonction, une fois, si bien que chaque attente suivante envoie un appel de quelques octets, pas la fonction. Si
la page va à une autre adresse pendant ce temps, la fonction le dit en partant, et Ceti cherche à nouveau dans la nouvelle
page, jusqu'à ce que le temps soit écoulé.

Chacun d'eux attend `browser.DefaultTimeout`, 5 secondes, à moins que `timeout =` ne donne un autre temps, en secondes :

```cesia norun
defn report(p)
  browser.WaitFor("#report", p, timeout = 30)?
  browser.Text("#report", p)
end
```

À la fin de son temps, une attente donne un `Err` de la sorte `"timeout"` qui dit ce qu'elle a vu (aucun élément ne
correspond ; aucun élément visible, une correspondance mais aucune visible ; aucun élément visible qui soit activé, un
visible mais tous désactivés) :

```text
#never: no element matches after 5 s
#out: no visible element (1 match, none visible) after 5 s
#go: no visible element that is enabled (1 visible, all disabled) after 5 s
```

Ce que l'attente ne vérifie pas : que l'élément a cessé de bouger, ou qu'aucun autre élément ne le couvre. Un clic sur un
élément sous un autre touche celui du dessus, comme le ferait le clic d'une personne, et le test échoue là où cela se voit.

### Après un clic qui charge une autre page

Un clic sur un lien ou sur le bouton d'un formulaire, une touche qui envoie un formulaire, ou un script de la page que
lance un clic, peut emmener la page vers un autre document. Un tel clic répond une fois ce document chargé, comme le fait
`Go`, dans le `timeout` du clic : l'étape suivante lit la nouvelle page, jamais celle qui est partie, et le serveur a
répondu à la requête, si bien qu'un test peut regarder ses données aussitôt. Un clic qui ne charge rien répond dès qu'il
est fait. Il n'y a aucune fonction à appeler pour cela :

```cesia norun
defn signIn(p)
  browser.Type(browser.ByLabel("Login"), "ana", p)?
  browser.Click(browser.ByRole("button", name = "Sign in"), p)?   (* answers once the next page has loaded *)
  browser.Text("h1", p)   (* the heading of the page that the form led to *)
end
```

`Press`, `Type`, `Select`, `Check`, `Hover`, `Drag` et `Wheel` attendent de la même façon quand ce qu'ils font emmène la
page vers un autre document. Ceti apprend chaque navigation par les événements de BiDi :
`browsingContext.navigationStarted` quand elle commence, que Firefox envoie avant de répondre au clic, puis
`browsingContext.load` quand son document s'est chargé. Une navigation qui n'apporte aucun document finit autrement, et
n'est plus attendue : `navigationFailed` quand elle a échoué ou que la page a refusé de partir, `downloadWillBegin` pour un
téléchargement, et `network.fetchError` pour une réponse `204 No Content` (204, sans contenu) ou une navigation que la page
a arrêtée. Une page qui ne s'est pas chargée à temps est un `Err` de la sorte `"timeout"` qui la nomme (la page était
encore en train de charger cette adresse après 5 s) :

```text
#signin: the page was still loading http://127.0.0.1:8080/invoices after 5 s
```

Ceti ne demande `network.fetchError` à Firefox qu'autour d'un clic ou d'une touche pressée (`Click`, `Check`, `Uncheck`,
`Press`), de juste avant jusqu'à ce que sa navigation ait son document : tant qu'un événement du réseau est demandé,
Firefox suit chaque requête de la page, à environ 1 ms chacune, mesuré, si bien qu'un `Go` d'une page de 20 images
prendrait 19 ms de plus. Ainsi une navigation qu'un script de la page commence de lui-même, comme un `Eval` qui change
`location` ou un timer, et qui n'apporte aucun document, une réponse 204 ou un arrêt, retient chaque étape de cette page
jusqu'à son `timeout`, jusqu'à ce qu'un `Go` emmène la page ailleurs.

Chaque étape attend aussi d'abord une navigation en cours dans sa page, quoi qui l'ait commencée : un clic dans une frame
dont le lien charge la page entière retient l'étape suivante sur cette page jusqu'à ce que le nouveau document se soit
chargé. Une navigation qu'un script commence de lui-même plus tard, comme un timer qui change `location`, peut commencer
pendant qu'une étape tourne : `Text` et les autres attentes d'un élément cherchent alors à nouveau dans le nouveau
document, mais un `Eval` qui tournait là ne reçoit aucune valeur. `form.submit()` et `history.back()` commencent leur
navigation un instant après la fin du script qui les appelle, donc après un `Eval` de l'un d'eux, attendez un élément de
la nouvelle page avec `WaitFor` ; un clic sur un bouton dont le handler (la fonction que la page attache à l'événement)
les appelle est attendu.

Firefox ne garde aucune page dans son **back-forward cache** sous Ceti, la copie des dernières pages qui rend instantané
le bouton Retour d'une personne : une page que `history.back()` ramène se charge à nouveau, comme après un rechargement,
là où le Firefox d'une personne peut la montrer telle qu'elle a été laissée, sans relancer ses scripts. Firefox 160 ne dit
d'une page tirée de ce cache que le commencement de sa navigation, si bien qu'un clic sur Retour attendrait un chargement
qui ne vient jamais.

**Une page ne peut pas retenir une étape pour toujours.** Chaque attente d'une navigation finit au `timeout` de l'étape,
avec l'adresse qu'elle attendait. Ceti lit les événements de Firefox comme n'importe quelle entrée : un champ du mauvais
type ne change rien. Il suit les navigations d'au plus 1 000 browsing contexts (les pages et les frames que Firefox tient)
à la fois, si bien qu'une page qui crée des frames sans fin ne peut pas remplir la mémoire ; au-delà, la navigation d'une
nouvelle frame n'est pas attendue.

## Cliquer et taper

`browser.Click` amène l'élément au milieu du **viewport**, la partie de la page que montre la fenêtre, si son centre en
est dehors, puis déplace la souris à son centre, appuie sur le bouton gauche et le relâche. Ce sont les événements propres
du navigateur, faits par `input.performActions` de BiDi, comme le clic d'une personne les fait : `isTrusted` est vrai, et
les handlers de `mousedown`, `mouseup` et `click` tournent comme ils le feraient pour une personne.

`browser.Type` donne le focus au champ (le fait de recevoir les touches), sélectionne ce qu'il contient, et tape le texte
touche par touche : le champ contient alors le texte. Un champ est un `input`, un `textarea`, ou un élément avec
`contenteditable`. Un texte vide efface ce que contenait le champ. `"\n"` tape une fin de ligne dans un `textarea`. Un
`input` d'un type qui ne prend pas de touches dans Firefox, `date`, `time`, `datetime-local`, `month`, `week`, `color` ou
`range`, reçoit le texte comme valeur, écrit comme HTML l'écrit (`"2026-03-15"`, `"09:30"`, `"#ff0000"`), avec les
événements `input` et `change` ; un texte qu'il ne peut pas prendre est un bug, et fait une panic.

`browser.Press` appuie sur une touche dans l'élément qui a le focus : un caractère, comme `"a"` ou `" "`, ou une touche
par son nom. Les modificateurs viennent avant la touche, joints par `+`, et sont tenus pendant qu'elle est pressée :

```cesia norun
defn keys(p)
  browser.Press("Enter", p)?
  browser.Press("Control+A", p)?
  browser.Press("Shift+Tab", p)
end
```

Les noms sont ceux du standard W3C WebDriver (§15.6.2) : `Backspace`, `Tab`, `Enter`, `Escape`, `PageUp`, `PageDown`,
`End`, `Home`, `ArrowLeft`, `ArrowUp`, `ArrowRight`, `ArrowDown`, `Insert`, `Delete`, `Pause`, `F1` à `F12`, et les
modificateurs `Shift`, `Control`, `Alt` et `Meta`. Un nom qui n'est pas une touche est un bug du programme, et fait une
panic avec la liste.

## Les formulaires

À côté de `Type`, trois fonctions remplissent un formulaire, et `browser.Value` le relit :

```cesia norun
defn order(p)
  browser.Select(browser.ByLabel("Country"), "France", p)?
  browser.Select(browser.ByLabel("Toppings"), ["Olives", "Basil"], p)?
  browser.Check(browser.ByLabel("I agree"), p)?
  browser.Uncheck(browser.ByLabel("Send me news"), p)?
  browser.Upload(browser.ByLabel("Photo"), ["tests/pages/photo.png"], p)
end
```

- `browser.Select(sel, labels, p)` choisit les options d'un `<select>` (une liste de choix) par leurs labels, le texte
  qu'une personne lit dans la liste ; une liste de labels pour un select qui en prend plusieurs, qui sont alors ses seules
  options choisies. Il attend le select, visible et activé, et ces options, qu'une page peut ajouter tard ; passé son
  temps, le `Err` nomme l'option qui manque. Firefox dessine la liste ouverte d'un select en dehors de la page, où la
  souris de BiDi ne peut pas aller, alors Ceti fait le choix dans la page et envoie `input` et `change`, comme le fait le
  navigateur après le choix d'une personne : ces deux événements ont `isTrusted` à faux.
- `browser.Check(sel, p)` et `browser.Uncheck(sel, p)` cliquent sur une checkbox (une case à cocher) ou un radio (un
  bouton d'un choix unique), comme le fait `Click`, quand elle n'est pas déjà comme demandé, puis attendent qu'elle le
  soit. Ils prennent un `input` et un élément du rôle `checkbox`, `radio` ou `switch` (son état est `aria-checked`). Un
  clic ne décoche jamais un radio, si bien que `Uncheck` d'un radio est un bug, et fait une panic.
- `browser.Upload(sel, files, p)` donne à un champ de fichier ses fichiers, un chemin ou une liste de chemins, comme une
  personne les choisit dans la fenêtre du navigateur ; `[]` le vide. Il attend un `input` de type `file`, montré ou non,
  puisqu'une page le cache souvent derrière un bouton à elle. Firefox envoie `input` et `change` lui-même.

**Ce qu'Upload peut lire.** Firefox lit les fichiers lui-même, en dehors de la sandbox de Cesia, alors Ceti demande d'abord
chacun à Cesia avec `sys.Stat` : le programme a besoin de `read=` pour lui, et Cesia suit les liens, si bien qu'un lien ne
peut pas mener hors des dossiers que `read=` permet ; sans elle, le programme s'arrête avec le message de Cesia, comme
pour toute lecture. Seuls les fichiers ordinaires sont pris. Firefox a besoin de chemins absolus, et Cesia ne donne aucun
dossier courant, alors Ceti l'apprend de Firefox : le chemin absolu du profil, moins le chemin relatif que Ceti lui a
donné. Un chemin relatif est ainsi pris depuis le dossier courant quand le dossier donné à `browser.Firefox` est relatif,
comme `.cesia/firefox` ; avec un dossier absolu, comme `test.Temp()`, donnez des chemins absolus.

## La souris et la molette

À côté de `Click`, trois fonctions bougent la souris de BiDi, dont les événements sont ceux du navigateur lui-même :

- `browser.Hover(sel, p)` déplace la souris au centre de l'élément, comme une personne pointe dessus : la page reçoit
  `mouseover`, `mouseenter` et `mousemove`, et un menu qui s'ouvre sous la souris s'ouvre.
- `browser.Drag(from, to, p)` appuie avec la souris au centre de `from`, la déplace à petits pas jusqu'au centre de `to`,
  et la relâche là : ce qu'écoutent les listes triées à la main, les curseurs de réglage et les cartes, avec les
  événements de la souris et du pointeur.
- `browser.Wheel(sel, dy, p)` tourne la molette au-dessus de l'élément de `dy` pixels, vers le bas quand `dy` est positif
  et vers le haut quand il est négatif : l'élément, ou la page autour de lui, défile comme pour une personne.

```cesia norun
defn sort(p)
  browser.Drag(browser.ByText("Task 3"), browser.ByText("Task 1"), p)?
  browser.Wheel("#feed", 2000, p)
end
```

Firefox fait défiler pour la molette sur un thread à lui (un fil d'exécution à part), et la page l'apprend une frame ou
deux plus tard, si bien que `Wheel` répond une fois que la page a vu un défilement, ou après six frames quand rien ne
pouvait défiler. Chaque profil coupe le défilement doux (`general.smoothScroll` dans son `user.js`) : un tour de molette
fait défiler aussitôt, comme un test en a besoin, plutôt qu'en une demi-seconde.

**Le drag and drop de HTML** (le glisser-déposer), un élément `draggable="true"` et l'événement `drop`, ne finit pas dans
Firefox 160 headless : `dragstart`, `dragenter` et `dragover` viennent, jamais `drop` ni `dragend`, quel que soit l'ordre
des mouvements. Ceti ne fait pas ces événements lui-même en JavaScript, puisqu'ils ne seraient pas ceux du navigateur : un
tel test attend Firefox.

## Lire la page

`browser.Text` donne le texte du premier élément visible d'un selector, dès qu'il y en a un : son `innerText`, le texte
tel que la page le montre, sans les balises et avec les sauts de ligne de sa mise en page. `browser.Texts` donne
l'`innerText` de chaque élément d'un selector, tels qu'ils sont maintenant, sans attente : une liste vide si aucun ne
correspond. Un élément qui n'est pas montré, comme un élément en `display: none`, donne son texte tel que la source le
contient.

```cesia norun
items(p) = browser.Texts(".item", p)   (* Ok(["one", "two", "three"]) *)
```

`browser.Value` donne ce que contient un champ, montré ou non : le texte d'un `input` ou d'un `textarea`, `true` ou
`false` pour une checkbox ou un radio, le label de l'option choisie d'un `<select>`, ou une liste de labels pour un select
qui en prend plusieurs. Il attend que le champ soit là :

```cesia norun
quantity(p) = browser.Value(browser.ByLabel("Quantity"), p)   (* Ok("3") *)
```

### Eval

`browser.Eval` donne la valeur d'une expression JavaScript dans la page. Une **promise**, la valeur de JavaScript pour un
résultat qui vient plus tard, est attendue, `timeout` secondes au plus. La valeur vient comme JSON l'écrit : un nombre,
un texte, `true` ou `false`, une liste, un dictionnaire, ou `missing` pour `null` et `undefined` ; une date comme son
texte, `NaN` et les infinis comme `missing`.

```cesia norun
values(p) = browser.Eval("[1, 'two', {three: 3}]", p)   (* Ok([1, "two", {three: 3}]) *)
health(p) = browser.Eval("fetch('/api/health').then((r) => r.status)", p)   (* Ok(200) *)
```

Toute autre valeur, comme une fonction, un élément ou une `Map`, est un `Err` de la sorte `"script"` qui la nomme :
changez-la dans l'expression en l'une de celles-là, comme `[...m]` pour une `Map` ou `el.id` pour un élément. De même
pour une valeur imbriquée sur plus de 64 niveaux, comme des listes de listes de listes : Firefox ne l'écrit pas plus
profond, si bien qu'aucun message n'est trop profond pour être lu. Une exception est un `Err` de la sorte
`"script"` avec son message, comme `TypeError: x is undefined`.

## Ce que la page fait d'elle-même

Une page montre des dialogues, écrit dans sa console, ouvre d'autres pages, envoie des requêtes et lance des
téléchargements, souvent après un clic. Les fonctions qui attendent l'une de ces choses prennent l'action qui la cause
comme une fonction sans argument, et guettent avant de la lancer, si bien que rien n'arrive trop tôt pour être vu ;
ensuite elles l'attendent, `timeout` secondes au plus après l'action, 5 par défaut. Le propre `Err` de l'action revient
tel quel.

### Les dialogues

Firefox signale à Ceti chaque dialogue (une petite fenêtre de question) d'une page : `alert`, `confirm`, `prompt`, et la
question que `beforeunload` pose avant qu'une page soit quittée. Un dialogue qu'aucune fonction n'attend est écarté
aussitôt, puisque personne n'est là pour y répondre : un `alert` se ferme, un `confirm` donne `false`, un `prompt` donne
`null`, et la page reste quand `beforeunload` demande.

`browser.Dialog(answer, action, p)` répond au premier dialogue de `p`, de ses frames, de ses tabs et de ses popups, qui
s'ouvre pendant `action()` : `true` l'accepte, `false` l'écarte, un texte accepte un `prompt` avec ce texte. Il donne
`{Type, Message, Default}`, `Type` l'un de `"alert"`, `"confirm"`, `"prompt"` et `"beforeunload"`, `Default` le texte
qu'offrait un `prompt` :

```cesia norun
defn removeFile(p)
  d = browser.Dialog(true, () -> browser.Click(browser.ByRole("button", name = "Delete"), p), p)?
  d.Message   (* "Delete the file?" *)
end
```

Un clic qui ouvre un dialogue ne finit pas avant qu'on ait répondu au dialogue, puisque la page attend la personne :
`Dialog` y répond dès qu'il s'ouvre, et donne sa réponse une fois que l'action a fini. Aucun dialogue dans les `timeout`
secondes après l'action est un `Err` de la sorte `"timeout"`.

### La console

`browser.Console(p)` donne ce que les pages du user context de `p`, `p` et ses frames, ses tabs et ses popups, ont écrit
dans leur console depuis que `p` s'est ouverte, la plus ancienne entrée d'abord : une liste de `{Type, Text}`, `Type` la
méthode de la console, comme `"log"`, `"info"`, `"warn"`, `"error"` ou `"debug"`, ou `"exception"` pour une erreur
qu'aucun code de la page n'a attrapée. Un test peut vérifier qu'une page n'a rien lancé :

```cesia norun
use std/value

defn isQuiet(p)
  thrown = [e for e in browser.Console(p)? if e.Type == "exception"]
  value.Len(thrown) == 0
end
```

Elle garde les 1 000 dernières entrées d'un user context, chacune coupée à ses 16 384 premiers caractères, si bien qu'une
page qui écrit sans fin ne peut pas remplir la mémoire du programme. Elle ne demande rien à Firefox : Ceti garde les
entrées à mesure qu'elles viennent.

### Le réseau

`browser.Route(pattern, handler, p)` envoie chaque requête de la page dont l'URL correspond au motif (le pattern) à
`handler(request)`, `request` étant `{Url, Method, Headers}`, `Headers` un dictionnaire de noms en minuscules. Comme le
fait un handler de `std/http`, le handler donne une réponse, `{Status, Body, Headers}`, chaque champ facultatif (200, un
corps vide, aucun en-tête), que la page reçoit à la place de celle du réseau ; `missing`, et la requête continue vers le
réseau telle qu'elle était ; ou un `Err`, et la requête échoue, comme sans réseau :

```cesia norun
use std/json
use std/result

defn offline(p)
  browser.Route("/api/items", r -> {Status: 200, Body: json.Text([]), Headers: {"content-type": "application/json"}}, p)?
  browser.Route("https://analytics.example.com/*", r -> result.Err("blocked"), p)
end
```

Un **motif** qui commence par `/` est comparé au chemin de l'URL, sur n'importe quelle origine et sans la query (la
partie après `?`) : `/api/items` correspond à `http://127.0.0.1:8080/api/items?page=2`. Un autre motif est comparé à
l'URL entière, comme `https://cdn.example.com/lib.js`. `*` tient lieu de n'importe quelle suite de caractères : `/api/*`,
`https://cdn.example.com/*`. Les routes d'une page durent aussi longtemps qu'elle ; quand plusieurs correspondent à une
requête, la dernière donnée s'en charge, si bien qu'un test peut faire différer une réponse pendant un temps. Une route
voit les requêtes de sa page, pas celles des frames ou des popups de la page.

Chaque requête d'une page qui a une route attend Ceti, environ un round trip, avant de continuer : BiDi a des motifs à
lui, que Firefox comparerait sans demander à Ceti, mais Firefox 160 s'écarte du standard sur ce point (un motif d'un
chemin ne lui correspond pas avec une query, un motif d'un hôte ne correspondait à rien), alors Ceti demande chaque
requête de la page et la compare lui-même. Un handler qui fait une panic fait échouer sa requête, et sa panic est
affichée, comme celle d'une fiber.

`browser.Response(pattern, action, p)` lance `action()` et donne la première réponse de la page dont l'URL correspond au
motif, une fois qu'elle est complète : `{Url, Method, Status, Headers, Body}`, `Body` les octets en texte, ou `missing`
quand ils dépassent 16 MiB :

```cesia norun
defn save(p)
  r = browser.Response("/api/save", () -> browser.Click(browser.ByRole("button", name = "Save"), p), p)?
  r.Status == 201
end
```

Une requête qui échoue, comme une requête à laquelle aucun serveur ne répond, est un `Err` de la sorte `"browser"`.

Pour voir une requête elle-même, comme le corps qu'envoie un formulaire, une route qui donne `missing` voit chaque requête
au passage et la laisse continuer : son handler peut passer la requête à un channel de `std/fiber` (une file par
laquelle des fibers s'envoient des valeurs), que le test lit ensuite.

```cesia norun
use std/fiber

defn sent(p)
  seen = fiber.Channel(size = 10)
  browser.Route("/api/*", defn (r)
    fiber.Send(r, seen)
    missing
  end, p)?
  browser.Click(browser.ByRole("button", name = "Save"), p)?
  fiber.Receive(seen, timeout = 5)
end
```

### Les téléchargements

Les téléchargements d'une page sont refusés, tous : sans cela, un Firefox headless enregistre ce qu'une page télécharge
dans le dossier de téléchargements de l'utilisateur, où le programme n'a jamais permis d'écrire.
`browser.Download(action, to, p)` lance `action()` et enregistre au chemin `to` le fichier qu'une page du user context de
`p` télécharge pendant ce temps, une fois qu'il est complet :

```cesia norun
defn export(p)
  d = browser.Download(() -> browser.Click(browser.ByRole("link", name = "Export"), p), "out/report.csv", p)?
  d.Name   (* "report.csv", the name the page gave it; the file is at out/report.csv *)
end
```

Il donne `{Url, Name}`. La page ne choisit rien de l'endroit où arrive le fichier : pendant l'action, Firefox ne peut
télécharger que dans un dossier du profil, puis Ceti déplace le fichier vers `to` avec `sys.Rename`, qui a besoin de
`write=` pour lui ; vers un autre disque que celui du profil, il copie le fichier en passant par la mémoire, jusqu'à
256 MiB. Aucun téléchargement fini dans les `timeout` secondes après l'action est un `Err` de la sorte `"timeout"`, un
téléchargement qui a échoué un `Err` de la sorte `"browser"`.

## Captures d'écran et PDF

`browser.Screenshot` donne les octets d'une image PNG du viewport, ou de la page entière avec `full = true`, ou, avec
`of =` un selector, de son premier élément visible seul, où qu'il soit dans la page, sans la faire défiler. Les octets
sont un texte de Cesia, que `sys.Write` enregistre tel quel :

```cesia norun
use std/sys
save(p) = sys.Write("page.png", browser.Screenshot(p, full = true)?)
chart(p) = sys.Write("chart.png", browser.Screenshot(p, of = browser.ByRole("img", name = "Sales"))?)
```

`browser.Pdf(p)` donne les octets de la page imprimée en PDF, sur du papier au format US Letter avec des marges de 1 cm,
les valeurs par défaut de BiDi. Firefox met environ 2,6 s à imprimer une page, la première fois comme les suivantes.

Firefox envoie l'image en Base64, une façon d'écrire des octets en lettres ; Cesia la décode en OCaml, environ 0,1 ms pour
une capture de 19 KB. Un message de Firefox contient au plus 64 MiB, le `DefaultMaxMessage` de `std/websocket`, si bien
qu'une capture ou un PDF contient au plus 48 MiB : au-delà, la connexion se ferme, et le navigateur est `"closed"`
(fermé).

## Les erreurs

Les erreurs sont des valeurs : chaque fonction donne un `Ok`, ou un `Err` de `{Kind, Message}` (sa sorte et son
message) :

| Kind | Quand |
|---|---|
| `"timeout"` | une attente n'a trouvé aucun élément avant que son temps soit écoulé, une page ne s'est pas chargée à temps, ou Firefox n'a pas répondu à temps |
| `"browser"` | Firefox a refusé une commande : le `Err` a le `Code` de BiDi, comme `no such frame` ou `unknown error`, et son `Message` |
| `"script"` | `Eval` a rencontré une exception, ou une valeur que JSON ne peut pas écrire |
| `"closed"` | le navigateur est parti : il a planté, ou `Firefox` a déjà donné sa réponse |

Une commande qui n'attend pas la page, comme `Screenshot`, a 30 secondes : au-delà, Firefox est tenu pour bloqué, et la
commande donne un `Err` de la sorte `"timeout"`.

## Plusieurs pages à la fois

Plusieurs fibers peuvent piloter un même navigateur à la fois : une fiber de Ceti possède le WebSocket, donne à chaque
commande son numéro, et remet chaque réponse à la fiber qui l'attend, par ce numéro. [fiber.Pmap] lance une fonction sur
chaque élément d'une liste dans une fiber à elle, si bien qu'il capture des pages côte à côte, chacune dans son propre
user context :

```cesia norun
use std/fiber
defn capture(url, b)
  p = browser.NewPage(b)?
  browser.Go(url, p)?
  shot = browser.Screenshot(p)?
  browser.ClosePage(p)?
  shot
end

defn all(b)
  fiber.Pmap(url -> capture(url, b), ["http://127.0.0.1:8080/", "http://127.0.0.1:8080/about"])
end
```

## Dans un test

Un test démarre son propre serveur sur un port libre, avec `net.Listen(0)`, et Firefox, qui est un autre programme,
l'atteint : la sandbox de Cesia ne s'applique qu'au programme Cesia. `[test]` dans `cesia.toml` donne les permissions et
le temps :

```toml
[test]
allow = ["exec=firefox", "net=127.0.0.1", "write=.cesia/firefox"]
timeout = "30"
```

Les tests démarrent Firefox dans `.cesia/firefox`, qui reste d'un test au suivant et d'un lancement de `cesia test` au
suivant, si bien que le template est créé une fois : `write=.cesia/firefox` leur permet d'y écrire, et un test lit déjà
les fichiers de son projet. `.cesia/` est le dossier où `cesia test` garde son propre état, comme les échecs qu'il essaie
en premier au lancement suivant, et `cesia new` le garde hors de git : le template appartient au Firefox de cette machine.
`test.Temp()`, le dossier que `cesia test` donne à chaque test et supprime après lui, recréerait le template à chaque test.

Pour ne payer qu'un démarrage de Firefox pour plusieurs scénarios, un test les lance sur un seul navigateur, chacun sur sa
page, et `cesia test` nomme la partie qui a échoué :

```cesia norun
use std/list

defn heading(url, b)
  p = browser.NewPage(b)?
  browser.Go(url, p)?
  browser.Text("h1", p)
end

defn isPages()
  site = "http://127.0.0.1:8080"
  browser.Firefox(b -> list.All([heading("$site/", b)? == "Home", heading("$site/cart", b)? == "Cart"]), ".cesia/firefox")
end
```

Avec le template, un démarrage de Firefox prend environ 1,0 s, et sa fin environ 0,5 s : regrouper des scénarios fait
gagner environ 1,6 s par démarrage évité.

## Aucun Firefox laissé derrière

Un Firefox headless avec une page prend environ 0,4 GB de mémoire (une mesure). `browser.Firefox` le ferme dans tous les cas pendant que le programme tourne :
après un `Ok`, un `Err` ou une panic de la fonction, et quand la fiber qui l'a appelé est arrêtée par `fiber.Cancel`,
puisqu'il tourne dans une fiber à lui. Il attend que Firefox et les processus qu'il a démarrés se soient terminés, puis
supprime le profil. Si Firefox tourne encore 5 secondes après avoir été fermé, il reçoit le signal TERM (la demande
habituelle de se terminer), et 5 secondes de plus ; ensuite `Firefox` donne un `Err` de la sorte `"browser"`.

Un test qui tourne au-delà de son temps est arrêté par `cesia test`, qui termine à la fin de chaque test les programmes
qu'il a démarrés : le signal TERM, et KILL une seconde plus tard. Ctrl-C et TERM atteignent Firefox aussi. Un `kill -9` du
programme Cesia lui-même laisse Firefox tourner : rien ne peut tourner après lui.

## Pas encore

Chrome et Edge, qui servent BiDi par ChromeDriver, et ont besoin de Chrome sur la machine ; le drag and drop de HTML, que
Firefox 160 headless ne finit pas ; un écran tactile, que Firefox 160 n'a aucune commande pour émuler ; les boutons
Précédent et Suivant ; la vidéo. Chacun viendra quand un vrai besoin le demandera.
