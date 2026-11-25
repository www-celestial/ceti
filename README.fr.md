# Ceti

Ceti pilote Firefox depuis un programme ou un test [Cesia](https://github.com/www-celestial/cesia-lang) : il ouvre une
page, trouve un élément comme le fait une personne, par son rôle, son label ou son texte, clique, tape, remplit un
formulaire, répond à un dialogue, simule ou attend le réseau, lit la console, et capture l'écran ou imprime un PDF, comme
le font Playwright, Puppeteer et Selenium. Il parle
**WebDriver BiDi**, le protocole du W3C pour l'automatisation des navigateurs : BiDi veut dire bidirectionnel, puisque le
programme envoie des commandes et que le navigateur renvoie des réponses sur une seule connexion WebSocket (une connexion
qui reste ouverte, où les messages vont dans les deux sens). Firefox sert BiDi lui-même, si bien que Ceti n'a besoin que
de Firefox et de Cesia 1.2, et ni de Node, ni d'un programme pilote (driver), ni du téléchargement d'un navigateur.

**Documentation : https://www-celestial.github.io/ceti/fr/** (en anglais : https://www-celestial.github.io/ceti/)

La famille : [Cesia](https://www-celestial.github.io/cesia-lang/fr/) (le langage) · [Cemacs](https://www-celestial.github.io/cemacs/fr/) (l'éditeur) ·
[Cepheus](https://www-celestial.github.io/cepheus/fr/) (la base de données) · [Ceti](https://www-celestial.github.io/ceti/fr/) (le pilote de navigateur).

```cesia
use deps/www-celestial/ceti/src/browser
use std/sys
use std/io

defn visit(b)
  p = browser.NewPage(b)?
  browser.Go("http://127.0.0.1:8080/", p)?
  browser.Type(browser.ByLabel("Name"), "Ana", p)?
  browser.Click(browser.ByRole("button", name = "Go"), p)?
  io.Print(browser.Text("#out", p)?)
  sys.Write("page.png", browser.Screenshot(p)?)
end

browser.Firefox(visit, "work/firefox")
```

```bash
cesia run --allow exec=firefox,net=127.0.0.1,read=work,write=work,write=page.png visit.ce
```

`browser.Firefox(f, dir)` démarre Firefox **headless**, sans fenêtre, sur un nouveau profil dans `dir` (un profil est le
dossier où un navigateur garde ses réglages, ses cookies et son cache), appelle `f` avec le navigateur, puis ferme Firefox
et supprime le profil, quoi que donne `f` : un `Ok`, un `Err` ou une panic (l'arrêt d'un programme sur un bug). C'est la
forme de `sql.Transaction`.

Le profil est une copie du **template** (le profil modèle) que `dir` garde pour cette version de Firefox : le profil d'un
Firefox démarré une fois et fermé avant toute page, si bien que chaque démarrage saute le travail d'un premier démarrage.
Firefox est alors prêt en environ 1,0 s au lieu de 2,1 s. Aucun lancement ne modifie le template, si bien qu'aucun
lancement ne voit ce qu'un autre a fait ; il est créé au premier démarrage dans `dir`, qui est prêt en environ 4,2 s, et à
nouveau quand la version de Firefox change.

## Installation

Ceti est une dépendance comme une autre : un dépôt git et un tag (une version nommée), dans les `[deps]` de `cesia.toml`.

```toml
[deps.ceti]
from = "github.com/www-celestial/ceti"
version = "v0.1.0"
take = ["src/browser"]
```

ou `cesia pkg add github.com/www-celestial/ceti@v0.1.0 src/browser`. Firefox doit être installé ; sa commande est
`firefox`, ou le chemin donné comme `program =`. Les versions avant v1.0.0 sont expérimentales : l'API peut encore changer
avec ce qu'apprennent de vrais tests.

## Les noms

La page vient en dernier, comme la liste le fait dans `list.Map(f, xs)`. Chaque fonction qui attend prend `timeout =`, 5
secondes par défaut.

| Nom | Ce qu'il fait |
|---|---|
| `Firefox(f, dir, headless = true, program = "firefox")` | Démarre Firefox sur une copie du template que garde `dir`, appelle `f(b)`, ferme Firefox, supprime son profil, et donne ce que `f` a donné. |
| `NewPage(b, state = missing)` | Ouvre une page dans un **user context** (un contexte d'utilisateur) à elle : ses cookies et son stockage sont les siens, comme dans une fenêtre de navigation privée ; avec `state`, elle commence avec ceux de `State`. |
| `NewTab(p)` | Ouvre une page dans le user context de `p`, comme un second tab (un second onglet) d'une même personne. |
| `ClosePage(p)` | Ferme une page et son user context, ou un tab ou une popup (une fenêtre qu'une page ouvre d'elle-même) seul. |
| `Go(url, p)` | Va à une URL et attend son événement `load`. |
| `Click(sel, p)` | Attend l'élément, le fait défiler jusqu'à le voir, et clique en son centre avec la souris ; quand le clic charge une autre page, il répond une fois cette page chargée. |
| `Type(sel, text, p)` | Attend le champ, sélectionne ce qu'il contient, et tape `text` touche par touche : le champ contient alors `text`. |
| `Press(key, p)` | Appuie sur une touche dans l'élément qui a le focus : `"Enter"`, `"Tab"`, `"a"`, `"Control+A"`. |
| `Select(sel, labels, p)` | Choisit les options d'un `<select>` par leurs labels. |
| `Check(sel, p)`, `Uncheck(sel, p)` | Clique sur une checkbox (une case à cocher) ou un radio quand elle n'est pas comme demandé, puis attend qu'elle le soit. |
| `Upload(sel, files, p)` | Donne à un champ de fichier ses fichiers, que le programme a le droit de lire. |
| `Hover(sel, p)`, `Drag(from, to, p)`, `Wheel(sel, dy, p)` | Pointe un élément, en fait glisser un sur un autre, tourne la molette au-dessus d'un élément. |
| `Text(sel, p)`, `Texts(sel, p)` | Le texte du premier élément visible, dès qu'il y en a un ; les textes de tous, tout de suite. |
| `Value(sel, p)` | Ce que contient un champ : un texte, `true` ou `false`, le label de l'option choisie. |
| `WaitFor(sel, p)` | Attend qu'un élément soit visible. |
| `Eval(js, p)` | La valeur d'une expression JavaScript, sa promise (un résultat qui vient plus tard) attendue, comme JSON l'écrit. |
| `Frame(sel, p)` | La frame d'un `<iframe>` (la page montrée dans une autre), comme une page. |
| `Dialog(answer, action, p)` | Lance l'action et répond au dialogue qu'elle ouvre : `true`, `false` ou le texte d'un `prompt`. |
| `Popup(action, p)` | Lance l'action et donne la page qu'elle a ouverte. |
| `Response(pattern, action, p)` | Lance l'action et donne la réponse à une URL du motif, avec son corps. |
| `Download(action, to, p)` | Lance l'action et enregistre à `to` le fichier qu'elle a téléchargé. |
| `Route(pattern, handler, p)` | Répond aux requêtes de la page vers les URL du motif, les laisse continuer ou les bloque. |
| `Console(p)` | Ce que la page a écrit dans sa console, et les erreurs qu'aucun code n'a attrapées. |
| `State(p)` | Les cookies et le `localStorage` de la page, en données simples. |
| `Emulate(p, ...)` | Un autre viewport (la partie de la page que montre la fenêtre), un autre pixel ratio, une autre langue, un autre fuseau horaire, un autre lieu, ou pas de réseau. |
| `Screenshot(p, full = false, of = missing)` | Les octets d'une image PNG du viewport, de la page entière, ou d'un seul élément. |
| `Pdf(p)` | Les octets de la page imprimée en PDF. |
| `ByRole`, `ByLabel`, `ByText`, `ByPlaceholder`, `ByTestId`, `Within` | Les locators : ils nomment un élément comme une personne le trouve, partout où va un selector. |
| `DefaultTimeout` | 5 secondes : combien de temps attend chaque fonction qui attend, à moins que son `timeout =` ne dise autre chose. |

Un élément est nommé par un **selector** (ce qui désigne un élément) : un texte CSS, comme `#go` ou `.item`, ou un locator,
comme
`browser.ByRole("button", name = "Save")` ou `browser.ByLabel("Email")`, qui le nomme comme une personne le trouve à
l'écran : par son rôle et son nom accessible, comme un lecteur d'écran le dit, son label, son texte, son placeholder (le
texte grisé d'un champ vide), ou un id de test. `browser.Within(container, inner)` regarde à l'intérieur d'autres
éléments, comme le bouton Buy (acheter) de la rangée de Coffee (café).

## L'attente qui se fait seule

Chaque fonction qui prend un selector envoie un seul appel à la page, qui cherche un élément attaché au document, visible
(sa boîte n'est pas vide, et il n'est pas en `visibility: hidden`) et, pour cliquer ou y taper, non désactivé. Elle
cherche à nouveau à chaque frame (chaque image que dessine la page) et à chaque changement de la page, et répond dès
qu'elle en trouve un, ou à la fin de son temps : **l'attente prend un seul round trip** (un aller-retour avec Firefox),
plutôt qu'une boucle de questions du programme. Si la page va à une autre adresse pendant ce temps, elle cherche à
nouveau dans la nouvelle. Le JavaScript de Ceti tourne dans une sandbox de BiDi (un bac à sable), qui voit le DOM de la
page (l'arbre de ses éléments) mais pas ses scripts, si bien qu'aucune page ne peut changer ce qu'il fait.

Un clic, ou une touche, qui emmène la page vers un autre document, comme le fait un lien ou le bouton d'un formulaire,
répond une fois ce document chargé, comme le fait `Go`, dans son `timeout` : l'étape suivante lit la nouvelle page, et le
serveur a répondu. Un clic qui ne charge rien, ou une navigation qui n'apporte aucun document, un téléchargement ou une
réponse 204, n'attend rien.

## Les erreurs

Les erreurs sont des valeurs : un `Err` de `{Kind, Message}`, son `Kind` (sa sorte) l'un de `"timeout"` (comme
`#go: no element matches after 5 s`, aucun élément ne correspond après 5 s), `"browser"` (une erreur de BiDi, avec son
`Code`, comme `no such frame`), `"script"` (une exception dans `Eval`) et `"closed"` (le navigateur est parti). Un
selector qui n'est pas du CSS, ou un rôle qu'ARIA n'a pas, est un bug du programme, alors il fait une panic, avec le
selector dans le message.

## Dans un test

Un test de `cesia test` démarre son propre serveur sur un port libre, et Firefox, qui est un autre programme, l'atteint.
Les tests démarrent Firefox dans `.cesia/firefox`, qui reste d'un lancement des tests au suivant, si bien que le template
est créé une fois :

```toml
[test]
allow = ["exec=firefox", "net=127.0.0.1", "write=.cesia/firefox"]
timeout = "30"
```

```cesia
use deps/www-celestial/ceti/src/browser
use std/http
use std/net
use std/fiber

defn isSignIn()
  l = net.Listen(0)?
  fiber.Spawn(() -> http.Serve(http.App() then http.Static("/", "tests/pages"), listener = l))
  browser.Firefox(defn (b)
    p = browser.NewPage(b)?
    browser.Go("http://127.0.0.1:$(net.Port(l))/index.html", p)?
    browser.Type("#name", "Ana", p)?
    browser.Click("#go", p)?
    browser.Text("#out", p)? == "clicked by Ana"
  end, ".cesia/firefox")
end
```

## Aucun Firefox laissé derrière

`browser.Firefox` ferme Firefox quand `f` se termine, dans les trois cas, et attend qu'il se soit terminé avant de
supprimer le profil et de donner sa réponse. Un test qui tourne au-delà de son temps est arrêté par `cesia test`, qui
termine les programmes que le test a démarrés, Firefox parmi eux.

## Ce qu'il ne fait jamais

Ceti ne cache jamais qu'un programme pilote le navigateur. `navigator.webdriver` reste `true`, comme le standard W3C
WebDriver le demande d'un navigateur sous contrôle à distance, et Ceti n'a aucune option pour le changer, aucun mode
furtif, aucun déguisement de l'empreinte du navigateur (ce qui le distingue des autres), et rien qui passe les CAPTCHA ou
les détecteurs de robots.

## Vitesse

Sur une seule machine, avec Firefox 160 : un `Click` avec son attente prend **5,0 ms**, par son rôle aussi (`ByRole`,
4,8 ms, là où le propre locator d'accessibilité de Firefox prend 11,9), un `Text` **0,9 ms**, une capture d'écran
**21 ms**, et la plupart des nouvelles étapes sont à moins d'une demi-milliseconde des mêmes commandes écrites à la main
sur BiDi brut. Firefox prend environ 1,0 s pour démarrer sur le template de profil et 0,3 s pour finir, ce qui fait
l'essentiel d'un test court. [Vitesse](docs/fr/book/speed.md) donne chaque étape, et comment elle a été mesurée.

## Plus

- [Le guide](docs/fr/book/guide.md) : les pages, les tabs, les popups et les frames, les locators et les attentes, les
  clics, les touches, les formulaires, la souris et la molette, ce que la page fait d'elle-même (les dialogues, la
  console, le réseau, les téléchargements), l'état d'une session, l'émulation, `Eval`, les captures d'écran et le PDF, les
  erreurs, plusieurs pages à la fois, les permissions.
- Pas encore : Chrome et Edge, qui ont besoin de Chrome sur la machine et de ChromeDriver ; le drag and drop de HTML (le
  glisser-déposer), que Firefox 160 headless ne finit pas ; un écran tactile, que Firefox 160 n'émule pas ; la vidéo.

Licence MIT.
