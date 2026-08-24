## Composable selectors for addressing table cells independently of rendering.

import ./tables

export tables

type
  TableSection* = enum
    ## A selectable fixed-grid section.
    sectionHeader,
    sectionBody,
    sectionFooter

  CellContext* = object
    ## Read-only information supplied to predicate selectors.
    section*: TableSection
    rowIndex*: int
    columnIndex*: int
    cell*: Cell

  CellAddress* = object
    ## Stable model address returned by ``matchingCells``.
    section*: TableSection
    rowIndex*: int
    columnIndex*: int

  CellPredicate* = proc(context: CellContext): bool {.closure.}

  Selector* = object
    ## A reusable predicate over header, body, and footer cells.
    predicate: CellPredicate

  CellModifier* = proc(cell: var Cell) {.closure.}

proc predicateSelector*(predicate: CellPredicate): Selector =
  ## Selects every cell for which ``predicate`` returns true.
  if predicate.isNil:
    raise newException(ValueError, "selector predicate cannot be nil")
  Selector(predicate: predicate)

proc allCellsSelector*(): Selector =
  ## Selects header, body, and footer cells.
  predicateSelector(proc(_: CellContext): bool = true)

proc rowSelector*(rowIndex: Natural): Selector =
  ## Selects one zero-based body row.
  predicateSelector(proc(context: CellContext): bool =
    context.section == sectionBody and context.rowIndex == int(rowIndex))

proc columnSelector*(columnIndex: Natural): Selector =
  ## Selects one column in the header, body, and footer.
  predicateSelector(proc(context: CellContext): bool =
    context.columnIndex == int(columnIndex))

proc cellSelector*(rowIndex, columnIndex: Natural): Selector =
  ## Selects one body cell.
  predicateSelector(proc(context: CellContext): bool =
    context.section == sectionBody and context.rowIndex == int(rowIndex) and
      context.columnIndex == int(columnIndex))

proc segmentSelector*(firstRow, firstColumn, lastRow,
                      lastColumn: Natural): Selector =
  ## Selects an inclusive rectangular body segment.
  if lastRow < firstRow or lastColumn < firstColumn:
    raise newException(ValueError, "selector segment bounds are reversed")
  predicateSelector(proc(context: CellContext): bool =
    context.section == sectionBody and
      context.rowIndex >= int(firstRow) and context.rowIndex <= int(lastRow) and
      context.columnIndex >= int(firstColumn) and
      context.columnIndex <= int(lastColumn))

proc headerSelector*(): Selector =
  ## Selects every header cell.
  predicateSelector(proc(context: CellContext): bool =
    context.section == sectionHeader)

proc footerSelector*(): Selector =
  ## Selects every footer cell.
  predicateSelector(proc(context: CellContext): bool =
    context.section == sectionFooter)

proc `or`*(left, right: Selector): Selector =
  ## Combines selectors as a set union.
  predicateSelector(proc(context: CellContext): bool =
    left.predicate(context) or right.predicate(context))

iterator contexts(table: Table): CellContext =
  if table.hasHeader:
    for columnIndex, cell in table.header.cells:
      yield CellContext(section: sectionHeader, rowIndex: -1,
        columnIndex: columnIndex, cell: cell)
  for rowIndex, row in table.rows:
    for columnIndex, cell in row.cells:
      yield CellContext(section: sectionBody, rowIndex: rowIndex,
        columnIndex: columnIndex, cell: cell)
  if table.hasFooter:
    for columnIndex, cell in table.footer.cells:
      yield CellContext(section: sectionFooter, rowIndex: -1,
        columnIndex: columnIndex, cell: cell)

proc matchingCells*(table: Table; selector: Selector): seq[CellAddress] =
  ## Returns matching model addresses in header/body/footer order.
  if selector.predicate.isNil:
    raise newException(ValueError, "selector is uninitialized")
  for context in table.contexts:
    if selector.predicate(context):
      result.add CellAddress(section: context.section,
        rowIndex: context.rowIndex, columnIndex: context.columnIndex)

proc apply*(table: var Table; selector: Selector; modifier: CellModifier) =
  ## Applies ``modifier`` once to every selected cell.
  if modifier.isNil:
    raise newException(ValueError, "cell modifier cannot be nil")
  let addresses = table.matchingCells(selector)
  for address in addresses:
    case address.section
    of sectionHeader:
      modifier(table.header.cells[address.columnIndex])
    of sectionBody:
      modifier(table.rows[address.rowIndex].cells[address.columnIndex])
    of sectionFooter:
      modifier(table.footer.cells[address.columnIndex])
