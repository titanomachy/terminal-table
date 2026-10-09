## Internal VT frame formatting shared by live displays and their tests.

import std/strutils
import terminal_style

proc fullScreenSequence*(frame: string; width, height: int): string =
  ## Paints a frame, then erases unused cells and rows without a screen clear.
  result = "\e[H"
  if frame.len == 0:
    result.add "\e[J"
    return
  let lines = frame.splitLines()
  for index, line in lines:
    result.add line
    if displayWidth(line) < width:
      result.add(if index == lines.high: "\e[J" else: "\e[K")
    elif index == lines.high and lines.len < height:
      # At the right margin the cursor still occupies the last printed cell.
      # Leave that row before erasing below, without scrolling a full screen.
      result.add "\r\n\e[J"
    if index < lines.high:
      result.add "\r\n"
