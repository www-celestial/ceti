# Speed

This page says what each step of Ceti costs, and where the time goes. Every number was measured on one machine
(8 cores, Linux 7.2, Firefox 159.0 headless, Cesia 1.1.0+dev), on 12 November 2026, against the same scenario driven
through raw WebDriver BiDi from Node 26: the same page, the same Firefox, a fresh profile for each run. Raw BiDi is the
floor: the protocol's own messages, written by hand, with no wait, no check and no library around them.

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

- **Firefox's start and end**: about 2.4 s to be ready, then 0.6 s to end, of the 3.5 s. The protocol has no part in
  them. A profile made once and copied for each run gets Firefox ready in about 0.9 s (measured with raw BiDi); Ceti
  doesn't do it yet.
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
