## A compact, csvlens-inspired interactive CSV viewer built from the current
## terminal_tables API and Nim's standard terminal input helpers.
##
## Run with an embedded data set:
##   nim c -r --path:src examples/csv_viewer.nim
##
## Or open a CSV file:
##   nim c -r --path:src examples/csv_viewer.nim -- path/to/data.csv

import std/[os, strformat, terminal]

import ../src/terminal_tables/csv_adapter

const sampleCsv = """Name,Language,Stars,Status,Description
terminal_tables,Nim,128,active,Responsive styled terminal tables
terminal_styles,Nim,64,active,ANSI styling and display width
csvlens,Rust,3900,active,Interactive CSV viewer
Nim,Nim,17000,active,Efficient expressive programming language
SQLite,C,8300,active,Embedded relational database
PostgreSQL,C,18000,active,Advanced open source database
Redis,C,70000,active,In-memory data store
ripgrep,Rust,56000,active,Fast recursive text search
bat,Rust,54000,active,Cat clone with syntax highlighting
fzf,Go,76000,active,Command-line fuzzy finder
"""

type ViewerState = object
  row, column: int
  rowOffset, columnOffset: int

proc detectedWidth(): int =
  let width = terminalWidth()
  if width > 0: width else: 80

proc detectedHeight(): int =
  let height = terminalHeight()
  if height > 0: height else: 24

proc fitViewport(source: Table; state: var ViewerState;
                 visibleRows, visibleColumns: int) =
  if source.rows.len == 0:
    state.row = 0
    state.rowOffset = 0
  else:
    state.row = min(max(state.row, 0), source.rows.high)
    state.rowOffset = min(state.rowOffset,
      max(0, source.rows.len - visibleRows))
    if state.row < state.rowOffset:
      state.rowOffset = state.row
    elif state.row >= state.rowOffset + visibleRows:
      state.rowOffset = state.row - visibleRows + 1

  state.column = min(max(state.column, 0), source.columnCount - 1)
  state.columnOffset = min(state.columnOffset,
    max(0, source.columnCount - visibleColumns))
  if state.column < state.columnOffset:
    state.columnOffset = state.column
  elif state.column >= state.columnOffset + visibleColumns:
    state.columnOffset = state.column - visibleColumns + 1

proc buildViewport(source: Table; state: var ViewerState;
                   sourceName: string): Table =
  let
    width = detectedWidth()
    height = detectedHeight()
    visibleRows = max(1, height - 8)
    visibleColumns = min(source.columnCount,
      max(1, (width - 7) div 18))

  source.fitViewport(state, visibleRows, visibleColumns)

  let
    rowEnd = min(source.rows.len, state.rowOffset + visibleRows)
    columnEnd = min(source.columnCount,
      state.columnOffset + visibleColumns)

  var headers = @["#"]
  for columnIndex in state.columnOffset ..< columnEnd:
    headers.add source.header.cells[columnIndex].text

  result = initTable(headers)
  for rowIndex in state.rowOffset ..< rowEnd:
    var values = @[$(rowIndex + 1)]
    for columnIndex in state.columnOffset ..< columnEnd:
      values.add source.rows[rowIndex].cells[columnIndex].text
    result.addRow(initRow(values))

  result.theme = roundedTheme
  result.theme.showRowSeparators = false
  result.overflow = overflowTruncate
  result.header.style = initTerminalStyle(
    foreground = colorBrightCyan, attributes = {taBold})
  result.borderStyle = initTerminalStyle(foreground = colorBrightBlack)

  let rowNumberWidth = max(3, ($max(source.rows.len, 1)).len)
  result.column(0).width = fixedWidth(Positive(rowNumberWidth))
  result.column(0).setAlignment(alignRight)
  result.column(0).style = initTerminalStyle(foreground = colorBrightBlack)
  for columnIndex in 1 ..< result.columnCount:
    result.column(columnIndex).width = maximumWidth(24)

  result.setTitle(&"{sourceName}  •  {source.rows.len} rows × " &
    &"{source.columnCount} columns")
  result.title.style = initTerminalStyle(
    foreground = colorBrightCyan, attributes = {taBold})

  let
    displayedRow = if source.rows.len == 0: 0 else: state.row + 1
    status = &"row {displayedRow}/{source.rows.len}  •  " &
      &"column {state.column + 1}/{source.columnCount}  •  " &
      "h/j/k/l move  g/G ends  r reset  Enter print  q quit"
    statusPanel = result.addPanel(status, panelBottom)
  result.panel(statusPanel).style = initTerminalStyle(
    foreground = colorBrightBlack)

  if source.rows.len > 0:
    let
      localRow = state.row - state.rowOffset
      localColumn = state.column - state.columnOffset + 1
    result.cell(localRow, localColumn).style = initTerminalStyle(
      foreground = colorBrightWhite,
      background = indexedColor(24),
      attributes = {taBold})
    result.headerCell(localColumn).style = initTerminalStyle(
      foreground = colorBrightCyan,
      attributes = {taBold, taUnderline})

proc loadSource(): tuple[table: Table, name: string] =
  case paramCount()
  of 0:
    result = (tableFromCsv(sampleCsv), "embedded-projects.csv")
  of 1:
    let filename = paramStr(1)
    result = (tableFromCsvFile(filename), filename.extractFilename())
  else:
    quit("Usage: csv_viewer [file.csv]", QuitFailure)

when isMainModule:
  if not stdin.isatty or not stdout.isatty:
    quit("csv_viewer requires an interactive terminal", QuitFailure)

  let source = loadSource()
  var state: ViewerState
  var options = initLiveTableOptions()
  options.alternateScreen = true
  var live = initLiveTable(
    buildViewport(source.table, state, source.name), options)
  var
    running = true
    printSelection = false
    selectedValue = ""

  live.startLive()
  try:
    while running:
      live.table = buildViewport(source.table, state, source.name)
      live.draw()
      case getch()
      of 'q':
        running = false
      of 'h':
        state.column = max(0, state.column - 1)
      of 'j':
        if source.table.rows.len > 0:
          state.row = min(source.table.rows.high, state.row + 1)
      of 'k':
        state.row = max(0, state.row - 1)
      of 'l':
        state.column = min(source.table.columnCount - 1, state.column + 1)
      of 'g':
        state.row = 0
      of 'G':
        if source.table.rows.len > 0:
          state.row = source.table.rows.high
      of '0':
        state.column = 0
      of '$':
        state.column = source.table.columnCount - 1
      of 'r':
        state = ViewerState()
      of '\r', '\n':
        if source.table.rows.len > 0:
          selectedValue = source.table.cell(state.row, state.column).text
          printSelection = true
          running = false
      else:
        discard
  finally:
    live.stopLive()

  if printSelection:
    echo selectedValue
