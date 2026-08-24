# Changelog

This project follows Semantic Versioning.

## [0.1.1] - 2026-08-24

### Changed

- Rename the Nimble package, public module namespace, and source tree from
  `terminal_tables` to `terminal_table`.
- Rename the project and repository references from `TerminalTables` and
  `terminal-tables` to `TerminalTable` and `terminal-table`.
- Rename the shared styling dependency and re-exported module from
  `terminal_styles` to `terminal_style`.

## [0.1.0] - 2026-08-24

### Added

- Add pure-Nim `Table`, `Row`, `Column`, and `Cell` models plus a dynamic
  `TableBuilder` for incrementally assembled data.
- Add responsive ANSI- and Unicode-aware rendering with natural, fixed,
  minimum, maximum, and percentage column-width constraints.
- Add word wrapping, character wrapping, truncation, horizontal and vertical
  alignment, cell padding, outer margins, and configurable shrink priorities.
- Add six built-in themes, custom border sets, independently styled borders,
  optional shadows, and plain-text output with styling disabled.
- Add cascading table, column, row, and cell styles while preserving ANSI
  formatting and OSC-8 hyperlinks during layout.
- Add composable selectors and modifiers for highlighting, alignment, padding,
  predicates, rectangular segments, headers, footers, rows, and columns.
- Add titles, top and bottom panels, footers, horizontal and vertical cell
  spans, and validation for overlapping or out-of-bounds spans.
- Add transpose and rotation operations, horizontal and vertical composition,
  merging, and row/column extraction, removal, duplication, and splitting.
- Add opt-in compile-time typed-object conversion plus CSV and JSON adapters,
  keeping macro and parser dependencies out of the core façade.
- Re-export `terminal_styles` from the main package façade so color, style,
  ANSI, and display-width helpers are available from one import.
- Add `renderToTerminalWidth` for responsive rendering against the currently
  detected terminal width.
- Add mutable `LiveTable` displays with explicit start, draw, and stop lifecycle
  methods, resize-safe full-screen redraws, and optional cross-platform
  alternate-screen support.
- Add an in-place live-table mode that preserves earlier terminal content and
  clears the previous frame using its resize-adjusted physical height.
- Add efficient live cell and row replacement, append operations, configurable
  bounded rolling rows, and side-effect-free `renderFrame` output.
- Add efficient, scan-line-free Windows redraws using restored virtual-terminal
  state and viewport-only frame replacement instead of clearing the console
  scrollback.
- Add a simulated real-time service-metrics example with responsive rendering,
  rolling data, Ctrl+C handling, and clean terminal-state restoration.

### Compatibility

- Support Nim 2.0.0 and newer.
- Require `terminal_styles` 0.1.0 or newer.
