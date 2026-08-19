## Value-preserving table composition and geometric transformations.

import std/sequtils

import ./tables

export tables

proc hasVerticalSpans(table: Table): bool =
  for row in table.rows:
    for cell in row.cells:
      if max(1, cell.rowSpan) > 1: return true

proc hasHorizontalSpans(table: Table): bool =
  for row in table.rows:
    for cell in row.cells:
      if max(1, cell.columnSpan) > 1: return true
  if table.hasHeader:
    for cell in table.header.cells:
      if max(1, cell.columnSpan) > 1: return true
  if table.hasFooter:
    for cell in table.footer.cells:
      if max(1, cell.columnSpan) > 1: return true

proc resetSpan(cell: var Cell) =
  cell.columnSpan = 1
  cell.rowSpan = 1

proc transformedBody(table: Table; height, width: int;
                     mapCell: proc(row, column: int): tuple[
                       row, column: int] {.closure.};
                     mapSpan: proc(row, column, rowSpan, columnSpan: int): tuple[
                       row, column, rowSpan, columnSpan: int] {.closure.}): Table =
  if table.rows.len == 0:
    raise newException(ValueError, "cannot transform an empty table body")
  result = table
  result.rows = newSeq[Row](height)
  result.columns = newSeq[Column](width)
  for index in 0 ..< width:
    result.columns[index] = initColumn()
  for rowIndex in 0 ..< height:
    result.rows[rowIndex].cells = newSeq[Cell](width)
  result.clearHeader()
  result.clearFooter()

  for rowIndex, row in table.rows:
    for columnIndex, source in row.cells:
      let target = mapCell(rowIndex, columnIndex)
      result.rows[target.row].cells[target.column] = source
      result.rows[target.row].cells[target.column].resetSpan()
  for rowIndex, row in table.rows:
    for columnIndex, source in row.cells:
      if max(1, source.rowSpan) > 1 or max(1, source.columnSpan) > 1:
        let target = mapSpan(rowIndex, columnIndex, max(1, source.rowSpan),
          max(1, source.columnSpan))
        result.rows[target.row].cells[target.column].setSpan(
          target.columnSpan, target.rowSpan)

proc transpose*(table: Table): Table =
  ## Transposes the body. Header/footer are removed because their axis changes.
  let height = table.rows.len
  let width = table.columnCount
  table.transformedBody(width, height,
    proc(row, column: int): tuple[row, column: int] = (column, row),
    proc(row, column, rowSpan, columnSpan: int): tuple[
        row, column, rowSpan, columnSpan: int] =
      (column, row, columnSpan, rowSpan))

proc rotateClockwise*(table: Table): Table =
  ## Rotates the body 90 degrees clockwise.
  let height = table.rows.len
  let width = table.columnCount
  table.transformedBody(width, height,
    proc(row, column: int): tuple[row, column: int] =
      (column, height - 1 - row),
    proc(row, column, rowSpan, columnSpan: int): tuple[
        row, column, rowSpan, columnSpan: int] =
      (column, height - row - rowSpan, columnSpan, rowSpan))

proc rotateCounterClockwise*(table: Table): Table =
  ## Rotates the body 90 degrees counter-clockwise.
  let height = table.rows.len
  let width = table.columnCount
  table.transformedBody(width, height,
    proc(row, column: int): tuple[row, column: int] =
      (width - 1 - column, row),
    proc(row, column, rowSpan, columnSpan: int): tuple[
        row, column, rowSpan, columnSpan: int] =
      (width - column - columnSpan, row, columnSpan, rowSpan))

proc rotate180*(table: Table): Table =
  ## Rotates the body by 180 degrees.
  let height = table.rows.len
  let width = table.columnCount
  table.transformedBody(height, width,
    proc(row, column: int): tuple[row, column: int] =
      (height - 1 - row, width - 1 - column),
    proc(row, column, rowSpan, columnSpan: int): tuple[
        row, column, rowSpan, columnSpan: int] =
      (height - row - rowSpan, width - column - columnSpan,
        rowSpan, columnSpan))

proc horizontalConcat*(left, right: Table): Table =
  ## Joins tables side by side. Their body heights and section presence match.
  if left.rows.len != right.rows.len:
    raise newException(ValueError, "horizontal concatenation needs equal row counts")
  if left.hasHeader != right.hasHeader or left.hasFooter != right.hasFooter:
    raise newException(ValueError, "horizontal concatenation needs matching sections")
  result = left
  result.columns.add right.columns
  for rowIndex in 0 ..< result.rows.len:
    result.rows[rowIndex].cells.add right.rows[rowIndex].cells
  if result.hasHeader: result.header.cells.add right.header.cells
  if result.hasFooter: result.footer.cells.add right.footer.cells

proc verticalConcat*(top, bottom: Table): Table =
  ## Stacks tables with equal column counts. The top presentation is retained.
  if top.columnCount != bottom.columnCount:
    raise newException(ValueError, "vertical concatenation needs equal column counts")
  result = top
  result.rows.add bottom.rows
  if not result.hasHeader and bottom.hasHeader:
    result.header = bottom.header
    result.hasHeader = true
  if bottom.hasFooter:
    result.footer = bottom.footer
    result.hasFooter = true

proc merge*(base, overlay: Table): Table =
  ## Fills empty body cells in ``base`` from an equally shaped ``overlay``.
  if base.columnCount != overlay.columnCount or
      base.rows.len != overlay.rows.len:
    raise newException(ValueError, "merged tables must have equal body shapes")
  result = base
  for rowIndex in 0 ..< result.rows.len:
    for columnIndex in 0 ..< result.columnCount:
      if result.rows[rowIndex].cells[columnIndex].text.len == 0:
        result.rows[rowIndex].cells[columnIndex] =
          overlay.rows[rowIndex].cells[columnIndex]

proc validateIndexes(indexes: openArray[int]; length: int; kind: string) =
  for index in indexes:
    if index < 0 or index >= length:
      raise newException(IndexDefect, kind & " index is outside the table")

proc extractRows*(table: Table; indexes: openArray[int]): Table =
  ## Returns the requested body rows in the supplied order.
  if table.hasVerticalSpans:
    raise newException(ValueError, "row extraction cannot cut vertical spans")
  validateIndexes(indexes, table.rows.len, "row")
  result = table
  result.rows = @[]
  for index in indexes: result.rows.add table.rows[index]

proc removeRows*(table: Table; indexes: openArray[int]): Table =
  ## Returns a copy without the specified body rows.
  validateIndexes(indexes, table.rows.len, "row")
  var keep: seq[int]
  for index in 0 ..< table.rows.len:
    if index notin indexes: keep.add index
  table.extractRows(keep)

proc duplicateRow*(table: Table; index: int; copies = 1): Table =
  ## Inserts ``copies`` additional instances immediately after one body row.
  if copies < 0: raise newException(ValueError, "copy count cannot be negative")
  if table.hasVerticalSpans:
    raise newException(ValueError, "row duplication cannot cross vertical spans")
  validateIndexes([index], table.rows.len, "row")
  result = table
  for _ in 0 ..< copies: result.rows.insert(table.rows[index], index + 1)

proc splitRows*(table: Table; at: range[0 .. high(int)]): tuple[
    before, after: Table] =
  ## Splits the body before index ``at``.
  if at > table.rows.len:
    raise newException(IndexDefect, "row split is outside the table")
  result.before = table.extractRows(toSeq(0 ..< int(at)))
  result.after = table.extractRows(toSeq(int(at) ..< table.rows.len))

proc extractColumns*(table: Table; indexes: openArray[int]): Table =
  ## Returns the requested columns in the supplied order.
  if table.hasHorizontalSpans:
    raise newException(ValueError, "column extraction cannot cut horizontal spans")
  validateIndexes(indexes, table.columnCount, "column")
  if indexes.len == 0:
    raise newException(ValueError, "a table requires at least one column")
  let selected = @indexes
  result = table
  result.columns = @[]
  for index in selected: result.columns.add table.columns[index]
  proc pick(row: Row): Row =
    result = row
    result.cells = @[]
    for index in selected: result.cells.add row.cells[index]
  for rowIndex in 0 ..< result.rows.len:
    result.rows[rowIndex] = pick(table.rows[rowIndex])
  if result.hasHeader: result.header = pick(table.header)
  if result.hasFooter: result.footer = pick(table.footer)

proc removeColumns*(table: Table; indexes: openArray[int]): Table =
  ## Returns a copy without the specified columns.
  validateIndexes(indexes, table.columnCount, "column")
  var keep: seq[int]
  for index in 0 ..< table.columnCount:
    if index notin indexes: keep.add index
  table.extractColumns(keep)

proc duplicateColumn*(table: Table; index: int; copies = 1): Table =
  ## Inserts copies of one column and its cells immediately to its right.
  if copies < 0: raise newException(ValueError, "copy count cannot be negative")
  if table.hasHorizontalSpans:
    raise newException(ValueError, "column duplication cannot cross horizontal spans")
  validateIndexes([index], table.columnCount, "column")
  result = table
  for _ in 0 ..< copies:
    result.columns.insert(table.columns[index], index + 1)
    for rowIndex in 0 ..< result.rows.len:
      result.rows[rowIndex].cells.insert(table.rows[rowIndex].cells[index], index + 1)
    if result.hasHeader:
      result.header.cells.insert(table.header.cells[index], index + 1)
    if result.hasFooter:
      result.footer.cells.insert(table.footer.cells[index], index + 1)

proc splitColumns*(table: Table; at: range[0 .. high(int)]): tuple[
    before, after: Table] =
  ## Splits the table before column index ``at``.
  if at <= 0 or at >= table.columnCount:
    raise newException(IndexDefect, "column split must leave two nonempty tables")
  result.before = table.extractColumns(toSeq(0 ..< int(at)))
  result.after = table.extractColumns(toSeq(int(at) ..< table.columnCount))
