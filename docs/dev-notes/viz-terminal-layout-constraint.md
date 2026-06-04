# Viz Service — Terminal Renders Vertically, Not Side-by-Side

**Service:** `services/viz/viz.sh`  
**Subcommands affected:** `grid`, `dashboard`

## The constraint

`ww viz grid` stacks four lens panels vertically rather than displaying them in
a 2×2 grid side-by-side. `ww viz dashboard` does the same. Each panel gets its
own full terminal width.

## Why side-by-side is hard in a terminal

A terminal writes one line at a time from left to right. To display two panels
side by side you need to either:

1. **Buffer each panel's output in memory, then interleave line-by-line.**
   Each panel produces N lines of variable length. You iterate both line arrays
   simultaneously, truncating/padding each to half terminal width, and print
   `left_line + separator + right_line`. This works for fixed-width text panels
   but breaks for panels that include sparklines, Unicode block characters, or
   Python output that isn't width-bounded.

2. **Use a TUI framework** (ncurses, dialog, bash+tput cursor repositioning).
   These let you paint arbitrary regions of the screen, but require the terminal
   to be in raw mode and prevent normal text scrolling. They also make the output
   non-pipeable and non-scriptable.

Neither approach is straightforward in pure bash + Python subprocess output.
Option 1 is achievable but the lens `lens_run()` functions write directly to
stdout with no width contract — forcing them into a fixed column width would
require either rewriting each lens or adding a column-truncation pass.

## Why the question arises here

The reference implementation (WebWarrior-copy `services/viz/`) is a browser-side
JS service. In the browser:

- CSS Grid/Flexbox makes multi-column layout trivial
- Each lens renders into a DOM `<div>` that the layout engine positions
- Panel borders, headers, and scrolling are handled by the browser rendering engine
- No buffering of text output is required

The repos/ww viz service is the terminal equivalent of the same concept, but the
terminal does not have a layout engine. It is a sequential text stream.

## Correct architectural answer

The terminal viz service (`ww viz`) is the right tool for quick CLI inspection and
scripting. For side-by-side multi-panel views, the correct surface is the browser
UI (`ww browser`). When the browser service in repos/ww is fully implemented, the
stream lens outputs should be wired into the browser's viz section there — the
WebWarrior-copy `services/viz/index.js` already shows the full pattern.

The terminal `ww viz` should be kept as a scriptable, pipeable, non-interactive
inspection tool, not pushed toward TUI complexity.

## If you do want side-by-side in the terminal

The simplest approach that stays in bash: buffer each lens to a temp file, then
use `paste` or a Python column-joiner to interleave them at half-width. The
implementation would need a `--columns N` option on `cmd_grid` and a column
splitter that respects Unicode character widths. That is a contained addition to
`lib/layouts.sh` when the need arises.
