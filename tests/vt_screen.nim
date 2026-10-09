## Small test screen for cursor positioning, delayed wrapping, and VT erases.
## It models the controls used by live frame updates without a platform TTY.

import std/strutils
import terminal_style

type VtScreen* = object
  lines*: seq[string]
  row, column: int
  wrapPending: bool

proc initVtScreen*(height, width: int; fill = ' '): VtScreen =
  for _ in 0 ..< height:
    result.lines.add repeat(fill, width)

proc nextRow(screen: var VtScreen) =
  inc screen.row
  if screen.row == screen.lines.len:
    let width = screen.lines[0].len
    screen.lines.delete(0)
    screen.lines.add repeat(' ', width)
    dec screen.row

proc feed*(screen: var VtScreen; output: string) =
  ## Processes ASCII frame text and the CSI controls emitted by live displays.
  for token in tokenizeAnsi(output):
    case token.kind
    of atkText:
      for character in token.value:
        case character
        of '\r':
          screen.column = 0
          screen.wrapPending = false
        of '\n':
          # Normal TTY output processing maps LF to CRLF.
          screen.column = 0
          screen.wrapPending = false
          screen.nextRow()
        else:
          if screen.wrapPending:
            screen.column = 0
            screen.nextRow()
          screen.lines[screen.row][screen.column] = character
          if screen.column == screen.lines[screen.row].high:
            screen.wrapPending = true
          else:
            inc screen.column
            screen.wrapPending = false
    of atkCsi:
      case token.value[^1]
      of 'H':
        let parameters = token.value[2 ..< token.value.high].split(';')
        screen.row = if parameters[0].len == 0: 0
          else: min(screen.lines.high, max(0, parseInt(parameters[0]) - 1))
        screen.column = if parameters.len < 2 or parameters[1].len == 0: 0
          else: min(screen.lines[0].high, max(0, parseInt(parameters[1]) - 1))
        screen.wrapPending = false
      of 'K', 'J':
        for column in screen.column .. screen.lines[screen.row].high:
          screen.lines[screen.row][column] = ' '
        if token.value[^1] == 'J':
          for row in screen.row + 1 .. screen.lines.high:
            screen.lines[row] = repeat(' ', screen.lines[row].len)
      of 'm', 'h', 'l':
        discard
      else:
        raise newException(ValueError, "unsupported test screen control")
    else:
      raise newException(ValueError, "unsupported test screen token")
