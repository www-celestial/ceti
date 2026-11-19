# Changelog

## Unreleased

No release yet: this is what `main` holds, which the README's `v0.1.0` names. Ceti needs Cesia 1.2, the first with a
WebSocket client, and Firefox. Versions below v1.0.0 are experimental: the API may still change with what real tests teach.

Ceti drives Firefox from a Cesia program or test through WebDriver BiDi, the W3C protocol of browser automation, which
Firefox serves itself: no Node, no driver program, no download of a browser.

### Pages

- `browser.Firefox(f, dir)` starts a headless Firefox on a new profile, calls `f`, then closes Firefox and removes the
  profile, whatever `f` gives; each page in its own user context. The profile is a copy of a template made once for each
  version of Firefox: ready in 980 ms instead of 2,092, a test in 1.7 s instead of 2.7 s (21 runs of each).
- `Go`, `Click`, `Type`, `Press`, `Text`, `Texts`, `Value`, `Eval`, `Screenshot` and `WaitFor`, each waiting in the page,
  with `timeout =`, 5 seconds by default. A click, a key or a choice that loads another page answers once it has loaded,
  and every step first waits for a navigation under way.
- `NewTab` and `Popup`, the page an action opened; `Frame`, the frame of an iframe as a page of its own.

### Finding and acting as a person does

- `ByRole`, `ByLabel`, `ByText`, `ByPlaceholder`, `ByTestId` and `Within`, wherever a CSS selector goes, checked against
  Firefox's accessibility tree. The finder lives in Ceti's sandbox of each document, so no script of the page can change
  it: `Text` 1.0 ms instead of 2.5.
- Forms: `Select`, `Check`, `Uncheck` and `Upload`, the last only with files the program may read; `Type` sets a date, a
  time or a colour. `Hover`, `Drag` and `Wheel` move the mouse and turn its wheel.

### Network, dialogs and state

- `Route` answers, lets go on or blocks the requests whose URL a pattern matches, as an HTTP handler does; `Response`
  gives the response an action waited for, with its body.
- `Dialog` answers the dialog an action opens, and a prompt that no `Dialog` waits for is dismissed; `Console` gives what
  the pages wrote in their console.
- `State` gives a page's cookies and localStorage as plain data, and `NewPage(b, state = s)` starts a page with them.
- `Emulate` gives a page another viewport, pixel ratio, language, time zone, place or no network.
- `Download` saves at the program's path the file an action downloads; `Pdf` prints a page; `Screenshot(p, of = sel)`
  captures one element.

### Security

- Ceti dials no address but 127.0.0.1; Firefox writes a download in the profile only, never in the person's download
  folder, and a download path out of its folder is refused before any move; `Eval` asks Firefox for at most 64 levels; a
  message of the wrong shape gives an `Err` or nothing, never a panic of the dispatcher.

### Docs

- The book, its guide and its speed page, in English and in French, each step beside the same step driven through raw
  BiDi from Node.
