## High-level modifications built on composable cell selectors.

import ./selectors

export selectors

proc mergedStyle(base, overlay: TerminalStyle): TerminalStyle =
  result = base
  if overlay.foreground.kind != tckDefault:
    result.foreground = overlay.foreground
  if overlay.background.kind != tckDefault:
    result.background = overlay.background
  result.attributes = result.attributes + overlay.attributes

proc highlight*(table: var Table; selector: Selector;
                style: TerminalStyle) =
  ## Cascades ``style`` onto selected cells.
  table.apply(selector, proc(cell: var Cell) =
    cell.style = mergedStyle(cell.style, style))

proc align*(table: var Table; selector: Selector;
            alignment: TextAlignment) =
  ## Sets horizontal alignment on selected cells.
  table.apply(selector, proc(cell: var Cell) =
    cell.setAlignment(alignment))

proc alignVertical*(table: var Table; selector: Selector;
                    alignment: VerticalAlignment) =
  ## Sets vertical alignment on selected cells.
  table.apply(selector, proc(cell: var Cell) =
    cell.setVerticalAlignment(alignment))

proc pad*(table: var Table; selector: Selector; padding: CellPadding) =
  ## Sets padding on selected cells.
  table.apply(selector, proc(cell: var Cell) = cell.setPadding(padding))

proc colorBorders*(table: var Table; style: TerminalStyle) =
  ## Styles all grid, intersection, and outer-border glyphs.
  table.borderStyle = style

proc setShadow*(table: var Table; shadow: Shadow) =
  ## Enables or replaces the table shadow.
  table.shadow = shadow

proc clearShadow*(table: var Table) =
  ## Disables the right and bottom shadow.
  table.shadow = Shadow()
