# Changelog

## Unreleased

No release yet: this is what `main` holds, which the README's `v0.1.0` names. Ceti needs Cesia 1.2, the first with a
WebSocket client, and Firefox. Versions below v1.0.0 are experimental: the API may still change with what real tests teach.

Ceti drives Firefox from a Cesia program or test through WebDriver BiDi, the W3C protocol of browser automation, which
Firefox serves itself: no Node, no driver program, no download of a browser.

### Watching a run

- `browser.Firefox(f, dir, slow = 0.5)` waits that many seconds (0 to 60) before each action on a page, a navigation, a
  click, a key, a file, a dialog's answer, and never before a step that only reads, as Playwright's `slowMo`.
- `devtools = true` opens Firefox's developer tools in its window; it needs `headless = false`.
- A dialog that no `Dialog` waits for is dismissed again, after `slow` seconds in a watched run: since `slow =` came,
  the dispatcher's own commands, the dismissal of such a dialog, a request let through and the end of a subscription,
  panicked unseen, so a click that opened an `alert` or a `confirm` never answered.
- Ceti's tests remove, at the start of each test, the profile that a test past its time left in their folder, as
  `cesia test` drops the fibers of such a test and stops its Firefox before Ceti removes it: that one profile made each
  later test of the file fail. The guide says it.

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
- `Go` keeps the program's rights: a `file:` URL, or a `view-source:` or `jar:` one of a file, needs `read=` for that
  file, and a `file:` URL in a form Firefox could read as another file is an `Err`; a local page's scripts read no other
  file, as in a Firefox no program drives. The guide says that `exec=firefox` is total trust, as `ffi=` is.
- Each template, profile and download folder is its owner's alone (0700, the files Ceti copies 0600, `key4.db` and
  `cert9.db` included); they were 0755 and 0644. The folder given to `Firefox` is made 0700 when it isn't there and
  keeps its mode when it is; one of someone else, or one that others may write in, is refused, `/tmp` and its sticky
  bit too, as is a template of someone else. The guide says when a stop signal leaves a profile behind.
- A caller that `fiber.Cancel` stops leaves no Firefox and no profile behind while the program runs: the function is
  cancelled, then Firefox closed and the profile removed, about 3 s after the cancel; they ran on before, for good if
  the program ended meanwhile.
- A message of Firefox past 64 MiB, as a page's console line that large, ends the session with an `Err` that says so,
  rather than "Firefox has closed.", and Firefox is closed at once: it took 10 s more and printed a panic.
- A Firefox slow to end no longer prints the panic "This process has ended.": Ceti stops reading its output before it
  takes its exit. The first start in a folder has 30 s to end rather than 5, so a loaded machine keeps its template.
- A download no longer goes into the desktop's list of recent files, `~/.local/share/recently-used.xbel`, and the
  guide says what Firefox still keeps in the home: a few folders, the caches of its libraries, and GIO's record of the
  address of each download.
- The site's build fails when the download of the nightly Cesia fails; only a nightly that isn't there yet counts as
  none. It passed green before, with nothing built or checked.

### Docs

- The book, its guide and its speed page, in English and in French, each step beside the same step driven through raw
  BiDi from Node.
- The examples write `x!`, Cesia's unwrap of a result, for `result.Unwrap(x)`.
