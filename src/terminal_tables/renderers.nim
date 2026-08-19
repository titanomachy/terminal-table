## Deterministic ANSI-aware terminal table rendering.
##
## ``render`` only returns a string. ``renderToTerminalWidth`` is the sole API
## that queries terminal dimensions, and ``print`` is only a convenience.

import std/[sequtils, strutils, terminal]

import ./tables

export tables

type
  ResolvedCell = object
    alignment: TextAlignment
    verticalAlignment: VerticalAlignment
    padding: CellPadding
    textStyle: TerminalStyle

  CellOwner = object
    row, column: int

  AnchorRender = object
    setting: ResolvedCell
    lines: seq[string]
    columnSpan, rowSpan: int
    contentWidth, requiredHeight: int

proc mergeStyle(base, overlay: TerminalStyle): TerminalStyle =
  result = base
  if overlay.foreground.kind != tckDefault:
    result.foreground = overlay.foreground
  if overlay.background.kind != tckDefault:
    result.background = overlay.background
  result.attributes = result.attributes + overlay.attributes

proc nonzero(padding: CellPadding): bool =
  padding.left != 0 or padding.right != 0 or padding.top != 0 or
    padding.bottom != 0

proc resolveCell(table: Table; row: Row; column: Column;
                 cell: Cell): ResolvedCell =
  result.alignment = table.alignment
  result.verticalAlignment = table.verticalAlignment
  result.padding = table.padding
  result.textStyle = table.style

  # Non-default direct field assignments remain ergonomic. Setters are needed
  # only to explicitly override an inherited value with the enum's zero value.
  if column.hasAlignment or column.alignment != alignLeft:
    result.alignment = column.alignment
  if column.hasVerticalAlignment or column.verticalAlignment != valignTop:
    result.verticalAlignment = column.verticalAlignment
  if column.hasPadding or column.padding.nonzero:
    result.padding = column.padding
  result.textStyle = mergeStyle(result.textStyle, column.style)

  if row.hasAlignment or row.alignment != alignLeft:
    result.alignment = row.alignment
  if row.hasVerticalAlignment or row.verticalAlignment != valignTop:
    result.verticalAlignment = row.verticalAlignment
  if row.hasPadding or row.padding.nonzero:
    result.padding = row.padding
  result.textStyle = mergeStyle(result.textStyle, row.style)

  if cell.hasAlignment or cell.alignment != alignLeft:
    result.alignment = cell.alignment
  if cell.hasVerticalAlignment or cell.verticalAlignment != valignTop:
    result.verticalAlignment = cell.verticalAlignment
  if cell.hasPadding or cell.padding.nonzero:
    result.padding = cell.padding
  result.textStyle = mergeStyle(result.textStyle, cell.style)

proc allRows(table: Table): seq[Row] =
  if table.hasHeader:
    result.add table.header
  result.add table.rows
  if table.hasFooter:
    result.add table.footer

proc effectiveColumnSpan(cell: Cell): int = max(1, cell.columnSpan)
proc effectiveRowSpan(cell: Cell): int = max(1, cell.rowSpan)

proc spanOwners(rows: openArray[Row]; columnCount: int): seq[seq[CellOwner]] =
  result = newSeq[seq[CellOwner]](rows.len)
  for rowIndex in 0 ..< rows.len:
    result[rowIndex] = newSeq[CellOwner](columnCount)
    for columnIndex in 0 ..< columnCount:
      result[rowIndex][columnIndex] = CellOwner(row: -1, column: -1)
  for rowIndex, row in rows:
    for columnIndex, cell in row.cells:
      if result[rowIndex][columnIndex].row >= 0:
        if cell.effectiveColumnSpan > 1 or cell.effectiveRowSpan > 1:
          raise newException(ValueError, "cell spans cannot overlap")
        continue
      let columnSpan = cell.effectiveColumnSpan
      let rowSpan = cell.effectiveRowSpan
      if columnIndex + columnSpan > columnCount or rowIndex + rowSpan > rows.len:
        raise newException(ValueError, "cell span leaves its table section")
      for coveredRow in rowIndex ..< rowIndex + rowSpan:
        for coveredColumn in columnIndex ..< columnIndex + columnSpan:
          if result[coveredRow][coveredColumn].row >= 0:
            raise newException(ValueError, "cell spans cannot overlap")
          result[coveredRow][coveredColumn] = CellOwner(
            row: rowIndex, column: columnIndex)

proc validate(table: Table; maxWidth: int) =
  if table.columnCount <= 0:
    raise newException(ValueError, "a table requires at least one column")
  if maxWidth < 0:
    raise newException(ValueError, "maximum table width cannot be negative")
  if min(min(table.padding.left, table.padding.right),
      min(table.padding.top, table.padding.bottom)) < 0:
    raise newException(ValueError, "cell padding cannot be negative")
  if min(min(table.margin.left, table.margin.right),
      min(table.margin.top, table.margin.bottom)) < 0:
    raise newException(ValueError, "table margins cannot be negative")
  if '\n' in table.truncationSuffix or '\r' in table.truncationSuffix:
    raise newException(ValueError,
      "the truncation suffix cannot contain newlines")
  for row in table.allRows:
    if row.cells.len != table.columnCount:
      raise newException(ValueError, "the table contains ragged rows")
    for index, cell in row.cells:
      let padding = resolveCell(table, row, table.columns[index], cell).padding
      if min(min(padding.left, padding.right),
          min(padding.top, padding.bottom)) < 0:
        raise newException(ValueError, "cell padding cannot be negative")
  if table.hasHeader:
    discard spanOwners([table.header], table.columnCount)
  discard spanOwners(table.rows, table.columnCount)
  if table.hasFooter:
    discard spanOwners([table.footer], table.columnCount)
  proc validateFullWidthCell(cell: Cell; name: string) =
    let resolved = resolveCell(table, Row(), Column(), cell)
    if min(min(resolved.padding.left, resolved.padding.right),
        min(resolved.padding.top, resolved.padding.bottom)) < 0:
      raise newException(ValueError, name & " padding cannot be negative")
  for panel in table.panels:
    if panel.cell.effectiveColumnSpan != 1 or panel.cell.effectiveRowSpan != 1:
      raise newException(ValueError, "full-width panels cannot define spans")
    validateFullWidthCell(panel.cell, "panel")
  if table.hasTitle and
      (table.title.effectiveColumnSpan != 1 or table.title.effectiveRowSpan != 1):
    raise newException(ValueError, "the full-width title cannot define a span")
  if table.hasTitle:
    validateFullWidthCell(table.title, "title")
  if table.shadow.right < 0 or table.shadow.bottom < 0:
    raise newException(ValueError, "shadow dimensions cannot be negative")
  if (table.shadow.right > 0 or table.shadow.bottom > 0) and
      displayWidth(table.shadow.glyph) != 1:
    raise newException(ValueError, "shadow glyph must occupy one terminal cell")
  for column in table.columns:
    if column.width.kind != widthContent and column.width.value <= 0:
      raise newException(ValueError, "column width values must be positive")
    if column.width.kind == widthPercentage and column.width.value > 100:
      raise newException(ValueError, "column percentages cannot exceed 100")
    let padding = resolveCell(table, Row(), column, Cell()).padding
    if min(min(padding.left, padding.right),
        min(padding.top, padding.bottom)) < 0:
      raise newException(ValueError, "column padding cannot be negative")

  let theme = table.theme
  proc requireGlyph(value, name: string; active: bool) =
    if active and displayWidth(value) != 1:
      raise newException(ValueError,
        name & " must occupy exactly one terminal cell")
    if '\n' in value or '\r' in value:
      raise newException(ValueError, name & " cannot contain line breaks")
  requireGlyph(theme.borders.horizontal, "horizontal border",
    theme.showTop or theme.showBottom or theme.showHeaderSeparator or
      theme.showRowSeparators)
  requireGlyph(theme.borders.vertical, "vertical border",
    theme.showOuterVertical or theme.showColumnSeparators)
  if theme.showTop:
    requireGlyph(theme.borders.topLeft, "top-left border",
      theme.showOuterVertical)
    requireGlyph(theme.borders.topRight, "top-right border",
      theme.showOuterVertical)
    requireGlyph(theme.borders.topJoin, "top border join",
      theme.showColumnSeparators)
  if theme.showBottom:
    requireGlyph(theme.borders.bottomLeft, "bottom-left border",
      theme.showOuterVertical)
    requireGlyph(theme.borders.bottomRight, "bottom-right border",
      theme.showOuterVertical)
    requireGlyph(theme.borders.bottomJoin, "bottom border join",
      theme.showColumnSeparators)
  if theme.showHeaderSeparator or theme.showRowSeparators:
    requireGlyph(theme.borders.middleLeft, "left rule border",
      theme.showOuterVertical)
    requireGlyph(theme.borders.middleRight, "right rule border",
      theme.showOuterVertical)
    requireGlyph(theme.borders.middleJoin, "rule border join",
      theme.showColumnSeparators)

proc borderOverhead(table: Table): int =
  if table.theme.showOuterVertical:
    result += 2
  if table.theme.showColumnSeparators:
    result += max(0, table.columnCount - 1)

proc naturalWidths(table: Table): tuple[content, padding: seq[int]] =
  var content = newSeq[int](table.columnCount)
  var paddingWidths = newSeq[int](table.columnCount)
  for index in 0 ..< table.columnCount:
    content[index] = 1
    let columnPadding = resolveCell(table, Row(), table.columns[index], Cell()).padding
    paddingWidths[index] = columnPadding.left + columnPadding.right
  proc includeRows(rows: openArray[Row]) =
    let owners = spanOwners(rows, table.columnCount)
    for rowIndex, row in rows:
      for index, cell in row.cells:
        let owner = owners[rowIndex][index]
        if owner.row != rowIndex or owner.column != index:
          continue
        let resolved = resolveCell(table, row, table.columns[index], cell)
        let span = cell.effectiveColumnSpan
        paddingWidths[index] = max(paddingWidths[index],
          resolved.padding.left + resolved.padding.right)
        if span == 1:
          content[index] = max(content[index], displayWidth(cell.text))
        else:
          let needed = displayWidth(cell.text) + resolved.padding.left +
            resolved.padding.right
          var available = 0
          for columnIndex in index ..< index + span:
            available += content[columnIndex] + paddingWidths[columnIndex]
          if table.theme.showColumnSeparators:
            available += span - 1
          var deficit = needed - available
          var target = index
          while deficit > 0:
            inc content[target]
            dec deficit
            target = if target + 1 < index + span: target + 1 else: index
  if table.hasHeader: includeRows([table.header])
  includeRows(table.rows)
  if table.hasFooter: includeRows([table.footer])
  result = (content, paddingWidths)

proc resolveWidths(table: Table; maxWidth: int): tuple[
    content, padding: seq[int]] =
  result = table.naturalWidths()
  let fixedOverhead = table.margin.left + table.margin.right +
    table.shadow.right +
    table.borderOverhead + result.padding.foldl(a + b, 0)
  let percentageBase = if maxWidth > 0:
      max(1, maxWidth - fixedOverhead)
    else:
      max(1, result.content.foldl(a + b, 0))

  var minimums = newSeqWith(table.columnCount, 1)
  for index, column in table.columns:
    case column.width.kind
    of widthContent:
      discard
    of widthFixed:
      result.content[index] = column.width.value
      minimums[index] = column.width.value
    of widthMinimum:
      result.content[index] = max(result.content[index], column.width.value)
      minimums[index] = column.width.value
    of widthMaximum:
      result.content[index] = min(result.content[index], column.width.value)
    of widthPercentage:
      result.content[index] = max(1,
        percentageBase * column.width.value div 100)

  if maxWidth > 0:
    var excess = fixedOverhead + result.content.foldl(a + b, 0) - maxWidth
    while excess > 0:
      var active: seq[int]
      var lowestPriority = high(int)
      for index, width in result.content:
        if width > minimums[index]:
          lowestPriority = min(lowestPriority, table.columns[index].widthPriority)
      for index, width in result.content:
        if width > minimums[index] and
            table.columns[index].widthPriority == lowestPriority:
          active.add index
      if active.len == 0:
        raise newException(ValueError,
          "the fixed widths, padding, borders, and margins cannot fit " &
            "maxWidth")
      let share = max(1, excess div active.len)
      for index in active:
        let reduction = min(share,
          min(excess, result.content[index] - minimums[index]))
        result.content[index] -= reduction
        excess -= reduction
        if excess == 0:
          break

proc cellLines(text: string; width: int; overflow: OverflowMode;
               suffix: string): seq[string] =
  case overflow
  of overflowWrapWords:
    result = wrapAnsi(text, width, wrapWords)
  of overflowWrapCharacters:
    result = wrapAnsi(text, width, wrapCharacters)
  of overflowTruncate:
    for line in text.splitLines:
      result.add truncateAnsi(line, width, suffix)
    if result.len == 0:
      result.add ""
  # A two-cell grapheme cannot be split into a one-cell allocation. Preserve
  # the table width contract by replacing only such an unrepresentable line
  # with the configured truncation result.
  for line in result.mitems:
    if displayWidth(line) > width:
      line = truncateAnsi(line, width, suffix)

proc styleText(value: string; textStyle: TerminalStyle;
               enabled: bool): string =
  if enabled:
    applyStyle(value, textStyle)
  else:
    stripAnsi(value)

proc borderText(table: Table; value: string): string =
  styleText(value, table.borderStyle, table.useColor)

proc rule(table: Table; widths, padding: seq[int]; position: char): string =
  let borders = table.theme.borders
  var left, joiner, right: string
  case position
  of 't':
    (left, joiner, right) = (borders.topLeft, borders.topJoin, borders.topRight)
  of 'b':
    (left, joiner, right) = (borders.bottomLeft, borders.bottomJoin,
      borders.bottomRight)
  else:
    (left, joiner, right) = (borders.middleLeft, borders.middleJoin,
      borders.middleRight)
  if table.theme.showOuterVertical:
    result.add left
  for index in 0 ..< table.columnCount:
    result.add repeat(borders.horizontal, widths[index] + padding[index])
    if index + 1 < table.columnCount and table.theme.showColumnSeparators:
      result.add joiner
  if table.theme.showOuterVertical:
    result.add right
  result = table.borderText(result)

proc spanWidth(table: Table; widths, padding: seq[int]; first, count: int): int =
  for index in first ..< first + count:
    result += widths[index] + padding[index]
  if table.theme.showColumnSeparators:
    result += count - 1

proc partialRule(table: Table; widths, padding: seq[int];
                 owners: seq[seq[CellOwner]]; afterRow: int): string =
  ## Draws a middle rule while leaving the inside of vertical spans open.
  proc crosses(columnIndex: int): bool =
    let owner = owners[afterRow][columnIndex]
    owner.row >= 0 and owner.row <= afterRow and
      owner.row + table.rows[owner.row].cells[owner.column].effectiveRowSpan >
        afterRow + 1
  if table.theme.showOuterVertical:
    result.add(if crosses(0): table.theme.borders.vertical
      else: table.theme.borders.middleLeft)
  for columnIndex in 0 ..< table.columnCount:
    let width = widths[columnIndex] + padding[columnIndex]
    result.add repeat(if crosses(columnIndex): " "
      else: table.theme.borders.horizontal,
      width)
    if columnIndex + 1 < table.columnCount and
        table.theme.showColumnSeparators:
      let leftOwner = owners[afterRow][columnIndex]
      let rightOwner = owners[afterRow][columnIndex + 1]
      if crosses(columnIndex) and crosses(columnIndex + 1) and
          leftOwner.row == rightOwner.row and
          leftOwner.column == rightOwner.column:
        result.add " "
      elif crosses(columnIndex) and crosses(columnIndex + 1):
        result.add table.theme.borders.vertical
      else:
        result.add table.theme.borders.middleJoin
  if table.theme.showOuterVertical:
    result.add(if crosses(table.columnCount - 1): table.theme.borders.vertical
      else: table.theme.borders.middleRight)
  result = table.borderText(result)

proc renderedSection(table: Table; rows: openArray[Row];
                     widths, padding: seq[int]; rowRules: bool): seq[string] =
  if rows.len == 0:
    return
  let owners = spanOwners(rows, table.columnCount)
  var anchors = newSeq[seq[AnchorRender]](rows.len)
  for rowIndex in 0 ..< rows.len:
    anchors[rowIndex] = newSeq[AnchorRender](table.columnCount)
  var rowHeights = newSeqWith(rows.len, 1)

  for rowIndex, row in rows:
    for columnIndex, cell in row.cells:
      let owner = owners[rowIndex][columnIndex]
      if owner.row != rowIndex or owner.column != columnIndex:
        continue
      var anchor: AnchorRender
      anchor.setting = resolveCell(table, row, table.columns[columnIndex], cell)
      anchor.columnSpan = cell.effectiveColumnSpan
      anchor.rowSpan = cell.effectiveRowSpan
      let totalWidth = table.spanWidth(widths, padding, columnIndex,
        anchor.columnSpan)
      anchor.contentWidth = max(1, totalWidth - anchor.setting.padding.left -
        anchor.setting.padding.right)
      anchor.lines = cellLines(cell.text, anchor.contentWidth, table.overflow,
        table.truncationSuffix)
      anchor.requiredHeight = anchor.setting.padding.top + anchor.lines.len +
        anchor.setting.padding.bottom
      anchors[rowIndex][columnIndex] = anchor
      if anchor.rowSpan == 1:
        rowHeights[rowIndex] = max(rowHeights[rowIndex], anchor.requiredHeight)

  # A vertical span expands its final covered row if its combined allocation
  # is too short. This leaves earlier rows stable and makes fitting repeatable.
  for rowIndex, row in rows:
    for columnIndex, cell in row.cells:
      let owner = owners[rowIndex][columnIndex]
      if owner.row != rowIndex or owner.column != columnIndex:
        continue
      let anchor = anchors[rowIndex][columnIndex]
      if anchor.rowSpan > 1:
        var available = 0
        for coveredRow in rowIndex ..< rowIndex + anchor.rowSpan:
          available += rowHeights[coveredRow]
        if available < anchor.requiredHeight:
          rowHeights[rowIndex + anchor.rowSpan - 1] +=
            anchor.requiredHeight - available

  var offsets = newSeq[int](rows.len + 1)
  for rowIndex in 0 ..< rows.len:
    offsets[rowIndex + 1] = offsets[rowIndex] + rowHeights[rowIndex]

  for rowIndex in 0 ..< rows.len:
    for lineIndex in 0 ..< rowHeights[rowIndex]:
      var line: string
      if table.theme.showOuterVertical:
        line.add table.borderText(table.theme.borders.vertical)
      var columnIndex = 0
      while columnIndex < table.columnCount:
        let owner = owners[rowIndex][columnIndex]
        if owner.column != columnIndex:
          inc columnIndex
          continue
        let anchor = anchors[owner.row][owner.column]
        let totalHeight = offsets[owner.row + anchor.rowSpan] - offsets[owner.row]
        let extra = totalHeight - anchor.requiredHeight
        let before = case anchor.setting.verticalAlignment
          of valignTop: 0
          of valignCenter: extra div 2
          of valignBottom: extra
        let position = offsets[rowIndex] - offsets[owner.row] + lineIndex
        let contentIndex = position - before - anchor.setting.padding.top
        var content = ""
        if contentIndex >= 0 and contentIndex < anchor.lines.len:
          content = anchor.lines[contentIndex]
        let totalWidth = table.spanWidth(widths, padding, owner.column,
          anchor.columnSpan)
        let padded = repeat(' ', anchor.setting.padding.left) &
          padAnsi(content, anchor.contentWidth, anchor.setting.alignment) &
          repeat(' ', totalWidth - anchor.setting.padding.left -
            anchor.contentWidth)
        line.add styleText(padded, anchor.setting.textStyle, table.useColor)
        columnIndex += anchor.columnSpan
        if columnIndex < table.columnCount and
            table.theme.showColumnSeparators:
          line.add table.borderText(table.theme.borders.vertical)
      if table.theme.showOuterVertical:
        line.add table.borderText(table.theme.borders.vertical)
      result.add line
    if rowRules and rowIndex + 1 < rows.len:
      result.add table.partialRule(widths, padding, owners, rowIndex)

proc renderedPanel(table: Table; cell: Cell; innerWidth: int): seq[string] =
  let setting = resolveCell(table, Row(), Column(), cell)
  let contentWidth = innerWidth - setting.padding.left - setting.padding.right
  if contentWidth <= 0:
    raise newException(ValueError,
      "full-width cell padding cannot fit the table width")
  let wrappedLines = cellLines(cell.text, contentWidth, table.overflow,
    table.truncationSuffix)
  var contents: seq[string]
  for _ in 0 ..< setting.padding.top: contents.add ""
  contents.add wrappedLines
  for _ in 0 ..< setting.padding.bottom: contents.add ""
  for content in contents:
    var line: string
    if table.theme.showOuterVertical:
      line.add table.borderText(table.theme.borders.vertical)
    let padded = repeat(' ', setting.padding.left) &
      padAnsi(content, contentWidth, setting.alignment) &
      repeat(' ', innerWidth - setting.padding.left - contentWidth)
    line.add styleText(padded, setting.textStyle, table.useColor)
    if table.theme.showOuterVertical:
      line.add table.borderText(table.theme.borders.vertical)
    result.add line

proc render*(table: Table; maxWidth = 0): string =
  ## Renders a table to a string. ``maxWidth = 0`` uses natural widths;
  ## otherwise the complete table, including margins, is fitted to that width.
  table.validate(maxWidth)
  let resolved = table.resolveWidths(maxWidth)
  var lines: seq[string]
  if table.theme.showTop:
    lines.add table.rule(resolved.content, resolved.padding, 't')

  let innerWidth = resolved.content.foldl(a + b, 0) +
    resolved.padding.foldl(a + b, 0) +
    (if table.theme.showColumnSeparators: table.columnCount - 1 else: 0)
  var hasContent = false
  template separate() =
    if hasContent and table.theme.showRowSeparators:
      lines.add table.rule(resolved.content, resolved.padding, 'm')

  if table.hasTitle:
    lines.add table.renderedPanel(table.title, innerWidth)
    hasContent = true
  for panel in table.panels:
    if panel.position == panelTop:
      separate()
      lines.add table.renderedPanel(panel.cell, innerWidth)
      hasContent = true
  if table.hasHeader:
    separate()
    lines.add table.renderedSection([table.header], resolved.content,
      resolved.padding, false)
    hasContent = true
    if table.theme.showHeaderSeparator:
      lines.add table.rule(resolved.content, resolved.padding, 'm')
  if table.rows.len > 0:
    if hasContent and not table.hasHeader:
      separate()
    lines.add table.renderedSection(table.rows, resolved.content,
      resolved.padding, table.theme.showRowSeparators)
    hasContent = true
  for panel in table.panels:
    if panel.position == panelBottom:
      separate()
      lines.add table.renderedPanel(panel.cell, innerWidth)
      hasContent = true
  if table.hasFooter:
    let headerRuleImmediatelyBefore = table.hasHeader and
      table.rows.len == 0 and
      not table.panels.anyIt(it.position == panelBottom)
    if hasContent and table.theme.showHeaderSeparator and
        not headerRuleImmediatelyBefore:
      lines.add table.rule(resolved.content, resolved.padding, 'm')
    lines.add table.renderedSection([table.footer], resolved.content,
      resolved.padding, false)
    hasContent = true
  if table.theme.showBottom:
    lines.add table.rule(resolved.content, resolved.padding, 'b')

  let rawWidth = table.borderOverhead + resolved.content.foldl(a + b, 0) +
    resolved.padding.foldl(a + b, 0)
  var withMargins: seq[string]
  let styledShadow = styleText(repeat(table.shadow.glyph, table.shadow.right),
    table.shadow.style, table.useColor)
  let blank = repeat(' ', table.margin.left + rawWidth + table.shadow.right +
    table.margin.right)
  for _ in 0 ..< table.margin.top:
    withMargins.add blank
  for line in lines:
    withMargins.add repeat(' ', table.margin.left) & line &
      styledShadow & repeat(' ', table.margin.right)
  let bottomShadow = styleText(repeat(table.shadow.glyph,
    rawWidth + table.shadow.right), table.shadow.style, table.useColor)
  for _ in 0 ..< table.shadow.bottom:
    withMargins.add repeat(' ', table.margin.left) & bottomShadow &
      repeat(' ', table.margin.right)
  for _ in 0 ..< table.margin.bottom:
    withMargins.add blank
  result = withMargins.join("\n")

proc renderToTerminalWidth*(table: Table; fallbackWidth = 80): string =
  ## Queries the current terminal width at call time and responsively renders.
  ## ``fallbackWidth`` is used when the terminal cannot report a positive size.
  if fallbackWidth <= 0:
    raise newException(ValueError, "fallback terminal width must be positive")
  let detected = terminalWidth()
  table.render(if detected > 0: detected else: fallbackWidth)

proc print*(table: Table; maxWidth = 0; output: File = stdout) =
  ## Writes one rendered table followed by a newline.
  output.writeLine(table.render(maxWidth))
