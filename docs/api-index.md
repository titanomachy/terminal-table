# TerminalTable API documentation

TerminalTable is a pure-Nim library for responsive, styled, and live terminal
tables. Most applications only need the `terminal_table` façade; the focused
modules are available when a smaller import surface is preferable.

- [Main `terminal_table` façade](terminal_table.html)
- [Search all exported symbols](theindex.html)
- [Package README](https://github.com/titanomachy/terminal-table#readme)
- [Examples](https://github.com/titanomachy/terminal-table/tree/master/examples)

## Install

```
nimble install terminal_style
nimble install terminal_table
```

## Quick start

```nim
import terminal_table

var table = initTable(["Name", "Role", "Status"])
table.addRow("Alice", "Administrator", green("online"))
table.addRow("Bob", "Developer", yellow("away"))
table.theme = roundedTheme

echo table.render(maxWidth = 60)
```

## Core modules

- [`tables`](terminal_table/tables.html) — table, row, column, and cell models.
- [`builders`](terminal_table/builders.html) — incremental runtime table construction.
- [`layouts`](terminal_table/layouts.html) — panels, horizontal and vertical spans, and layout helpers.
- [`themes`](terminal_table/themes.html) — built-in and custom border themes.
- [`renderers`](terminal_table/renderers.html) — responsive string rendering.
- [`selectors`](terminal_table/selectors.html) — row, column, cell, segment, and predicate selection.
- [`modifiers`](terminal_table/modifiers.html) — selection-based styling and layout changes.
- [`transformations`](terminal_table/transformations.html) — transpose, rotate, compose, merge, and extract operations.
- [`live_tables`](terminal_table/live_tables.html) — resize-safe dashboards and rolling live tables.

## Data adapters

- [`typed_data`](typed_data.html) — compile-time object conversion.
- [`csv_adapter`](csv_adapter.html) — CSV parsing and table construction.
- [`json_adapter`](json_adapter.html) — JSON parsing and table construction.

## Generate locally

```
nimble docs
python3 -m http.server 8000 --directory htmldocs
```

Then open [http://localhost:8000](http://localhost:8000). Serving the files over
HTTP allows the generated documentation search to load its index.
