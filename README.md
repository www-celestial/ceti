# Ceti

Ceti drives Firefox from a [Cesia](https://github.com/www-celestial/cesia-lang) program or test: it opens a page, finds
an element as a person does, by its role, its label or its text, clicks, types, fills a form, answers a dialog, mocks or
waits for the network, reads the console, and captures the screen or prints a PDF, as Playwright, Puppeteer and
Selenium do. It speaks
**WebDriver BiDi**, the W3C protocol of browser automation: BiDi stands for bidirectional, as the program sends commands
and the browser sends answers back on one WebSocket connection. Firefox serves BiDi itself, so Ceti needs nothing
but Firefox and Cesia 1.2, and no Node, no driver program, no download of a browser.

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

`exec=firefox` is total trust, as `ffi=` is: a program that may start Firefox may start one of its own, with any
arguments, which reads and writes every file of the user. Give it only to a program you trust; the guide says what
Ceti's own functions keep, under Permissions.

`browser.Firefox(f, dir)` starts Firefox **headless**, without a window, on a new profile in `dir` (a profile is the
folder where a browser keeps its settings, cookies and cache), calls `f` with the browser, then closes Firefox and removes
the profile, whatever `f` gives: an `Ok`, an `Err` or a panic. It is the shape of `sql.Transaction`.

The profile is a copy of the **template** that `dir` keeps for this version of Firefox: the profile of a Firefox started
once and closed before any page, so that each start skips the work of a first start. Firefox is then ready in about
1.0 s instead of 2.1 s. No run changes the template, so no run sees what another one did; it is made at the first start
in `dir`, which is ready in about 4.2 s, and again when Firefox's version changes.

## Install

Ceti is a dependency like any other: a git repository and a tag, in the `[deps]` of `cesia.toml`.

```toml
[deps.ceti]
from = "github.com/www-celestial/ceti"
version = "v0.1.0"
take = ["src/browser"]
```

or `cesia pkg add github.com/www-celestial/ceti@v0.1.0 src/browser`. Firefox must be installed; its command is
`firefox`, or the path given as `program =`. Versions below v1.0.0 are experimental: the API may still change with what
real tests teach.

## The names

The page comes last, as the list does in `list.Map(f, xs)`. Each function that waits takes `timeout =`, 5 seconds by
default.

| Name | What it does |
|---|---|
| `Firefox(f, dir, headless = true, program = "firefox")` | Starts Firefox on a copy of the template that `dir` keeps, calls `f(b)`, closes Firefox, removes its profile, and gives what `f` gave. |
| `NewPage(b, state = missing)` | Opens a page in a **user context** of its own: its cookies and its storage are its own, as in a private window; with `state`, it starts with those of `State`. |
| `NewTab(p)` | Opens a page in the user context of `p`, as a second tab of one person. |
| `ClosePage(p)` | Closes a page and its user context, or a tab or a popup alone. |
| `Go(url, p)` | Goes to a URL and waits for its `load` event. |
| `Click(sel, p)` | Waits for the element, scrolls it into view, and clicks its centre with the mouse; when the click loads another page, it answers once that page has loaded. |
| `Type(sel, text, p)` | Waits for the field, selects what it holds, and types `text` key by key: the field then holds `text`. |
| `Press(key, p)` | Presses a key in the element that has the focus: `"Enter"`, `"Tab"`, `"a"`, `"Control+A"`. |
| `Select(sel, labels, p)` | Chooses the options of a `<select>` by their labels. |
| `Check(sel, p)`, `Uncheck(sel, p)` | Clicks a checkbox or a radio when it isn't as asked, then waits until it is. |
| `Upload(sel, files, p)` | Gives a file field its files, which the program may read. |
| `Hover(sel, p)`, `Drag(from, to, p)`, `Wheel(sel, dy, p)` | Points at an element, drags one onto another, turns the wheel over one. |
| `Text(sel, p)`, `Texts(sel, p)` | The text of the first visible element, once there is one; the texts of all, at once. |
| `Value(sel, p)` | What a field holds: a text, `true` or `false`, the label of the chosen option. |
| `WaitFor(sel, p)` | Waits until an element is visible. |
| `Eval(js, p)` | The value of a JavaScript expression, its promise awaited, as JSON writes it. |
| `Frame(sel, p)` | The frame of an `<iframe>`, as a page. |
| `Dialog(answer, action, p)` | Runs the action and answers the dialog it opens: `true`, `false` or the text of a `prompt`. |
| `Popup(action, p)` | Runs the action and gives the page it opened. |
| `Response(pattern, action, p)` | Runs the action and gives the response to a URL of the pattern, with its body. |
| `Download(action, to, p)` | Runs the action and saves at `to` the file it downloaded. |
| `Route(pattern, handler, p)` | Answers, lets go on or blocks the page's requests to the URLs of the pattern. |
| `Console(p)` | What the page wrote in its console, and the errors no code caught. |
| `State(p)` | The cookies and the `localStorage` of the page, as plain data. |
| `Emulate(p, ...)` | Another viewport, pixel ratio, language, time zone, place, or no network. |
| `Screenshot(p, full = false, of = missing)` | The bytes of a PNG image of the viewport, of the whole page, or of one element. |
| `Pdf(p)` | The bytes of the page printed as a PDF. |
| `ByRole`, `ByLabel`, `ByText`, `ByPlaceholder`, `ByTestId`, `Within` | Locators: name an element as a person finds it, wherever a selector goes. |
| `DefaultTimeout` | 5 seconds: how long each function that waits waits, unless its `timeout =` says otherwise. |

An element is named by a **selector**: a CSS text, as `#go` or `.item`, or a locator, as
`browser.ByRole("button", name = "Save")` or `browser.ByLabel("Email")`, which names it as a person finds it on the
screen: by its role and its accessible name, as a screen reader says it, its label, its text, its placeholder, or a test
id. `browser.Within(container, inner)` looks inside other elements, as the Buy button of the row of Coffee.

## Waiting by itself

Each function that takes a selector sends one call to the page, which looks for an element that is attached to the
document, visible (its box isn't empty, and it isn't `visibility: hidden`) and, to click or type in, not disabled. It looks
again at each frame and at each change of the page, and answers as soon as it finds one, or at the end of its time: **the
wait takes one round trip**, rather than a loop of questions from the program. If the page goes to another address
meanwhile, it looks again in the new one. Ceti's JavaScript runs in a sandbox of BiDi, which sees the page's DOM but not
its scripts, so no page can change what it does.

A click, or a key, that takes the page to another document, as a link or the button of a form does, answers once that
document has loaded, as `Go` does, within its `timeout`: the next step reads the new page, and the server has
answered. A click that loads nothing, or a navigation that brings no document, a download or an answer 204, waits for
nothing.

## Errors

Errors are values: an `Err` of `{Kind, Message}`, its `Kind` one of `"timeout"` (as `#go: no element matches after 5 s`),
`"browser"` (an error of BiDi, with its `Code`, as `no such frame`), `"script"` (an exception in `Eval`) and `"closed"` (the
browser has gone). A selector that isn't CSS, or a role that ARIA doesn't have, is a bug of the program, so it panics, with the selector
in the message.

## In a test

A test of `cesia test` starts its own server on a free port, and Firefox, which is another program, reaches it. The
tests start Firefox in `.cesia/firefox`, which stays from one run of the tests to the next, so that the template is made
once:

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

## No Firefox left behind

`browser.Firefox` closes Firefox when `f` ends, in all three cases, and waits until it has ended before it removes the
profile and gives its answer. A test that runs past its time is stopped by `cesia test`, which ends the programs that the
test started, Firefox among them.

## What it never does

Ceti never hides that a program drives the browser. `navigator.webdriver` stays `true`, as the W3C WebDriver standard
asks of a browser under remote control, and Ceti has no option to change it, no stealth mode, no disguise of the
browser's fingerprint, and nothing that gets past CAPTCHAs or bot detectors.

## Speed

On one machine, with Firefox 160: a `Click` with its wait takes **5.0 ms**, by its role as well (`ByRole`, 4.8 ms,
where Firefox's own accessibility locator takes 11.9), a `Text` **0.9 ms**, a screenshot **21 ms**, and most new steps
within half a millisecond of the same commands written by hand on raw BiDi. Firefox takes about 1.0 s to start on the
template profile and 0.3 s to end, which is most of a short test. [Speed](docs/book/speed.md) has every step, and how
it was measured.

## More

- [The guide](docs/book/guide.md): pages, tabs, popups and frames, locators and the waits, clicks, keys, forms, the
  mouse and the wheel, what the page does by itself (dialogs, the console, the network, downloads), the state of a
  session, emulation, `Eval`, screenshots and PDF, errors, several pages at once, permissions.
- Not yet: Chrome and Edge, which need Chrome on the machine and ChromeDriver; the drag and drop of HTML, which Firefox
  160 headless doesn't end; a touch screen, which Firefox 160 doesn't emulate; video.

MIT licence.
