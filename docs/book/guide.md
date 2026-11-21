# Driving Firefox

This chapter drives Firefox from Cesia: start it, open pages, find elements, click and type, read what the page shows,
run JavaScript, capture the screen, and know what went wrong when something does. The examples use the package as a
program does, `use deps/www-celestial/ceti/src/browser`; they are shown and checked, not run, since a site starts no
browser.

## Starting Firefox

`browser.Firefox` starts Firefox and gives it to a function. When the function ends, Firefox closes:

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

Five things happen, in this order:

1. A new folder is made in `work/firefox` for the **profile**, the folder where a browser keeps its settings, its
   cookies and its cache: a copy of the **template** that `work/firefox` keeps for this version of Firefox, the profile
   of a Firefox started once and closed before any page (see [The template profile](#the-template-profile)). Each start
   has a copy of its own, so nothing of one run reaches the next.
2. Firefox starts **headless**, without a window, with `--remote-debugging-port=0`: it serves WebDriver BiDi on a port
   it chooses itself, and writes `WebDriver BiDi listening on ws://127.0.0.1:PORT` on its output. Ceti reads that line,
   for at most 30 seconds.
3. Ceti opens the WebSocket of BiDi, `ws://127.0.0.1:PORT/session`, and the session (`session.new`); it connects to no
   address but `127.0.0.1`. Prompts such as `alert` and `confirm` are dismissed as they open, since no person is there
   to answer them: `confirm` gives `false`. Downloads are refused: without it, a headless Firefox saves what a page
   downloads in the user's download folder, where the program has no `write=`.
4. `title(b)` runs, in a fiber of its own.
5. Whatever `title` gave, an `Ok`, an `Err`, or a panic, Ceti closes Firefox (`browser.close`), waits until it has ended,
   removes the profile, and gives what `title` gave, or panics again if `title` panicked.

`headless = false` shows the window, to look at a problem. `program =` names the command of Firefox when it isn't
`firefox`, as `/Applications/Firefox.app/Contents/MacOS/firefox` on macOS.

### The template profile

A Firefox that starts on an empty profile spends about a second on work that it does only once for a profile: it
registers its built-in modules, makes its databases, and fills its **startup cache**, where it keeps the scripts of its
own interface, compiled, for the next starts. Ceti does that work once per folder. At the first start in `work/firefox`,
it starts Firefox on an empty profile, headless, opens the session and closes it, before any page; it keeps that profile
as the template, `work/firefox/template-Mozilla-Firefox-159.0-20261027034604-20261027034604`. Each start then copies
it, about 36 MB in 21 ms, and Firefox is ready in about 1.0 s instead of 2.1 s ([Speed](speed.md#the-template-profile)).

- **It holds no page's work.** The start that makes it opens no page, and Ceti removes what that start left that is its
  own before it keeps it: its lock, its HTTP cache, its telemetry, its crash reports, its session, and the list of files
  that the startup cache read, which names them by the path of the template.
- **No run changes it.** Firefox runs on the copy, and Ceti removes the copy when Firefox has ended. So no run sees what
  another one did: its cookies, its storage, its cache, its history, its settings. The tests of Ceti check that the
  template is the same, byte for byte, after all of them.
- **There is one for each version of Firefox.** Its name is what `firefox --full-version` writes, the version and the
  build of Firefox, with dashes for its spaces; Ceti asks for it at each start, which takes 30 ms. After an update of Firefox,
  the next start makes the template of the new version and removes the others: Firefox refuses a profile of a later
  version than its own, and does its once-only work again on a profile of an earlier one.
- **The first start in a folder is ready in about 4.2 s**, as it makes the template first. A folder that is thrown away
  after each run, as `test.Temp()`, makes it again at every start: give `Firefox` a folder that stays, as
  `.cesia/firefox` in a project ([In a test](#in-a-test)).

Two programs, or two test files, can start Firefox in one folder at once. When the template isn't there yet, each makes
its own in a folder of its own, `build-` and a number, and renames it to the template's name at once: the first keeps
it, and the other removes its own. A copy never meets a template half made.

The folder can be removed whenever no Firefox runs from it: the next start makes the template again. Beside the
template, a `profile-` folder is the profile of a Firefox that runs, and a `build-` folder a template being made; one
that stays after Firefox has ended comes from a program that a stop signal ended ([No Firefox left
behind](#no-firefox-left-behind)), from a `kill -9`, or from a power cut, and can be removed.

### Permissions

A Cesia program touches nothing outside itself unless its command line allows it. Ceti needs three permissions:

| Permission | Why |
|---|---|
| `exec=firefox` | to start Firefox, and to ask for its version; `exec=` the path given as `program`, when there is one |
| `net=127.0.0.1` | to connect to Firefox, on the port it chose at its start, which no one can write in advance |
| `read=work`, `write=work` | to make the template and the profiles in the folder given to `Firefox`, and to remove the profiles: removing a folder lists it first |

`net=127.0.0.1` opens every port of this machine to the program: a narrower permission would need a new kind of
permission in Cesia, for the ports of the programs it started.

Three more, for some functions only: `read=` for a local file that `browser.Go` opens, `read=` for the files that
`browser.Upload` gives a page, and `write=` for the path where `browser.Download` saves a file.

**`exec=firefox` is total trust**, as `ffi=` is. Cesia's `exec=` names a program, not its arguments: a program that may
start Firefox may start it itself, with any arguments, and drive it over `net=127.0.0.1` as Ceti does. That Firefox
reads and writes every file the user may, as `firefox --screenshot PATH` writes an image at `PATH` or a download goes to
any folder, and reaches every host, past `net=`. So `read=` and `write=` don't confine a program that has
`exec=firefox`: give it only to a program you trust as yourself. What Ceti's own functions keep is narrower: they never
make Firefox read or write, for the program, a file that its permissions don't name. `Go` asks for `read=` of a local
file ([Pages](#pages)), `Upload` for `read=` of each file it gives ([Forms](#forms)), and `Download` saves only at a
path of `write=` ([Downloads](#downloads)). That guards a program that passes on a URL or a path it didn't write
itself, as a crawler that follows links; it doesn't hold back a program that means harm.

**Private folders.** A profile holds the cookies and the storage of its pages while Firefox runs, so Ceti makes the
folder given to `Firefox`, its template, each profile and the folder where a download waits yours alone, with Cesia's
`private = true`: folders 0700, which no one else on the machine can list or enter, and the files it copies or writes
0600. A folder given to `Firefox` that was open to others becomes 0700. One that belongs to someone else, or a template
in it that does, is refused with an `Err` of the kind `"browser"`, since a template that someone else put there would
steer every Firefox started from it, as a proxy in its preferences: give `Firefox` a folder of your own, as
`.cesia/firefox`, never one you share.

## Pages

`browser.NewPage` opens a page in a **user context** of its own: a set of cookies, storage and cache that no other user
context sees, as a private window has. Two pages of one browser don't share a login, so two scenarios can run side by
side in one Firefox:

```cesia norun
defn twoUsers(b)
  ana = browser.NewPage(b)?
  bob = browser.NewPage(b)?
  browser.Go("http://127.0.0.1:8080/", ana)?
  browser.Go("http://127.0.0.1:8080/", bob)?
  browser.Eval("document.cookie", bob)
end
```

Every page is visible, as the page a person looks at: Firefox runs the timers of a hidden tab once a second at most, and
its frames as rarely, which would make the waits slow and the page unlike the real one. So the first page opens beside
the tab Firefox opened at its start, and while it is open, the others open in windows of their own. Opening a page in a
window costs about 0.2 s, against 0.09 s for the first.

`browser.ClosePage` closes a page and its user context, with its tabs and popups. The pages still open close with the
browser, so a program needs it only when it opens many pages.

`browser.Go` goes to a URL and waits for its `load` event, the moment when the page and its images, styles and scripts
have loaded. An address that can't be reached is an `Err` of the kind `"browser"`.

**What Go may read.** Firefox reads the files of this machine itself, outside Cesia's sandbox, so `Go` first asks Cesia
for the file that a `file:` URL names, or a `view-source:` or `jar:` URL of one, with `sys.Stat`: the program needs
`read=` for it, as `sys.Read` does, and without it the program stops with Cesia's message. Ceti reads the URL as
Firefox does: its scheme in any case, its tabs and line ends dropped, `localhost` as its host, its `%XX` decoded and its
`.` and `..` taken away. A `file:` URL in another form, as one that names another host or writes a dot, a slash or a
backslash in `%XX`, is an `Err` of the kind `"browser"`: Ceti takes the plain form, `file:///home/ana/page.html`.

A local page is an origin of its own, as in a Firefox that no program drives: its scripts read no other file of the
machine (Ceti sets `security.fileuri.strict_origin_policy` in each profile, which WebDriver BiDi turns off). A page of
`http:` or `https:` leads Firefox to no file at all: Firefox refuses its links, its frames and its scripts to `file:`.
What `Go` checks is the URL it is given, not where a local page leads: a local page that the program opens may still
show another file of the machine, in a frame, or after a link that the program clicks or a script that it runs with
`Eval`, and `Text` or `Screenshot` then read it. Open local pages only from folders that hold no such page, or serve
them over `http:` from `127.0.0.1`, as the tests of Ceti do.

### The state of a session

A test that signs in once and then runs as that person keeps the **state** of the session: `browser.State(p)` gives the
cookies of `p`'s user context and the `localStorage` of the page's origin, as plain data, `{Cookies, Storage}`, and
`browser.NewPage(b, state = s)` opens a page whose user context starts with them:

```cesia norun
use std/json
use std/result
use std/sys

defn saveSignIn(p)
  sys.Write(".cesia/signed-in.json", json.Text(browser.State(p)?))
end

defn asAna(b)
  s = result.Unwrap(json.Parse(sys.Read(".cesia/signed-in.json")?))
  browser.NewPage(b, state = s)
end
```

Each cookie is `{Name, Value, Domain, Path, HttpOnly, Secure, SameSite, Expires}`, `Expires` in seconds since 1970, or
`missing` for a cookie that ends with the session. `Storage` is `{origin: {key: value}}`; BiDi reads no `localStorage`
of another origin than the page's. To write it, Ceti opens an empty page of that origin, which it answers itself, so no
server sees the request, then leaves the new page on `about:blank`. An origin that isn't `http:` or `https:` is refused.
The file of a state holds what a signed-in person holds: keep it out of git, as in `.cesia/`.

### Emulation

`browser.Emulate(p, ...)` makes the browser present itself otherwise to `p` and to the pages of its user context, its
tabs and popups, until another `Emulate` changes it. It takes what it is given, each one a command of BiDi:

| Parameter | What the page sees | Example |
|---|---|---|
| `viewport = [width, height]` | the size of its viewport, in CSS pixels | `[390, 844]` |
| `scale = n` | the device pixel ratio, how many pixels of the screen a CSS pixel takes | `3` |
| `locale = text` | the language, in `navigator.language` and `Intl` | `"fr-FR"` |
| `timezone = text` | the time zone of its dates | `"Europe/Paris"` |
| `geolocation = [latitude, longitude]` | the place that `navigator.geolocation` gives | `[48.8566, 2.3522]` |
| `offline = true` | a network that is off; `false` puts it back | `true` |

```cesia norun
defn asPhone(p)
  browser.Emulate(p, viewport = [390, 844], scale = 3, locale = "fr-FR", timezone = "Europe/Paris")?
  browser.Go("http://127.0.0.1:8080/", p)
end
```

A page that asks for its position gets the one `Emulate` gave, with no question. Without one, it gets an error at once:
each profile turns off Firefox's ways to learn the machine's own place, a network service and GeoClue, so no page learns
where the machine is. A time zone or a language that Firefox doesn't know is an `Err` of the kind `"browser"`. A touch
screen isn't there: Firefox 160 has no `emulation.setTouchOverride`.

### Tabs and popups

`browser.NewTab(p)` opens a page in the user context of `p`: it shares its cookies and its storage, as a second tab of
one person does, for a test of what one tab sees of another. `browser.NewPage` stays the way to another person.

`browser.Popup(action, p)` runs `action()` and gives the page that a page of `p`'s user context opened meanwhile, by
`window.open` or by a link whose `target` is `_blank`, once it has loaded:

```cesia norun
defn help(p)
  h = browser.Popup(() -> browser.Click(browser.ByRole("link", name = "Help"), p), p)?
  browser.Text("h1", h)
end
```

No page opened within `timeout` seconds after the action is an `Err` of the kind `"timeout"`. A tab and a popup share
`p`'s user context, so they close with `p`; `browser.ClosePage` of one closes it alone.

### Frames

A **frame**, the page that an `<iframe>` shows inside another, has its own document: a selector of the page doesn't
look into it. `browser.Frame(sel, p)` waits for an `iframe` or a `frame` of the selector, shown or not, and gives its
frame as a page, whose functions all work in it, of the page's origin or of another one, as a form of payment served
by a bank:

```cesia norun
defn pay(p)
  card = browser.Frame("#payment", p)?
  browser.Type(browser.ByLabel("Card number"), "4242 4242 4242 4242", card)?
  browser.Click(browser.ByRole("button", name = "Pay"), card)
end
```

A frame closes with its page, so `browser.ClosePage` of a frame is a bug: it panics. A frame that its page removed gives
an `Err` of the kind `"browser"`, `no such frame`.

## Finding an element

Every function that looks for an element takes a **selector**: a CSS text, or a **locator**, which names the element as
a person finds it on the screen.

A text is always a **CSS selector**, the language of style sheets for naming elements: `#go` is the element whose id is
`go`, `.item` each element of the class `item`, `form input[type=email]` each email field in a form. A selector that
isn't CSS, as `div[`, is a bug of the program: the function panics, and the message names the selector.

A locator is made by one of these functions:

| Locator | What it finds |
|---|---|
| `browser.ByRole(role, name = missing, exact = false)` | the elements of an ARIA role, with that accessible name |
| `browser.ByLabel(text, exact = false)` | the fields that a label names |
| `browser.ByText(text, exact = false)` | the innermost elements whose text holds `text` |
| `browser.ByPlaceholder(text, exact = false)` | the fields whose placeholder holds `text` |
| `browser.ByTestId(id)` | the elements whose `data-testid` is `id` |
| `browser.Within(container, inner)` | what `inner` finds inside what `container` finds |

```cesia norun
defn signIn(p)
  browser.Type(browser.ByLabel("Email"), "ana@example.com", p)?
  browser.Type(browser.ByLabel("Password"), "secret", p)?
  browser.Click(browser.ByRole("button", name = "Sign in"), p)
end
```

A test written so reads as the page does for a person, and goes on passing when the page changes its ids or its classes.

**Roles and names.** A **role** is what an element is to a screen reader, a program that reads the page aloud: a
`button`, a `link`, a `textbox`, a `checkbox`, a `heading`, a `row`. An element has one by itself, a `<button>` is a
button and an `<a href>` a link, or by the `role` attribute that the page writes. Its **accessible name** is what a screen
reader says of it: the `aria-labelledby` or the `aria-label` the page gives it, else the label of a field, the `alt` of an
image, or, for a button, a link, a heading, a cell or a row, its text, else its `title` or its `placeholder`. Ceti
computes both in the page, after the W3C texts WAI-ARIA 1.2, HTML-AAM (the roles of HTML elements) and *Accessible Name
and Description Computation 1.2*; its tests check them against Firefox's own accessibility tree, for some forty kinds of
elements. Two notes: a password field has no role, as HTML-AAM says, so find it by its label; and the rows of a table are
named by their text, as ARIA 1.2 says, which Firefox doesn't do itself.

**Matching.** With `name`, a part of the name is enough, and case and runs of spaces don't count: `name = "save"` finds
"Save" and "Save draft". `exact = true` asks for the whole name, case kept. `ByLabel`, `ByText` and `ByPlaceholder`
match in the same way. An element that `aria-hidden="true"` hides from screen readers isn't found by `ByRole`, and a role
that ARIA doesn't have, as `"buton"`, is a bug: the function panics with the list of roles.

**Within.** `browser.Within` looks inside other elements: the Buy button of the row of Coffee, in a table where each row
has its own Buy button:

```cesia norun
buyCoffee(p) = browser.Click(browser.Within(browser.ByRole("row", name = "Coffee"), browser.ByRole("button", name = "Buy")), p)
```

Locators look inside the shadow roots of the page as well, the hidden trees of web components; a CSS text looks in the
document only, as `querySelectorAll` does. An error names the locator in words, as `role button named "Save": no element
matches after 5 s`.

### Waiting by itself

`browser.Click`, `browser.Type`, `browser.Text` and `browser.WaitFor` wait for their element. Each sends one function to
the page, which looks for the first element of the selector that is:

- attached to the document;
- visible: its box isn't empty, and it isn't `visibility: hidden`;
- to click it or type in it, not disabled, and to type in it, not read-only.

The function looks again at each frame the page draws (`requestAnimationFrame`) and at each change of the page
(`MutationObserver`), and answers as soon as it finds one, or when its time is over. The wait is done in the page, in one
**round trip** (one message to Firefox and its answer), rather than by asking the page again and again from Cesia.
The function runs in Ceti's **sandbox** of the page, a realm of BiDi that sees the page's DOM but not its scripts: a
page that changes `JSON.parse` or `querySelectorAll` for itself changes nothing for Ceti. The first wait in a document
puts the function there, once, so each wait after it sends a call of a few bytes, not the function. If
the page goes to another address meanwhile, the function answers so as it leaves, and Ceti looks again in the new page,
until the time is over.

Each of them waits `browser.DefaultTimeout`, 5 seconds, unless `timeout =` gives another time, in seconds:

```cesia norun
defn report(p)
  browser.WaitFor("#report", p, timeout = 30)?
  browser.Text("#report", p)
end
```

At the end of its time, a wait gives an `Err` of the kind `"timeout"` that says what it saw:

```text
#never: no element matches after 5 s
#out: no visible element (1 match, none visible) after 5 s
#go: no visible element that is enabled (1 visible, all disabled) after 5 s
```

What the wait doesn't check: that the element has stopped moving, or that no other element covers it. A click on an
element under another one hits the one on top, as a person's click would, and the test fails where it can be seen.

### After a click that loads another page

A click on a link or on the button of a form, a key that sends a form, or a script of the page that a click runs, can
take the page to another document. Such a click answers once that document has loaded, as `Go` does, within the
click's `timeout`: the next step reads the new page, never the one that went away, and the server has answered the
request, so a test can look at its data at once. A click that loads nothing answers as soon as it is done. There is no
function to call for it:

```cesia norun
defn signIn(p)
  browser.Type(browser.ByLabel("Login"), "ana", p)?
  browser.Click(browser.ByRole("button", name = "Sign in"), p)?   (* answers once the next page has loaded *)
  browser.Text("h1", p)   (* the heading of the page that the form led to *)
end
```

`Press`, `Type`, `Select`, `Check`, `Hover`, `Drag` and `Wheel` wait in the same way when what they do takes the page
to another document. Ceti learns of each navigation from the events of BiDi: `browsingContext.navigationStarted` when
it begins, which Firefox sends before it answers the click, then `browsingContext.load` when its document has loaded.
A navigation that brings no document ends otherwise, and is waited for no more: `navigationFailed` when it failed or
the page refused to leave, `downloadWillBegin` for a download, and `network.fetchError` for an answer
`204 No Content` or a navigation that the page stopped. A page that hasn't loaded in time is an `Err` of the kind
`"timeout"` that names it:

```text
#signin: the page was still loading http://127.0.0.1:8080/invoices after 5 s
```

Ceti asks Firefox for `network.fetchError` only around a click or a key press (`Click`, `Check`, `Uncheck`, `Press`),
from just before it until its navigation has its document: while any event of the network is asked for, Firefox
follows every request of the page, at about 1 ms each, measured, so a `Go` of a page of 20 images would take 19 ms
more. So a navigation that a script of the page begins by itself, as an `Eval` that sets `location` or a timer, and that
brings no document, an answer 204 or a stop, holds each step of that page until its `timeout`, until a `Go` takes the
page elsewhere.

Every step also waits first for a navigation under way in its page, whatever began it: a click in a frame whose link
loads the whole page holds the next step on that page until the new document has loaded. A navigation that a script
begins by itself later, as a timer that changes `location`, may begin while a step runs: `Text` and the other waits for
an element then look again in the new document, but an `Eval` that was running there gets no value. `form.submit()`
and `history.back()` begin their navigation a moment after the script that calls them has ended, so after an `Eval` of
one of them, wait for an element of the new page with `WaitFor`; a click on a button whose handler calls them is
waited for.

Firefox keeps no page in its **back-forward cache** under Ceti, the copy of the last pages that makes a person's Back
instant: a page that `history.back()` brings back loads again, as after a reload, where a person's Firefox may show it
as it was left, its scripts not run again. Firefox 160 tells of a page taken from that cache only that its navigation
started, so a click on Back would wait for a load that never comes.

**A page can't hold a step for ever.** Each wait for a navigation ends at the step's `timeout`, with the address it
waited for. Ceti reads the events of Firefox as any input: a field of the wrong type changes nothing. It follows the
navigations of at most 1,000 browsing contexts at once, so that a page that makes frames without end can't fill the
memory; past them, a new frame's navigation isn't waited for.

## Clicking and typing

`browser.Click` brings the element to the middle of the **viewport**, the part of the page that the window shows, if its
centre is out of it, then moves the mouse to its centre, presses and releases the left button. These are the browser's
own events, made by `input.performActions` of BiDi, as a person's click makes them: `isTrusted` is true, and the
handlers of `mousedown`, `mouseup` and `click` run as they would for a person.

`browser.Type` gives the field the focus, selects what it holds, and types the text key by key: the field then holds
the text. A field is an `input`, a `textarea`, or an element with `contenteditable`. An empty text deletes what the field
held. `"\n"` types a line end in a `textarea`. An `input` of a type that takes no keys in Firefox, `date`, `time`,
`datetime-local`, `month`, `week`, `color` or `range`, gets the text as its value, written as HTML writes it
(`"2026-03-15"`, `"09:30"`, `"#ff0000"`), with the events `input` and `change`; a text it can't take is a bug, and
panics.

`browser.Press` presses one key in the element that has the focus: a character, as `"a"` or `" "`, or a key by its name.
Modifiers go before the key, joined by `+`, and are held while it is pressed:

```cesia norun
defn keys(p)
  browser.Press("Enter", p)?
  browser.Press("Control+A", p)?
  browser.Press("Shift+Tab", p)
end
```

The names are those of the W3C WebDriver standard (§15.6.2): `Backspace`, `Tab`, `Enter`, `Escape`, `PageUp`,
`PageDown`, `End`, `Home`, `ArrowLeft`, `ArrowUp`, `ArrowRight`, `ArrowDown`, `Insert`, `Delete`, `Pause`, `F1` to `F12`,
and the modifiers `Shift`, `Control`, `Alt` and `Meta`. A name that is no key is a bug of the program, and panics with
the list.

## Forms

Beside `Type`, three functions fill a form, and `browser.Value` reads it back:

```cesia norun
defn order(p)
  browser.Select(browser.ByLabel("Country"), "France", p)?
  browser.Select(browser.ByLabel("Toppings"), ["Olives", "Basil"], p)?
  browser.Check(browser.ByLabel("I agree"), p)?
  browser.Uncheck(browser.ByLabel("Send me news"), p)?
  browser.Upload(browser.ByLabel("Photo"), ["tests/pages/photo.png"], p)
end
```

- `browser.Select(sel, labels, p)` chooses the options of a `<select>` by their labels, the text a person reads in the
  list; a list of labels for a select that takes several, which are then its only chosen options. It waits for the
  select, visible and enabled, and for those options, which a page may add late; past its time, the `Err` names the
  option missing. Firefox draws the open list of a select outside the page, where the mouse of BiDi can't reach, so Ceti
  makes the choice in the page and sends `input` and `change`, as the browser does after a person's choice: those two
  events have `isTrusted` false.
- `browser.Check(sel, p)` and `browser.Uncheck(sel, p)` click a checkbox or a radio, as `Click` does, when it isn't
  already as asked, then wait until it is. They take an `input` and an element of the role `checkbox`, `radio` or
  `switch` (its state is `aria-checked`). A click never unchecks a radio, so `Uncheck` of one is a bug, and panics.
- `browser.Upload(sel, files, p)` gives a file field its files, a path or a list of paths, as a person picks them in the
  browser's dialog; `[]` empties it. It waits for an `input` of type `file`, shown or not, since a page often hides it
  behind a button of its own. Firefox sends `input` and `change` itself.

**What Upload may read.** Firefox reads the files itself, outside Cesia's sandbox, so Ceti first asks Cesia for each one
with `sys.Stat`: the program needs `read=` for it, and Cesia follows links, so a link can't lead out of the folders that
`read=` allows; without it, the program stops with Cesia's message, as for any read. Only regular files are taken.
That is what Upload keeps: it gives Firefox no file that the program may not read, whatever path it is handed. It is no
fence around the program, which has `exec=firefox` ([Permissions](#permissions)), and the page gets what each file holds,
as a site gets what a person uploads to it.
Firefox needs absolute paths, and Cesia gives no current folder, so Ceti learns it from Firefox: the absolute path of the
profile, less the relative one Ceti gave it. A relative path is so taken from the current folder when the folder given to
`browser.Firefox` is relative, as `.cesia/firefox`; with an absolute one, as `test.Temp()`, give absolute paths.

## The mouse and the wheel

Beside `Click`, three functions move the mouse of BiDi, whose events are the browser's own:

- `browser.Hover(sel, p)` moves the mouse to the centre of the element, as a person points at it: the page gets
  `mouseover`, `mouseenter` and `mousemove`, and a menu that opens under the mouse opens.
- `browser.Drag(from, to, p)` presses the mouse on the centre of `from`, moves it in small steps to the centre of `to`,
  and releases it there: what lists sorted by hand, sliders and maps listen to, with the events of the mouse and the
  pointer.
- `browser.Wheel(sel, dy, p)` turns the wheel over the element by `dy` pixels, down when `dy` is positive and up when
  it is negative: the element, or the page around it, scrolls as for a person.

```cesia norun
defn sort(p)
  browser.Drag(browser.ByText("Task 3"), browser.ByText("Task 1"), p)?
  browser.Wheel("#feed", 2000, p)
end
```

Firefox scrolls for the wheel on a thread of its own, and the page learns it a frame or two later, so `Wheel` answers
once the page has seen a scroll, or after six frames when nothing could scroll. Each profile turns off smooth
scrolling (`general.smoothScroll` in its `user.js`): a turn of the wheel scrolls at once, as a test needs, rather than
over half a second.

**The drag and drop of HTML**, an element `draggable="true"` and the event `drop`, doesn't end in Firefox 160 headless:
`dragstart`, `dragenter` and `dragover` come, never `drop` nor `dragend`, whatever the order of the moves. Ceti doesn't
make those events itself in JavaScript, as they wouldn't be the browser's: such a test waits for Firefox.

## Reading the page

`browser.Text` gives the text of the first visible element of a selector, once there is one: its `innerText`, the text
as the page shows it, without the tags and with the line breaks of its layout. `browser.Texts` gives the `innerText` of
every element of a selector, as they are now, with no wait: an empty list if none matches. An element that isn't shown,
as one in `display: none`, gives its text as the source holds it.

```cesia norun
items(p) = browser.Texts(".item", p)   (* Ok(["one", "two", "three"]) *)
```

`browser.Value` gives what a field holds, shown or not: the text of an `input` or a `textarea`, `true` or `false` for a
checkbox or a radio, the label of the chosen option of a `<select>`, or a list of them for a select that takes several.
It waits until the field is there:

```cesia norun
quantity(p) = browser.Value(browser.ByLabel("Quantity"), p)   (* Ok("3") *)
```

### Eval

`browser.Eval` gives the value of a JavaScript expression in the page. A **promise**, the value of JavaScript for a result
that comes later, is awaited, at most `timeout` seconds. The value comes as JSON writes it: a number, a text, `true` or
`false`, a list, a dictionary, or `missing` for `null` and `undefined`; a date as its text, `NaN` and the infinities as
`missing`.

```cesia norun
values(p) = browser.Eval("[1, 'two', {three: 3}]", p)   (* Ok([1, "two", {three: 3}]) *)
health(p) = browser.Eval("fetch('/api/health').then((r) => r.status)", p)   (* Ok(200) *)
```

Any other value, as a function, an element or a `Map`, is an `Err` of the kind `"script"` that names it: turn it into one
of those in the expression, as `[...m]` for a `Map` or `el.id` for an element. So is a value that nests deeper than 64
levels, as lists of lists of lists: Firefox writes it no deeper, so that no message is too deep to read. An exception is an `Err` of the kind
`"script"` with its message, as `TypeError: x is undefined`.

## What the page does by itself

A page shows dialogs, writes in its console, opens other pages, sends requests and starts downloads, often after a click.
The functions that wait for one of those take the action that causes it as a function of no argument, and watch before
they run it, so that nothing comes too early to be seen; then they wait for it, at most `timeout` seconds after the
action, 5 by default. The action's own `Err` comes back as it is.

### Dialogs

Firefox tells Ceti of each dialog of a page: `alert`, `confirm`, `prompt`, and the question that `beforeunload` asks
before a page is left. One that no function waits for is dismissed at once, since no person is there to answer it: an
`alert` closes, a `confirm` gives `false`, a `prompt` gives `null`, and the page stays when `beforeunload` asks.

`browser.Dialog(answer, action, p)` answers the first dialog of `p`, its frames, tabs and popups, that opens during
`action()`: `true` accepts it, `false` dismisses it, a text accepts a `prompt` with that text. It gives `{Type, Message,
Default}`, `Type` one of `"alert"`, `"confirm"`, `"prompt"` and `"beforeunload"`, `Default` the text a `prompt` offered:

```cesia norun
defn removeFile(p)
  d = browser.Dialog(true, () -> browser.Click(browser.ByRole("button", name = "Delete"), p), p)?
  d.Message   (* "Delete the file?" *)
end
```

A click that opens a dialog doesn't end until the dialog is answered, since the page waits for the person: `Dialog`
answers it as soon as it opens, and gives its answer once the action has ended. No dialog within `timeout` seconds after
the action is an `Err` of the kind `"timeout"`.

### The console

`browser.Console(p)` gives what the pages of `p`'s user context, `p` and its frames, tabs and popups, wrote in their
console since `p` opened, oldest first: a list of `{Type, Text}`, `Type` the method of the console, as `"log"`, `"info"`,
`"warn"`, `"error"` or `"debug"`, or `"exception"` for an error that no code of the page caught. A test can check that a
page threw nothing:

```cesia norun
use std/value

defn isQuiet(p)
  thrown = [e for e in browser.Console(p)? if e.Type == "exception"]
  value.Len(thrown) == 0
end
```

It keeps the last 1,000 entries of a user context, each cut to its first 16,384 characters, so that a page that logs
without end can't fill the program's memory. It asks Firefox nothing: Ceti keeps the entries as they come.

### The network

`browser.Route(pattern, handler, p)` sends each request of the page whose URL the pattern matches to
`handler(request)`, `request` being `{Url, Method, Headers}`, `Headers` a dictionary of lower-case names. As a handler
of `std/http` does, the handler gives a response, `{Status, Body, Headers}`, each one optional (200, an empty body, no
header), which the page gets instead of the network's; `missing`, and the request goes on to the network as it was; or
an `Err`, and the request fails, as with no network:

```cesia norun
use std/json
use std/result

defn offline(p)
  browser.Route("/api/items", r -> {Status: 200, Body: json.Text([]), Headers: {"content-type": "application/json"}}, p)?
  browser.Route("https://analytics.example.com/*", r -> result.Err("blocked"), p)
end
```

A **pattern** that starts with `/` is matched against the path of the URL, on any origin and without the query:
`/api/items` matches `http://127.0.0.1:8080/api/items?page=2`. Another pattern is matched against the whole URL, as
`https://cdn.example.com/lib.js`. `*` stands for any run of characters: `/api/*`, `https://cdn.example.com/*`. The routes
of a page last as long as it does; when several match a request, the last one given handles it, so a test can make one
answer differ for a while. A route sees the requests of its page, not those of the page's frames or popups.

Each request of a page that has a route waits for Ceti, about one round trip, before it goes on: BiDi has patterns of
its own, which Firefox would match without asking Ceti, but Firefox 160 departs from the standard there (a pattern of a
path doesn't match it with a query, one of a host matched nothing), so Ceti asks for every request of the page and
matches it itself. A handler that panics makes its request fail, and its panic is printed, as a fiber's is.

`browser.Response(pattern, action, p)` runs `action()` and gives the first response of the page whose URL the pattern
matches, once it is complete: `{Url, Method, Status, Headers, Body}`, `Body` the bytes as a text, or `missing` when they
pass 16 MiB:

```cesia norun
defn save(p)
  r = browser.Response("/api/save", () -> browser.Click(browser.ByRole("button", name = "Save"), p), p)?
  r.Status == 201
end
```

A request that fails, as one that no server answers, is an `Err` of the kind `"browser"`.

To see a request itself, as the body that a form sends, a route that gives `missing` sees each request on its way and
lets it go on: its handler can hand the request to a channel of `std/fiber`, which the test then reads.

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

### Downloads

A page's downloads are refused, all of them: without that, a headless Firefox saves what a page downloads in the
user's download folder, where the program has no `write=`. `browser.Download(action, to, p)` runs `action()` and
saves at the path `to` the file that a page of `p`'s user context downloads meanwhile, once it is complete:

```cesia norun
defn export(p)
  d = browser.Download(() -> browser.Click(browser.ByRole("link", name = "Export"), p), "out/report.csv", p)?
  d.Name   (* "report.csv", the name the page gave it; the file is at out/report.csv *)
end
```

It gives `{Url, Name}`. The page chooses nothing of where the file lands: during the action, Firefox may download into a
folder of the profile only, then Ceti moves the file to `to` with `sys.Rename`, which needs `write=` for it; to another
disk than the profile's, it copies the file through the memory, up to 256 MiB. No download that ends within `timeout`
seconds after the action is an `Err` of the kind `"timeout"`, a download that failed one of the kind `"browser"`.

That is what Ceti keeps: a page that Ceti drives saves no file where the program has no `write=`, neither by a
download that no `Download` waits for nor by the name it gives its file, and the file it saves lands at `to` alone. It
doesn't keep the program itself out of a folder, since `exec=firefox` lets it drive a Firefox of its own
([Permissions](#permissions)), nor does it look at what the file holds: a page chooses that.

## Screenshots and PDF

`browser.Screenshot` gives the bytes of a PNG image of the viewport, or of the whole page with `full = true`, or, with
`of =` a selector, of its first visible element alone, wherever it is in the page, without scrolling it. The bytes are
a text of Cesia, which `sys.Write` saves as it is:

```cesia norun
use std/sys
save(p) = sys.Write("page.png", browser.Screenshot(p, full = true)?)
chart(p) = sys.Write("chart.png", browser.Screenshot(p, of = browser.ByRole("img", name = "Sales"))?)
```

`browser.Pdf(p)` gives the bytes of the page printed as a PDF, on paper of the US Letter size with margins of 1 cm, the
defaults of BiDi. Firefox takes about 2.6 s to print a page, the first time and the next ones.

Firefox sends the image in Base64, a way to write bytes as letters; Cesia decodes it in OCaml, about 0.1 ms for a
screenshot of 19 KB. A message of Firefox holds at most 64 MiB, the `DefaultMaxMessage` of `std/websocket`, so a
screenshot or a PDF holds at most 48 MiB. Past it, the connection ends, as a WebSocket can't skip a message, and so does
the session: each step after it gives an `Err` of the kind `"closed"` that says a message passed 64 MiB, and Firefox is
closed with the TERM signal. A page can do it too, with a line of that size in its console, which Firefox sends whole
(`Console` keeps 16 KiB of each). Ceti reads no larger message, so that no page can make the program hold more.

## Errors

Errors are values: each function gives an `Ok`, or an `Err` of `{Kind, Message}`:

| Kind | When |
|---|---|
| `"timeout"` | a wait found no element before its time was over, a page didn't load in time, or Firefox gave no answer in time |
| `"browser"` | Firefox refused a command: the `Err` has the `Code` of BiDi, as `no such frame` or `unknown error`, and its `Message` |
| `"script"` | `Eval` met an exception, or a value that JSON can't write |
| `"closed"` | the browser has gone: it crashed, `Firefox` has given its answer already, or a message of Firefox passed 64 MiB, which ended the session; the `Message` says which |

A command that doesn't wait on the page, as `Screenshot`, has 30 seconds: past them, Firefox is taken for stuck, and the
command gives an `Err` of the kind `"timeout"`.

## Several pages at once

Several fibers can drive one browser at once: one fiber of Ceti owns the WebSocket, gives each command its number, and
hands each answer to the fiber that waits for it, by that number. [fiber.Pmap] runs a function on each element of a
list in a fiber of its own, so it captures pages side by side, each in its own user context:

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

## In a test

A test starts its own server on a free port, with `net.Listen(0)`, and Firefox, which is another program, reaches it: the
sandbox of Cesia applies to the Cesia program only. `[test]` in `cesia.toml` gives the permissions and the time:

```toml
[test]
allow = ["exec=firefox", "net=127.0.0.1", "write=.cesia/firefox"]
timeout = "30"
```

The tests start Firefox in `.cesia/firefox`, which stays from one test to the next and from one run of `cesia test` to
the next, so that the template is made once: `write=.cesia/firefox` lets them write there, and a test reads the files of
its project already. `.cesia/` is the folder where `cesia test` keeps its own state, as the failures it tries first at
the next run, and `cesia new` keeps it out of git: the template belongs to the Firefox of this machine. `test.Temp()`,
the folder that `cesia test` gives each test and removes after it, would make the template again at every test.

To pay for one start of Firefox for several scenarios, a test runs them on one browser, each on its page, and
`cesia test` names the part that failed:

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

With the template, a start of Firefox takes about 1.0 s, and its end about 0.5 s: grouping scenarios saves about 1.6 s
for each start that it spares.

## No Firefox left behind

A headless Firefox with one page takes about 0.4 GB of memory (one measure). `browser.Firefox` closes it in every case while the program runs:
after an `Ok`, an `Err` or a panic of the function, and when the fiber that called it is stopped by `fiber.Cancel`. It
waits until Firefox and the processes it started have ended, then removes the profile. If Firefox still runs 5 seconds
after it was closed, it gets the TERM signal, and 5 seconds more; then `Firefox` gives an `Err` of the kind
`"browser"`.

**A cancelled caller.** `Firefox` runs in a fiber of its own, which nothing else stops, as `sql.Transaction` does, and
its caller says four times a second that it still waits. When `fiber.Cancel` stops the caller, that fiber hears nothing
more: about 1.5 s later it cancels the function, at its next wait, then closes Firefox and removes the profile as after
any end; in all, about 3 s after the cancel. A late word, as when a long computation held the program, cancels nothing:
the fiber takes the caller for stopped only after two waits in a row without one. This holds while the program runs: a
program that ends just after the cancel ends without it, since Cesia ends a program when its own code ends, its other
fibers with it, and stops no program that it started then. Firefox then runs on, and its profile stays. A program that
must end at once tells its function to end, by a channel that the function listens to, and waits for `Firefox`, rather
than cancel it.

A test that runs past its time is stopped by `cesia test`, which ends at the end of each test the programs it started:
the TERM signal, and KILL a second later. A `kill -9` of the Cesia program itself leaves Firefox running: nothing can
run after it.

A stop signal reaches Firefox too: Cesia passes TERM on to the programs it started, and a terminal sends Ctrl-C (INT) to
all of them. Firefox ends; what becomes of its profile depends on the program:

- **A program that doesn't take the stop signals**, as most scripts, ends at once, as Cesia ends it at the first one.
  The profile stays in the folder, as nothing of the program runs after the signal to remove it. It is yours alone
  ([Private folders](#permissions)), and can be removed.
- **A program that takes them**, by `sys.Stops` as a server does, goes on: the function gets an `Err` of the kind
  `"closed"` at its next step, as Firefox has ended, and `Firefox` removes the profile before it gives back what the
  function gave. A second signal ends any program at once, and its profile stays.

## Not yet

Chrome and Edge, which serve BiDi through ChromeDriver, and need Chrome on the machine; the drag and drop of HTML,
which Firefox 160 headless doesn't end; a touch screen, which Firefox 160 has no command to emulate; the back and
forward buttons; video. Each will come when a real need asks for it.
