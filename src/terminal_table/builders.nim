## Incremental construction for data whose shape is known at runtime.

import ./tables

export tables

type
  TableBuilder* = object
    ## Accumulates rows before validating and producing a ``Table``.
    headers*: seq[string]
    rows*: seq[seq[string]]
    currentRow*: seq[string]

proc initTableBuilder*(headers: openArray[string] = []): TableBuilder =
  ## Starts a dynamic table builder, optionally with a header.
  result.headers = @headers

proc addCell*(builder: var TableBuilder; value: string) =
  ## Appends one cell to the row currently being assembled.
  builder.currentRow.add value

proc finishRow*(builder: var TableBuilder) =
  ## Finishes the current row. Empty rows are rejected.
  if builder.currentRow.len == 0:
    raise newException(ValueError, "cannot finish an empty row")
  builder.rows.add builder.currentRow
  builder.currentRow = @[]

proc addRow*(builder: var TableBuilder; values: varargs[string, `$`]) =
  ## Appends one complete dynamic row.
  if builder.currentRow.len > 0:
    raise newException(ValueError, "finish the current row before adding another")
  var row: seq[string]
  for value in values:
    row.add value
  if row.len == 0:
    raise newException(ValueError, "table rows cannot be empty")
  builder.rows.add row

proc build*(builder: TableBuilder): Table =
  ## Validates the accumulated shape and returns an independent table.
  if builder.currentRow.len > 0:
    raise newException(ValueError, "finish the current row before building")
  let columnCount = if builder.headers.len > 0: builder.headers.len
    elif builder.rows.len > 0: builder.rows[0].len
    else: 0
  if columnCount == 0:
    raise newException(ValueError, "cannot build an empty table")
  if builder.headers.len > 0:
    result = initTable(builder.headers)
  else:
    result = initTable(Positive(columnCount))
  for values in builder.rows:
    if values.len != columnCount:
      raise newException(ValueError, "all builder rows must have the same number of cells")
    result.addRow(initRow(values))

proc fromRows*(rows: openArray[seq[string]]): Table =
  ## Builds a headerless table from runtime row data.
  var builder = initTableBuilder()
  for row in rows:
    builder.rows.add row
  builder.build()
