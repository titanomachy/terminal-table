## Resize-safe live display support for mutable terminal tables.
##
## ``LiveTable`` separates data updates from terminal ownership. Applications
## mutate ``table`` or use the convenience update procedures, then call
## ``draw``. Full-screen mode replaces the complete terminal frame and can use
## the terminal's alternate screen. In-place mode preserves content above the
## table and accounts for terminal rows created by wrapping after a resize.

import std/[strutils, terminal]

when defined(windows):
  import std/winlean

import ./renderers

export renderers

type
  LiveTableMode* = enum
    ## Selects whether a live table owns the screen or only its recent rows.
    ltmFullScreen,
    ltmInPlace

  LiveTableOptions* = object
    ## Terminal lifecycle, sizing, and row-retention configuration.
    mode*: LiveTableMode
    alternateScreen*: bool
    availableWidth*: int
      ## Complete table width. Zero detects the terminal width on every draw.
    fallbackWidth*: int
      ## Used when automatic terminal-width detection is unavailable.
    maxRows*: int
      ## Maximum retained body rows. Zero keeps every row.

  LiveTable* = object
    ## A mutable table paired with an explicit live terminal lifecycle.
    table*: Table
    options*: LiveTableOptions
    output: File
    active: bool
    usingAlternateScreen: bool
    usingVtSequences: bool
    previousFrame: string
    when defined(windows):
      windowsConsoleHandle: Handle
      windowsOriginalMode: DWORD
      windowsModeChanged: bool

when defined(windows):
  const
    enableProcessedOutput = DWORD(0x0001)
    enableVirtualTerminalProcessing = DWORD(0x0004)

  proc getConsoleMode(handle: Handle; mode: ptr DWORD): WINBOOL {.
      stdcall, dynlib: "kernel32", importc: "GetConsoleMode".}

  proc setConsoleMode(handle: Handle; mode: DWORD): WINBOOL {.
      stdcall, dynlib: "kernel32", importc: "SetConsoleMode".}

  proc enableWindowsVt(live: var LiveTable): bool =
    if not live.output.isatty or
        (live.output != stdout and live.output != stderr):
      return false
    let handle = getStdHandle(
      if live.output == stderr: STD_ERROR_HANDLE else: STD_OUTPUT_HANDLE)
    if handle == INVALID_HANDLE_VALUE:
      return false
    var originalMode: DWORD
    if getConsoleMode(handle, addr originalMode) == 0:
      return false
    let requestedMode = originalMode or enableProcessedOutput or
      enableVirtualTerminalProcessing
    if requestedMode != originalMode and
        setConsoleMode(handle, requestedMode) == 0:
      return false
    live.windowsConsoleHandle = handle
    live.windowsOriginalMode = originalMode
    live.windowsModeChanged = requestedMode != originalMode
    true

  proc restoreWindowsConsoleMode(live: var LiveTable) =
    if live.windowsModeChanged:
      discard setConsoleMode(live.windowsConsoleHandle,
        live.windowsOriginalMode)
    live.windowsModeChanged = false

proc initLiveTableOptions*(): LiveTableOptions =
  ## Returns resize-safe full-screen defaults.
  LiveTableOptions(
    mode: ltmFullScreen,
    alternateScreen: true,
    availableWidth: 0,
    fallbackWidth: 80,
    maxRows: 0
  )

proc validate(options: LiveTableOptions) =
  if options.availableWidth < 0:
    raise newException(ValueError, "live table width cannot be negative")
  if options.fallbackWidth <= 0:
    raise newException(ValueError,
      "live table fallback width must be positive")
  if options.maxRows < 0:
    raise newException(ValueError, "live table maximum rows cannot be negative")

proc trimRows(live: var LiveTable) =
  if live.options.maxRows <= 0:
    return
  let excess = live.table.rows.len - live.options.maxRows
  if excess > 0:
    live.table.rows = live.table.rows[excess .. ^1]

proc initLiveTable*(table: Table;
                    options = initLiveTableOptions();
                    output: File = stdout): LiveTable =
  ## Creates a live table without changing terminal state.
  ##
  ## ``output`` is retained for the complete lifecycle. Automatic sizing uses
  ## the process terminal width; set ``availableWidth`` for a deterministic
  ## custom output or test stream.
  options.validate()
  if output == nil:
    raise newException(ValueError, "live table output cannot be nil")
  result = LiveTable(table: table, options: options, output: output)
  result.trimRows()

proc isActive*(live: LiveTable): bool =
  ## Returns whether ``startLive`` has been called without a matching stop.
  live.active

proc maxRows*(live: LiveTable): int =
  ## Returns the current body-row retention limit; zero means unlimited.
  live.options.maxRows

proc setMaxRows*(live: var LiveTable; maxRows: int) =
  ## Changes the body-row retention limit and immediately trims older rows.
  if maxRows < 0:
    raise newException(ValueError, "live table maximum rows cannot be negative")
  live.options.maxRows = maxRows
  live.trimRows()

proc updateCell*[T](live: var LiveTable; rowIndex, columnIndex: int;
                    value: T) =
  ## Replaces one body cell's text without rebuilding the table.
  live.table.cell(rowIndex, columnIndex).text = $value

proc replaceRow*(live: var LiveTable; rowIndex: int; row: Row) =
  ## Replaces one body row after validating its shape.
  if rowIndex < 0 or rowIndex >= live.table.rows.len:
    raise newException(IndexDefect, "row index is outside the live table")
  if row.cells.len != live.table.columnCount:
    raise newException(ValueError,
      "replacement row must match the live table column count")
  live.table.rows[rowIndex] = row

proc replaceRow*(live: var LiveTable; rowIndex: int;
                 values: varargs[string, `$`]) =
  ## Replaces one body row after validating its shape.
  var converted: seq[string]
  for value in values:
    converted.add value
  live.replaceRow(rowIndex, initRow(converted))

proc addRow*(live: var LiveTable; row: Row) =
  ## Appends a row and removes the oldest rows beyond ``maxRows``.
  live.table.addRow(row)
  live.trimRows()

proc addRow*(live: var LiveTable; values: varargs[string, `$`]) =
  ## Appends a row and removes the oldest rows beyond ``maxRows``.
  var converted: seq[string]
  for value in values:
    converted.add value
  live.addRow(initRow(converted))

proc resolvedWidth(live: LiveTable): int =
  live.options.validate()
  if live.options.availableWidth > 0:
    return live.options.availableWidth
  let detected = terminalWidth()
  if detected > 0: detected else: live.options.fallbackWidth

proc renderFrame*(live: LiveTable): string =
  ## Responsively renders the current table without modifying terminal state.
  live.table.render(live.resolvedWidth())

proc physicalLineCount(frame: string; width: int): int =
  ## Counts screen rows after terminal wrapping at the current width.
  if frame.len == 0:
    return 0
  for line in frame.splitLines():
    result += max((line.displayWidth + width - 1) div width, 1)

proc clearLinesSequence(lineCount: int): string =
  if lineCount > 0: "\e[" & $lineCount & "A\e[J" else: ""

proc fullScreenSequence(frame: string): string =
  ## Replaces only visible frame rows and emits the update as one write. The
  ## new content is painted before any unused row tail is erased, so terminals
  ## cannot present a blank scan line while processing the update. The final
  ## erase also removes rows left behind by a previously taller frame.
  result = "\e[H"
  if frame.len == 0:
    result.add "\e[J"
    return
  let lines = frame.splitLines()
  for index, line in lines:
    result.add line
    if index == lines.high:
      result.add "\e[J"
    else:
      result.add "\e[K"
      result.add '\n'

proc startLive*(live: var LiveTable) =
  ## Starts the configured display and hides the cursor.
  ##
  ## Calling this procedure again while active has no effect. Alternate-screen
  ## mode applies to a full-screen live table attached to a VT-capable TTY.
  if live.active:
    return
  live.options.validate()

  when defined(posix):
    live.usingVtSequences = true
  elif defined(windows):
    live.usingVtSequences = live.enableWindowsVt()

  if live.options.mode == ltmFullScreen and live.options.alternateScreen and
      live.output.isatty and live.usingVtSequences:
    live.output.write "\e[?1049h"
    live.usingAlternateScreen = true
  if live.options.mode == ltmFullScreen:
    if live.usingVtSequences:
      live.output.write "\e[2J\e[H"
    else:
      live.output.setCursorPos(0, 0)
      live.output.eraseScreen()
  if live.usingVtSequences:
    live.output.write "\e[?25l"
  else:
    live.output.hideCursor()
  live.output.flushFile()
  live.previousFrame.setLen(0)
  live.active = true

proc draw*(live: var LiveTable) =
  ## Renders and replaces the current live table frame.
  ##
  ## Full-screen mode always redraws from a cleared home position. In-place
  ## mode clears the physical height of the previous frame at the newly
  ## detected width, which accounts for resize-induced terminal wrapping.
  if not live.active:
    raise newException(ValueError, "call startLive before drawing a live table")
  let
    width = live.resolvedWidth()
    frame = live.table.render(width)
  case live.options.mode
  of ltmFullScreen:
    if live.usingVtSequences:
      # Keep the clear and replacement in one terminal write so an incomplete
      # frame is not presented between updates. On Windows this also avoids
      # Nim's eraseScreen, which clears the complete scrollback buffer through
      # several Win32 calls and can be visibly slow for a large buffer.
      live.output.write frame.fullScreenSequence()
    else:
      live.output.setCursorPos(0, 0)
      live.output.eraseScreen()
      live.output.write frame
  of ltmInPlace:
    if live.previousFrame.len > 0:
      live.output.write clearLinesSequence(
        live.previousFrame.physicalLineCount(width))
    live.output.write frame
    live.output.write '\n'
  live.output.flushFile()
  live.previousFrame = frame

proc stopLive*(live: var LiveTable) =
  ## Restores attributes, screen state, and cursor visibility.
  ##
  ## Calling this procedure for an inactive table has no effect.
  if not live.active:
    return
  if live.usingVtSequences:
    live.output.write "\e[0m"
    if live.usingAlternateScreen:
      live.output.write "\e[?1049l"
    live.output.write "\e[?25h"
  else:
    live.output.resetAttributes()
    live.output.showCursor()
  live.output.flushFile()
  when defined(windows):
    live.restoreWindowsConsoleMode()
  live.active = false
  live.usingAlternateScreen = false
  live.usingVtSequences = false
  live.previousFrame.setLen(0)
