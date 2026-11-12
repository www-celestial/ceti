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

1. A new folder is made in `work/firefox` for the **profile**: the folder where a browser keeps its settings, its
   cookies and its cache. Each start has a new one, so nothing of one run reaches the next.
2. Firefox starts **headless**, without a window, with `--remote-debugging-port=0`: it serves WebDriver BiDi on a port
   it chooses itself, and writes `WebDriver BiDi listening on ws://127.0.0.1:PORT` on its output. Ceti reads that line,
   for at most 30 seconds.
3. Ceti opens the WebSocket of BiDi, `ws://127.0.0.1:PORT/session`, and the session (`session.new`). Prompts such as
   `alert` and `confirm` are dismissed as they open, since no person is there to answer them: `confirm` gives `false`.
4. `title(b)` runs, in a fiber of its own.
5. Whatever `title` gave, an `Ok`, an `Err`, or a panic, Ceti closes Firefox (`browser.close`), waits until it has ended,
   removes the profile, and gives what `title` gave, or panics again if `title` panicked.

`headless = false` shows the window, to look at a problem. `program =` names the command of Firefox when it isn't
`firefox`, as `/Applications/Firefox.app/Contents/MacOS/firefox` on macOS.

### Permissions

A Cesia program touches nothing outside itself unless its command line allows it. Ceti needs three permissions:

| Permission | Why |
|---|---|
| `exec=firefox` | to start Firefox; `exec=` the path given as `program`, when there is one |
| `net=127.0.0.1` | to connect to Firefox, on the port it chose at its start, which no one can write in advance |
| `read=work`, `write=work` | to make the profile in the folder given to `Firefox`, and to remove it: removing a folder lists it first |

`net=127.0.0.1` opens every port of this machine to the program: a narrower permission would need a new kind of
permission in Cesia, for the ports of the programs it started.

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

`browser.ClosePage` closes a page and its user context. The pages still open close with the browser, so a program needs
it only when it opens many pages.

`browser.Go` goes to a URL and waits for its `load` event, the moment when the page and its images, styles and scripts
have loaded. An address that can't be reached is an `Err` of the kind `"browser"`.

## Finding an element

An element is named by a **CSS selector**, the language of style sheets for naming elements: `#go` is the element whose
id is `go`, `.item` each element of the class `item`, `form input[type=email]` each email field in a form. It is the only
way to name an element, and it works in every browser. A selector that isn't CSS, as `div[`, is a bug of the program: the
function panics, and the message names the selector.

### Waiting by itself

`browser.Click`, `browser.Type`, `browser.Text` and `browser.WaitFor` wait for their element. Each sends one function to
the page, which looks for the first element of the selector that is:

- attached to the document;
- visible: its box isn't empty, and it isn't `visibility: hidden`;
- to click it or type in it, not disabled, and to type in it, not read-only.

The function looks again at each frame the page draws (`requestAnimationFrame`) and at each change of the page
(`MutationObserver`), and answers as soon as it finds one, or when its time is over. The wait is done in the page, in one
**round trip** (one message to Firefox and its answer), rather than by asking the page again and again from Cesia. If
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

A click that loads another page gives its answer once the click is done, not once the new page has loaded: a `Text` of
an element that both pages have may read the old one. Wait for an element of the new page first, with `WaitFor` or a
`Text` of it.

## Clicking and typing

`browser.Click` brings the element to the middle of the **viewport**, the part of the page that the window shows, if its
centre is out of it, then moves the mouse to its centre, presses and releases the left button. These are the browser's
own events, made by `input.performActions` of BiDi, as a person's click makes them: `isTrusted` is true, and the
handlers of `mousedown`, `mouseup` and `click` run as they would for a person.

`browser.Type` gives the field the focus, selects what it holds, and types the text key by key: the field then holds
the text. A field is an `input`, a `textarea`, or an element with `contenteditable`. An empty text deletes what the field
held. `"\n"` types a line end in a `textarea`.

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

## Reading the page

`browser.Text` gives the text of the first visible element of a selector, once there is one: its `innerText`, the text
as the page shows it, without the tags and with the line breaks of its layout. `browser.Texts` gives the `innerText` of
every element of a selector, as they are now, with no wait: an empty list if none matches. An element that isn't shown,
as one in `display: none`, gives its text as the source holds it.

```cesia norun
items(p) = browser.Texts(".item", p)   (* Ok(["one", "two", "three"]) *)
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
of those in the expression, as `[...m]` for a `Map` or `el.id` for an element. An exception is an `Err` of the kind
`"script"` with its message, as `TypeError: x is undefined`.

## Screenshots

`browser.Screenshot` gives the bytes of a PNG image of the viewport, or of the whole page with `full = true`. The bytes are
a text of Cesia, which `sys.Write` saves as it is:

```cesia norun
use std/sys
save(p) = sys.Write("page.png", browser.Screenshot(p, full = true)?)
```

Firefox sends the image in Base64, a way to write bytes as letters; Cesia decodes it in OCaml, about 0.1 ms for a
screenshot of 19 KB.

## Errors

Errors are values: each function gives an `Ok`, or an `Err` of `{Kind, Message}`:

| Kind | When |
|---|---|
| `"timeout"` | a wait found no element before its time was over, or Firefox gave no answer in time |
| `"browser"` | Firefox refused a command: the `Err` has the `Code` of BiDi, as `no such frame` or `unknown error`, and its `Message` |
| `"script"` | `Eval` met an exception, or a value that JSON can't write |
| `"closed"` | the browser has gone: it crashed, or `Firefox` has given its answer already |

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
sandbox of Cesia applies to the Cesia program only. `[test]` in `cesia.toml` gives the permissions and the time, since a
start of Firefox takes about two seconds:

```toml
[test]
allow = ["exec=firefox", "net=127.0.0.1"]
timeout = "30"
```

`test.Temp()`, the folder that `cesia test` gives each test, is the folder of the profile: it can be read and written
already. To pay for one start of Firefox for several scenarios, a test runs them on one browser, each on its page, and
`cesia test` names the part that failed:

```cesia norun
use std/list
use std/test

defn heading(url, b)
  p = browser.NewPage(b)?
  browser.Go(url, p)?
  browser.Text("h1", p)
end

defn isPages()
  site = "http://127.0.0.1:8080"
  browser.Firefox(b -> list.All([heading("$site/", b)? == "Home", heading("$site/cart", b)? == "Cart"]), test.Temp())
end
```

## No Firefox left behind

A headless Firefox with one page takes about 0.4 GB of memory (one measure). `browser.Firefox` closes it in every case while the program runs:
after an `Ok`, an `Err` or a panic of the function, and when the fiber that called it is stopped by `fiber.Cancel`, as
it runs in a fiber of its own. It waits until Firefox and the processes it started have ended, then removes the profile.
If Firefox still runs 5 seconds after it was closed, it gets the TERM signal, and 5 seconds more; then `Firefox` gives
an `Err` of the kind `"browser"`.

A test that runs past its time is stopped by `cesia test`, which ends at the end of each test the programs it started:
the TERM signal, and KILL a second later. Ctrl-C and TERM reach Firefox too. A `kill -9` of the Cesia program itself
leaves Firefox running: nothing can run after it.

## Not yet

Chrome and Edge, which serve BiDi through ChromeDriver; frames; the network and the console; files to upload; several
windows of one page; phones; PDF and video. Each will come when a real need asks for it.
