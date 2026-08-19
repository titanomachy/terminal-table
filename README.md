# terminal_tables

`terminal_tables` is a pure-Nim toolkit for responsive, styled terminal tables,
from static reports to resize-safe live dashboards and rolling real-time data
feeds. It renders to strings, has no import-time side effects, and depends only
on `terminal_styles` for ANSI parsing and Unicode terminal-cell measurement.

Requires Nim 2.0.0 or newer and `terminal_styles` 0.1.0 or newer.

The implementation is original Nim code. Its feature direction is inspired by
the documented API of Rust's [`tabled`](https://github.com/zhiburt/tabled), not
by copied source.

## Quick start

```nim
import terminal_tables

var table = initTable(["Name", "Role", "Status"])
table.addRow("Alice", "Administrator", green("online"))
table.addRow("Bob", "Developer", yellow("away"))

table.theme = roundedTheme
table.column(1).alignment = alignCenter
table.column(2).alignment = alignRight

echo table.render(maxWidth = 60)
```

Importing `terminal_tables` exposes the complete table API and re-exports
`terminal_styles`, so colors, reusable styles, ANSI stripping, and display-width
helpers need no second import.

Typed-object conversion and CSV/JSON parsing are opt-in modules so the core
façade has no macro or parser cost. Each optional module re-exports the core API,
therefore one import is still sufficient when using an adapter.

## Models and dynamic builders

`Table`, `Row`, `Column`, and `Cell` are public value types. Headers establish a
fixed column count, and ragged rows raise `ValueError` when they are added.

```nim
var table = initTable(["Key", "Value"])
table.addRow("language", "Nim")

# Headerless tables specify their column count.
var log = initTable(Positive(3))
log.addRow("12:00", "info", "started")
```

Use `TableBuilder` when rows arrive incrementally or their shape is only known
at runtime. `build` validates the complete data set.

```nim
var builder = initTableBuilder(["Key", "Value"])
builder.addCell("phase")
builder.addCell("2")
builder.finishRow()
builder.addRow("status", "complete")
let table = builder.build()
```

## Live and real-time tables

`LiveTable` pairs a mutable `Table` with explicit terminal lifecycle methods.
It is data-source agnostic: poll a service, consume events, or receive snapshots
from another thread, then update cells or append rows and call `draw` to publish
the next frame. No timer or background thread is started by the library.
Its default full-screen mode recalculates terminal width, clears the complete
prior frame, and redraws the table on every `draw`. POSIX terminals use an
alternate screen by default, keeping updates out of normal scrollback:

```nim
import std/os
import terminal_tables

var table = initTable(["Service", "Requests", "Status"])
table.addRow("api", 0, "starting")

var live = initLiveTable(table)
live.startLive()
try:
  for requests in [42, 57, 63]:
    live.updateCell(0, 1, requests)
    live.updateCell(0, 2, green("healthy"))
    live.draw()
    sleep(250)
finally:
  live.stopLive()
```

Only `draw` writes a frame, so several cell or row changes can be batched into
one screen update. Use `renderFrame` when the current responsive table is needed
as a string without taking ownership of the terminal.

For event feeds, set a bounded rolling row window. New rows automatically
discard the oldest body rows beyond the limit:

```nim
var options = initLiveTableOptions()
options.maxRows = 20
var live = initLiveTable(initTable(["Time", "Event"]), options)
live.addRow("12:00:01", "worker started")
```

Set `options.mode = ltmInPlace` to preserve terminal content above the table.
In-place redraws calculate the previous frame's physical height at the current
terminal width, including rows introduced by resize wrapping. Full-screen mode
is the most robust choice for dashboards. Set `availableWidth` to a positive
value for deterministic rendering or leave it at zero to detect width on every
frame.

The [`examples/live_data_table.nim`](examples/live_data_table.nim) program
demonstrates a responsive rolling service-metrics feed with simulated incoming
data and clean Ctrl+C restoration.

`LiveTable` is intentionally not internally synchronized. Keep mutation and
`draw` on one rendering thread. A background producer should send immutable
updates or snapshots through a channel, or publish them behind an application
lock, rather than mutating `live.table` concurrently.

## Themes

Six built-in themes cover common output formats:

- `asciiTheme`
- `modernTheme`
- `roundedTheme`
- `borderlessTheme`
- `markdownTheme`
- `psqlTheme`

`customTheme` accepts a `BorderSet` and visibility flags. Every active border
glyph must occupy exactly one terminal cell; invalid and multiline borders are
rejected before rendering.

## Layout

Horizontal alignment uses `alignLeft`, `alignCenter`, and `alignRight`. Vertical
alignment of multiline rows uses `valignTop`, `valignCenter`, and
`valignBottom`.

```nim
table.column(1).alignment = alignRight
table.row(0).setVerticalAlignment(valignCenter)
table.cell(0, 0).setAlignment(alignCenter)
```

Direct assignment is convenient for non-default alignment values. The
`setAlignment`, `setVerticalAlignment`, and `setPadding` procedures record an
explicit override, including an explicit left/top/zero value that would
otherwise mean “inherit”. Settings cascade from table to column to row to cell.

Configure padding inside cells and margins outside the border separately:

```nim
table.padding = initCellPadding(left = 2, right = 2, top = 0, bottom = 0)
table.margin = initTableMargin(left = 1, right = 1, top = 1, bottom = 1)
```

Each column has one content-width rule:

```nim
table.columns[0].width = contentWidth
table.columns[1].width = fixedWidth(16)
table.columns[2].width = minimumWidth(8)
table.columns[3].width = maximumWidth(24)
table.columns[4].width = percentageWidth(30)
```

Widths describe the content area. Padding, separators, borders, and margins are
included automatically when fitting the complete table. `render(maxWidth = 0)`
uses natural widths; a positive width responsively shrinks flexible columns and
raises `ValueError` if fixed/minimum constraints cannot fit.

Set a shrink priority when some flexible columns are more important than
others. Lower values shrink first; columns default to zero.

```nim
table.column(0).setWidthPriority(10) # preserve this column longer
table.column(2).setWidthPriority(-5) # shrink this column first
```

Wrapping defaults to word boundaries. Character wrapping and truncation are
also available, and all three modes preserve ANSI style and OSC hyperlinks.

```nim
table.overflow = overflowWrapCharacters
# or:
table.overflow = overflowTruncate
table.truncationSuffix = "..."
```

## Selectors and modifiers

Selectors are reusable and composable. Row, cell, and segment indexes address
only the zero-based body; a column selector also includes that column in the
header and footer. Predicate selectors can inspect the section, indexes, and
current `Cell`.

```nim
table.highlight(headerSelector() or footerSelector(),
  initTerminalStyle(attributes = {taBold}))
table.align(columnSelector(2), alignRight)
table.pad(segmentSelector(0, 0, 2, 1), initCellPadding(2, 2))

let failures = predicateSelector(proc(context: CellContext): bool =
  context.cell.text == "failed")
table.highlight(failures,
  initTerminalStyle(foreground = colorBrightRed))
```

`matchingCells` returns stable model addresses. `apply` accepts a custom
closure when the built-in `highlight`, `align`, `alignVertical`, and `pad`
modifiers are not enough. A selector union modifies each matching cell once.

## Titles, panels, footers, and spans

Titles and panels are full-width cells. Top panels appear after the title and
before the header; bottom panels appear after body rows and before the footer.

```nim
table.setTitle("Production status")
discard table.addPanel("Updated 12:00 UTC", panelTop)
table.setFooter(["Total", "", "42"])
```

The cell returned by `table.title`, `panel(index)`, or `footerCell(index)` can
be styled and aligned like another cell. `clearTitle` and `clearFooter` remove
the named sections.

Horizontal and vertical spans are anchored by their top-left body cell.
Headers and footers can span horizontally. Covered values stay in the model
and become visible again after `clearSpan`.

```nim
table.cell(0, 0).setSpan(columns = 2)
table.cell(1, 0).setSpan(rows = 3)
table.footerCell(0).setSpan(columns = 3)
```

Spans cannot overlap, leave their section, or cross between header, body, and
footer. Wrapping and ANSI-aware measurement use the combined span width;
internal borders are omitted. The full normative behavior is documented in
[`docs/advanced-layout.md`](docs/advanced-layout.md).

## Transformations and composition

Transformations return independent values and never mutate their input:

```nim
let columnsAsRows = table.transpose()
let clockwise = table.rotateClockwise()
let combined = horizontalConcat(left, right)
let stacked = verticalConcat(top, bottom)
let filled = merge(base, overlay) # overlay fills empty body cells
```

`transpose`, `rotateClockwise`, `rotateCounterClockwise`, and `rotate180`
operate on body data, preserve cell styles, and transform span geometry. They
remove headers and footers because those concepts change axes. Titles and
panels remain attached to the result.

Use `extractRows`, `removeRows`, `duplicateRow`, and `splitRows` for row edits;
the corresponding column procedures are `extractColumns`, `removeColumns`,
`duplicateColumn`, and `splitColumns`. Axis edits reject spans on that axis so
they can never silently cut a merged region.

## Typed objects and data adapters

Convert homogeneous object collections at compile time by importing
`terminal_tables/typed_data`:

```nim
type Build = object
  internalId: int
  name: string
  durationMs: int

proc seconds(value: int): string = $(value div 1000) & "s"

let table = tableFromObjects(builds,
  tableColumn(name, "Build"),             # select and rename
  tableColumn(durationMs, "Time", seconds)) # select and format
```

Column specifications define exact selection and order, so omitted fields are
hidden. Without specifications, all object fields are discovered in declaration
order. Unknown/duplicate fields and incompatible formatter signatures fail at
compile time.

CSV and JSON support are equally explicit:

```nim
import terminal_tables/csv_adapter
let csvTable = tableFromCsv("Name,Score\nAda,10")

import terminal_tables/json_adapter
let jsonTable = tableFromJson("""[{"name":"Ada","score":10}]""")
```

CSV accepts text or files and uses Nim's standard parser. JSON expects an array
of objects and can infer the stable union of keys or use an explicit column
list. Detailed contracts and error behavior are in
[`docs/typed-data.md`](docs/typed-data.md).

Semantic Markdown and HTML exporters are deferred: advanced spans, panels,
multiline values, styling, and hyperlinks need an explicit lossless export
contract rather than implicit data loss. `markdownTheme` remains available for
terminal/plain-text Markdown-style output.

## Styling

Reusable `TerminalStyle` values can be assigned at table, column, row, and cell
scope. Styles cascade in that order, with the most specific color winning and
attributes being combined. `borderStyle` styles the table grid independently.

```nim
table.style = initTerminalStyle(attributes = {taBold})
table.column(0).style = initTerminalStyle(foreground = colorCyan)
table.cell(0, 1).style = initTerminalStyle(background = indexedColor(235))
table.borderStyle = initTerminalStyle(foreground = colorBrightBlack)
```

`colorBorders` is the procedural equivalent for grid styling. An optional
right/bottom shadow is included in responsive width calculations:

```nim
table.colorBorders(initTerminalStyle(foreground = colorBrightBlack))
table.setShadow(initShadow(right = 1, bottom = 1, glyph = "░",
  style = initTerminalStyle(foreground = colorBrightBlack)))
```

Set `table.useColor = false` to remove ANSI already present in values and omit
configured styles, which is useful for redirected or plain-text output.

## Rendering and terminal width

The core renderer is deterministic and never queries the environment:

```nim
let natural = table.render()
let fitted = table.render(maxWidth = 80)
```

`renderToTerminalWidth(fallbackWidth = 80)` explicitly queries the current
terminal at call time. `table.print(maxWidth = 80)` is a convenience that writes
the rendered string plus a newline.

## Development

The examples import the sibling source façade, so they compile both before the
package is published and while developing locally:

```sh
nim c -r examples/basic_table.nim
nim c -r examples/advanced_tables.nim
nim c -r examples/data_adapters.nim
nim c -r examples/live_data_table.nim
nim c -r examples/transform_tables.nim
nim c -r examples/all_tables.nim
nimble test
nimble examples
nimble docs
```

The test suite always passes explicit widths and never depends on the
developer's terminal dimensions. The broader workspace roadmap lives in
[`../terminal_graphs/PLANS/PLAN1.md`](../terminal_graphs/PLANS/PLAN1.md).

The complete example-to-module audit is in
[`docs/public-api.md`](docs/public-api.md). Release history, contribution rules,
third-party declarations, and the release procedure live in `CHANGELOG.md`,
`CONTRIBUTING.md`, `THIRD_PARTY_NOTICES.md`, and `RELEASING.md`.
