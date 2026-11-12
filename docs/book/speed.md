# Speed

This page says what each step of Ceti costs, and where the time goes. Every number was measured on one machine
(8 cores, Linux 7.2, Firefox 159.0 headless, Cesia 1.1.0+dev), on 12 November 2026, against the same scenario driven
through raw WebDriver BiDi from Node 26: the same page, the same Firefox, a fresh profile for each run. Raw BiDi is the
floor: the protocol's own messages, written by hand, with no wait, no check and no library around them. These steps were
measured with Ceti v1, which started each Firefox on an empty profile; [The template profile](#the-template-profile)
gives the start and the end of Firefox since Ceti copies a template.

## How it was measured

One run starts Firefox, opens a page, goes to a local page served on 127.0.0.1, types three letters in a field, clicks a
button, reads a text, reads the texts of a list, takes a screenshot, closes the page and quits. In the same browser, it
then repeats 21 times: go to the page, click, read, screenshot, and `Eval("1")`; the median of the 21 is that run's
warm time. Ceti and raw BiDi ran one after the other, 21 times each, alternated, each pair while no other heavy work ran
on the machine. Each figure is the median of the 21 runs, then the first and the third quartile in brackets: half of
the runs lie between them. For the whole scenario and the start, the difference of the medians has its 95% interval,
from 5,000 resamplings of the runs (the bootstrap): an interval that holds 0 shows no difference that these runs can
see.

## The numbers

Times in milliseconds. "Cold" is the first call in a new browser; "warm" is the median of 21 calls in the same browser.

| Step | Ceti | Raw BiDi |
|---|---:|---:|
| ready: start Firefox, its WebSocket, the session | 2,436 [2,088–2,699] | 2,052 [1,922–2,646] |
| `NewPage` (user context and page) | 89.3 [79.1–104.9] | 94.6 [81.6–107.5] |
| `Go`, cold / warm | 94.6 / 15.6 | 101.2 / 15.4 |
| `Type` of 3 letters, cold (raw: find the field, then the keys) | 50.9 [44.6–56.8] | 29.4 [27.8–34.6] |
| `Click`, cold (raw: find the button, then the mouse) | 19.1 [18.0–23.2] | 26.2 [23.7–30.7] |
| `Click`, warm | **10.9** [10.1–11.9] | 7.9 [7.0–8.5] |
| `Text`, cold / warm | 2.0 / **1.6** [1.5–1.6] | 4.9 / 1.1 |
| `Texts` of 3 elements | 1.5 [1.3–1.6] | 2.0 [1.6–2.2] |
| `Screenshot` 1366×682, cold / warm | 24.7 / **19.2** [18.8–20.3] | 19.4 / 18.8 |
| `Eval("1")`, warm | 1.2 [1.1–1.2] | 1.1 [1.1–1.1] |
| `ClosePage` | 18.0 [16.5–21.1] | 14.7 [13.4–15.8] |
| quit: close Firefox, wait for its end, remove the profile | 598 [564–837] | 566 [528–618] |
| the whole scenario | 3,451 [3,016–3,837] | 2,918 [2,757–3,454] |

The start differs by +384 ms, 95% interval [−330, +585], and the whole scenario by +533 ms, [−39, +889]: both hold 0,
as Firefox's own start varies from 1.7 s to 7 s between runs. Ceti's median start was higher in an earlier series of 21
runs too (+246 ms, [−408, +640]), and the Cesia program used no time of the processor while Firefox started (under
10 ms, read from `/proc`): if the difference is real, it lies in how Firefox starts, not in work that Ceti does.

## Where the time goes

- **Firefox's start and end**: on an empty profile, about 2.4 s to be ready, then 0.6 s to end, of the 3.5 s. The
  protocol has no part in them. On the template profile, about 1.0 s and 0.5 s
  ([The template profile](#the-template-profile)).
- **A command costs at least about 1.1 ms**: the WebSocket, the JSON and Firefox's own work. Ceti's own share, its
  JSON, its fibers and its WebSocket client in Cesia, is the difference on `Eval("1")`: 0.1 ms, 95% interval
  [0.0, 0.1].
- **A warm `Click` costs 10.9 ms**, against 7.9 for raw BiDi's find and click: about 6 ms in Firefox for the mouse
  events of `input.performActions`, the same in both, and 4 to 5 ms for the wait, where raw BiDi only finds the element.
  The wait is the first script of a page just loaded, which costs Firefox about 1 ms more than the next ones, and its
  check that the element is visible makes Firefox lay out the page, about 1 ms more. A second click on the same page
  took 6.8 ms (the median of 21, in one run).
- **`Text` costs 0.5 ms more than raw BiDi's read**, for the same reason: it checks that the element is visible.
- **A screenshot costs 19 ms**, nearly all in Firefox, which draws the page and writes the PNG in Base64. Cesia decodes
  the Base64 in OCaml, in about 0.1 ms.

## Ceti in a program's start

A Cesia program reads a package when it uses one of its names. A program that uses Ceti starts in 7.0 ms against 2.5 ms
for `io.Print(1)`, so +4.5 ms, 95% interval [+4.4, +4.7] (21 runs of each, alternated): 2.2 ms for the packages of Cesia
it uses (the WebSocket client, std/encode, std/json) and 2.4 ms for its own code. It is a fifth of a percent of the
2.4 s that Firefox then takes to be ready.

The template profile added about 60 lines of code to Ceti: a program that uses it starts 0.18 ms later, 95% interval
[+0.06, +0.41] (8.40 ms against 8.22 ms for v1, on 12 November, 21 runs of each, alternated), against 1.1 s saved at
each start of Firefox. Cesia compiles a function at its first call, but reads, parses and resolves every line of a
package when a program loads it: the cost follows the lines of code, and comments cost nothing.

## The template profile

Firefox spends about a second of its start on work that it does once for a profile: it registers its built-in modules,
makes its databases, and fills its startup cache. Ceti does it once per folder, in the template, and each start copies
the template ([the guide](guide.md#the-template-profile) says how). These numbers compare Ceti with the template and
Ceti v1, which started each Firefox on an empty profile: 21 rounds, each while no other heavy work ran on the machine,
the order of the two switched at each round. "Ready" is the time from the call of `browser.Firefox` to the start of the
function it calls; "a test" is `cesia test` of a file that holds the test of the README (a page, three letters typed, a
click, a text read), from the start of the process to its end, v1 with `test.Temp()` and Ceti with its kept folder.

| Step | v1, empty profile | Ceti, template | Ceti, first start in a folder |
|---|---:|---:|---:|
| ready | 2,092 [2,011–2,523] | **980** [918–1,125] | 4,223 [3,885–5,073] |
| end: close Firefox, wait for its end, remove the profile | 748 [695–1,169] | 530 [515–749] | 622 [567–982] |
| start and end, with no page | 3,124 [2,738–3,922] | 1,649 [1,443–1,857] | 5,398 [4,742–5,914] |
| a test, from the start of `cesia test` to its end | 2,737 [2,541–2,886] | **1,709** [1,569–1,905] | not measured |

Times in milliseconds, the median of 21 runs and the quartiles in brackets. Ceti with the template minus v1, the
difference of the medians with its 95% interval from 5,000 resamplings: ready −1,112 [−1,390, −955], end −218
[−502, −3], a test −1,029 [−1,171, −849]. The first start in a folder is ready +2,131 [+1,714, +2,911] after v1's.

The first start in a folder makes the template: a start of Firefox on an empty profile, its session, its end, and the
removal of what that start left that is its own, before the start of the run itself. A folder thrown away after each
run, as `test.Temp()`, pays it at every start.

Before Firefox starts, Ceti asks for its version, `firefox --full-version`, in 30 ms, and copies the template,
36 MB, in 21 ms (medians of 21, in Cesia); it removes the copy in 3 ms once Firefox has ended.

### What the template must hold

Indicative, 7 rounds of raw BiDi from Node, each part left out of the template in turn; the ready time, median and
quartiles, in ms:

| Template | Ready |
|---|---:|
| none: an empty profile | 1,839 [1,726–2,175] |
| the whole profile of a first start | 939 [907–1,035] |
| **Ceti's**: that profile without what its start left that is its own | **916** [881–942] |
| the same, from a first start that waited 3 s before it closed | 953 [935–1,063] |
| Ceti's, without the startup cache | 1,460 [1,428–2,060] |
| Ceti's, without the databases of history and icons | 1,077 [990–1,480] |

The startup cache, the compiled scripts of Firefox's own interface, is more than half of the gain. The databases of
history and icons, 10 MB of the 36, save about 0.16 s: Firefox would make them again. What the first start leaves that
is its own, its HTTP cache, telemetry, crash reports and session, saves nothing, so Ceti removes it. A first start that
waits 3 s before it closes leaves the same files, so the template's start closes at once.
