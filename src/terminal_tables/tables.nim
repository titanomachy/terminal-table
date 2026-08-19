## Core table, row, cell, and column data model.

import std/strformat

import terminal_styles
import ./[layouts, themes]

export terminal_styles, layouts, themes

type
  Cell* = object
    ## Text and optional layout/style overrides for one table cell.
    text*: string
    alignment*: TextAlignment
    verticalAlignment*: VerticalAlignment
    padding*: CellPadding
    style*: TerminalStyle
    hasAlignment*, hasVerticalAlignment*, hasPadding*: bool
    columnSpan*, rowSpan*: int

  Row* = object
    ## An ordered collection of cells with optional shared overrides.
    cells*: seq[Cell]
    alignment*: TextAlignment
    verticalAlignment*: VerticalAlignment
    padding*: CellPadding
    style*: TerminalStyle
    hasAlignment*, hasVerticalAlignment*, hasPadding*: bool

  Column* = object
    ## Layout, width, and style settings for one column.
    width*: WidthConstraint
    alignment*: TextAlignment
    verticalAlignment*: VerticalAlignment
    padding*: CellPadding
    style*: TerminalStyle
    hasAlignment*, hasVerticalAlignment*, hasPadding*: bool
    widthPriority*: int

  Panel* = object
    ## One full-width cell rendered above or below the normal grid.
    cell*: Cell
    position*: PanelPosition

  Table* = object
    ## A complete table model. Rendering never mutates it.
    header*: Row
    hasHeader*: bool
    footer*: Row
    hasFooter*: bool
    title*: Cell
    hasTitle*: bool
    panels*: seq[Panel]
    rows*: seq[Row]
    columns*: seq[Column]
    theme*: TableTheme
    alignment*: TextAlignment
    verticalAlignment*: VerticalAlignment
    padding*: CellPadding
    margin*: TableMargin
    overflow*: OverflowMode
    truncationSuffix*: string
    style*: TerminalStyle
    borderStyle*: TerminalStyle
    shadow*: Shadow
    useColor*: bool

proc initCell*(text: string): Cell =
  ## Creates a cell containing ``text``. Newlines are supported.
  Cell(text: text, columnSpan: 1, rowSpan: 1)

proc initRow*(values: openArray[string]): Row =
  ## Creates a row from strings.
  for value in values:
    result.cells.add initCell(value)

proc initColumn*(): Column =
  ## Creates a content-sized column with inherited layout settings.
  Column(width: contentWidth, widthPriority: 0)

proc initTableBase(columnCount: int): Table =
  if columnCount <= 0:
    raise newException(ValueError, "a table requires at least one column")
  result.theme = modernTheme
  result.padding = initCellPadding()
  result.margin = initTableMargin()
  result.overflow = overflowWrapWords
  result.truncationSuffix = "…"
  result.useColor = true
  for _ in 0 ..< columnCount:
    result.columns.add initColumn()

proc initTable*(columnCount: Positive): Table =
  ## Creates a table without a header and with ``columnCount`` columns.
  initTableBase(int(columnCount))

proc initTable*(headers: openArray[string]): Table =
  ## Creates a table whose column count is defined by ``headers``.
  if headers.len == 0:
    raise newException(ValueError, "table headers cannot be empty")
  result = initTableBase(headers.len)
  result.header = initRow(headers)
  result.hasHeader = true

proc columnCount*(table: Table): int =
  ## Returns the table's fixed number of columns.
  table.columns.len

proc validateRow(table: Table; row: Row) =
  if row.cells.len != table.columnCount:
    raise newException(ValueError, fmt"row has {row.cells.len} cells; expected {table.columnCount}")

proc addRow*(table: var Table; row: Row) =
  ## Appends ``row``, rejecting ragged input immediately.
  table.validateRow(row)
  table.rows.add row

proc addRow*(table: var Table; values: varargs[string, `$`]) =
  ## Converts values to strings and appends a validated row.
  var row: Row
  for value in values:
    row.cells.add initCell(value)
  table.addRow(row)

proc setHeader*(table: var Table; values: openArray[string]) =
  ## Adds or replaces the header after validating its width.
  let row = initRow(values)
  table.validateRow(row)
  table.header = row
  table.hasHeader = true

proc clearHeader*(table: var Table) =
  ## Removes the header without changing column definitions.
  table.header = Row()
  table.hasHeader = false

proc setFooter*(table: var Table; values: openArray[string]) =
  ## Adds or replaces a footer after validating its width.
  let row = initRow(values)
  table.validateRow(row)
  table.footer = row
  table.hasFooter = true

proc clearFooter*(table: var Table) =
  ## Removes the footer without changing column definitions.
  table.footer = Row()
  table.hasFooter = false

proc setTitle*(table: var Table; text: string) =
  ## Adds or replaces the full-width title.
  table.title = initCell(text)
  table.hasTitle = true

proc clearTitle*(table: var Table) =
  ## Removes the title.
  table.title = Cell()
  table.hasTitle = false

proc addPanel*(table: var Table; text: string;
               position = panelTop): int {.discardable.} =
  ## Adds a full-width panel and returns its index in ``table.panels``.
  table.panels.add Panel(cell: initCell(text), position: position)
  table.panels.high

proc panel*(table: var Table; index: int): var Cell =
  ## Returns a mutable full-width panel cell.
  if index < 0 or index >= table.panels.len:
    raise newException(IndexDefect, "panel index is outside the table")
  table.panels[index].cell

proc row*(table: var Table; index: int): var Row =
  ## Returns a mutable body row.
  if index < 0 or index >= table.rows.len:
    raise newException(IndexDefect, "row index is outside the table")
  table.rows[index]

proc row*(table: Table; index: int): Row =
  ## Returns an immutable copy of a body row.
  if index < 0 or index >= table.rows.len:
    raise newException(IndexDefect, "row index is outside the table")
  table.rows[index]

proc column*(table: var Table; index: int): var Column =
  ## Returns a mutable column configuration.
  if index < 0 or index >= table.columns.len:
    raise newException(IndexDefect, "column index is outside the table")
  table.columns[index]

proc column*(table: Table; index: int): Column =
  ## Returns an immutable copy of a column configuration.
  if index < 0 or index >= table.columns.len:
    raise newException(IndexDefect, "column index is outside the table")
  table.columns[index]

proc cell*(table: var Table; rowIndex, columnIndex: int): var Cell =
  ## Returns a mutable body cell.
  if rowIndex < 0 or rowIndex >= table.rows.len:
    raise newException(IndexDefect, "row index is outside the table")
  if columnIndex < 0 or columnIndex >= table.columnCount:
    raise newException(IndexDefect, "column index is outside the table")
  table.rows[rowIndex].cells[columnIndex]

proc cell*(table: Table; rowIndex, columnIndex: int): Cell =
  ## Returns an immutable copy of a body cell.
  if rowIndex < 0 or rowIndex >= table.rows.len:
    raise newException(IndexDefect, "row index is outside the table")
  if columnIndex < 0 or columnIndex >= table.columnCount:
    raise newException(IndexDefect, "column index is outside the table")
  table.rows[rowIndex].cells[columnIndex]

proc headerCell*(table: var Table; columnIndex: int): var Cell =
  ## Returns a mutable header cell.
  if not table.hasHeader:
    raise newException(ValueError, "the table does not have a header")
  if columnIndex < 0 or columnIndex >= table.columnCount:
    raise newException(IndexDefect, "column index is outside the table")
  table.header.cells[columnIndex]

proc footerCell*(table: var Table; columnIndex: int): var Cell =
  ## Returns a mutable footer cell.
  if not table.hasFooter:
    raise newException(ValueError, "the table does not have a footer")
  if columnIndex < 0 or columnIndex >= table.columnCount:
    raise newException(IndexDefect, "column index is outside the table")
  table.footer.cells[columnIndex]

proc setSpan*(cell: var Cell; columns = 1; rows = 1) =
  ## Sets this cell's rectangular span. Overlap is checked when rendering.
  if columns <= 0 or rows <= 0:
    raise newException(ValueError, "cell spans must be positive")
  cell.columnSpan = columns
  cell.rowSpan = rows

proc clearSpan*(cell: var Cell) =
  ## Restores a cell to a one-column, one-row span.
  cell.columnSpan = 1
  cell.rowSpan = 1

proc setWidthPriority*(column: var Column; priority: int) =
  ## Sets responsive shrink priority. Lower values shrink first.
  column.widthPriority = priority

template defineLayoutSetters(TypeName: typedesc) =
  proc setAlignment*(value: var TypeName; alignment: TextAlignment) =
    ## Sets an explicit horizontal alignment override.
    value.alignment = alignment
    value.hasAlignment = true

  proc setVerticalAlignment*(value: var TypeName;
                             alignment: VerticalAlignment) =
    ## Sets an explicit vertical alignment override.
    value.verticalAlignment = alignment
    value.hasVerticalAlignment = true

  proc setPadding*(value: var TypeName; padding: CellPadding) =
    ## Sets an explicit padding override.
    if min(min(padding.left, padding.right),
        min(padding.top, padding.bottom)) < 0:
      raise newException(ValueError, "cell padding cannot be negative")
    value.padding = padding
    value.hasPadding = true

defineLayoutSetters(Cell)
defineLayoutSetters(Row)
defineLayoutSetters(Column)
