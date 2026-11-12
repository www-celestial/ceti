# Ceti

Ceti drives Firefox from a [Cesia](https://github.com/www-celestial/cesia-lang) program or test: it opens a page, clicks,
types, reads a text and captures the screen, as Playwright, Puppeteer and Selenium do. It speaks
**WebDriver BiDi**, the W3C protocol of browser automation: BiDi stands for bidirectional, as the program sends commands
and the browser sends answers back on one WebSocket connection. Firefox serves BiDi itself, so Ceti needs nothing
but Firefox and Cesia 1.1, and no Node, no driver program, no download of a browser.

```cesia
use deps/www-celestial/ceti/src/browser
use std/sys
use std/io

defn visit(b)
  p = browser.NewPage(b)?
  browser.Go("http://127.0.0.1:8080/", p)?
  browser.Type("#name", "Ana", p)?
  browser.Click("#go", p)?
  io.Print(browser.Text("#out", p)?)
  sys.Write("page.png", browser.Screenshot(p)?)
end

browser.Firefox(visit, "work/firefox")
```

```bash
cesia run --allow exec=firefox,net=127.0.0.1,read=work,write=work,write=page.png visit.ce
```

`browser.Firefox(f, dir)` starts Firefox **headless**, without a window, on a new profile in `dir` (a profile is the
folder where a browser keeps its settings, cookies and cache), calls `f` with the browser, then closes Firefox and removes
the profile, whatever `f` gives: an `Ok`, an `Err` or a panic. It is the shape of `sql.Transaction`.

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

| Name | What it does |
|---|---|
| `Firefox(f, dir, headless = true, program = "firefox")` | Starts Firefox, calls `f(b)`, closes Firefox, removes its profile, and gives what `f` gave. |
| `NewPage(b)` | Opens a page in a **user context** of its own: its cookies and its storage are its own, as in a private window. |
| `ClosePage(p)` | Closes a page and its user context. The pages still open close with the browser. |
| `Go(url, p)` | Goes to a URL and waits for its `load` event. |
| `Click(sel, p)` | Waits for the element, scrolls it into view, and clicks its centre with the mouse. |
| `Type(sel, text, p)` | Waits for the field, selects what it holds, and types `text` key by key: the field then holds `text`. |
| `Press(key, p)` | Presses a key in the element that has the focus: `"Enter"`, `"Tab"`, `"a"`, `"Control+A"`. |
| `Text(sel, p)` | The text of the first visible element, `innerText`, once there is one. |
| `Texts(sel, p)` | The texts of all the elements, as they are now, without waiting. |
| `Eval(js, p)` | The value of a JavaScript expression, its promise awaited, as JSON writes it. |
| `Screenshot(p, full = false)` | The bytes of a PNG image of the viewport, or of the whole page. |
| `WaitFor(sel, p)` | Waits until an element is visible. |
| `DefaultTimeout` | 5 seconds: how long each function that waits waits, unless its `timeout =` says otherwise. |

An element is named by a **CSS selector**, as `#go` or `.item`: one way to name an element, which works everywhere. The page
comes last, as the list does in `list.Map(f, xs)`.

## Waiting by itself

`Click`, `Type`, `Text` and `WaitFor` send one function to the page, which looks for an element that is attached to the
document, visible (its box isn't empty, and it isn't `visibility: hidden`) and, to click or type in, not disabled. It looks
again at each frame and at each change of the page, and answers as soon as it finds one, or at the end of its time: **the
wait takes one round trip**, rather than a loop of questions from the program. If the page goes to another address
meanwhile, it looks again in the new one.

## Errors

Errors are values: an `Err` of `{Kind, Message}`, its `Kind` one of `"timeout"` (as `#go: no element matches after 5 s`),
`"browser"` (an error of BiDi, with its `Code`, as `no such frame`), `"script"` (an exception in `Eval`) and `"closed"` (the
browser has gone). A selector that isn't CSS is a bug of the program, so it panics, with the selector in the message.

## In a test

A test of `cesia test` starts its own server on a free port, and Firefox, which is another program, reaches it:

```toml
[test]
allow = ["exec=firefox", "net=127.0.0.1"]
timeout = "30"
```

```cesia
use deps/www-celestial/ceti/src/browser
use std/http
use std/net
use std/fiber
use std/test

defn isSignIn()
  l = net.Listen(0)?
  fiber.Spawn(() -> http.Serve(http.App() then http.Static("/", "tests/pages"), listener = l))
  browser.Firefox(defn (b)
    p = browser.NewPage(b)?
    browser.Go("http://127.0.0.1:$(net.Port(l))/index.html", p)?
    browser.Type("#name", "Ana", p)?
    browser.Click("#go", p)?
    browser.Text("#out", p)? == "clicked by Ana"
  end, test.Temp())
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

On one machine, with Firefox 159: a `Click` with its wait takes **10.9 ms**, a `Text` **1.6 ms**, a screenshot
**19.2 ms**, and each command 0.1 ms more than the same command written by hand on raw BiDi. Firefox takes about 2 s to
start and 0.6 s to end, which is most of a short test. [Speed](docs/book/speed.md) has every step, and how it was
measured.

## More

- [The guide](docs/book/guide.md): pages, waits, keys, `Eval`, screenshots, errors, several pages at once, permissions.
- Not yet: Chrome and Edge (next), frames, the network and the console, files to upload, phones.

MIT licence.
