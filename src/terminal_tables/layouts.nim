## Layout types shared by table models and renderers.

import terminal_styles

export terminal_styles

type
  VerticalAlignment* = enum
    ## Alignment of content within a cell that is taller than its text.
    valignTop,
    valignCenter,
    valignBottom

  OverflowMode* = enum
    ## How content that exceeds its allocated width is handled.
    overflowWrapWords,
    overflowWrapCharacters,
    overflowTruncate

  WidthKind* = enum
    ## Strategy used to choose a column's content width.
    widthContent,
    widthFixed,
    widthMinimum,
    widthMaximum,
    widthPercentage

  WidthConstraint* = object
    ## A column width rule. Width values exclude padding and borders.
    kind*: WidthKind
    value*: int

  CellPadding* = object
    ## Blank cells placed inside a cell around its content.
    left*, right*, top*, bottom*: int

  TableMargin* = object
    ## Blank cells and lines placed outside the complete table.
    left*, right*, top*, bottom*: int

  PanelPosition* = enum
    ## Placement of a full-width panel relative to normal table data.
    panelTop,
    panelBottom

  Shadow* = object
    ## Optional right and bottom table shadow. Sizes are terminal cells/lines.
    right*, bottom*: int
    glyph*: string
    style*: TerminalStyle

const
  contentWidth* = WidthConstraint(kind: widthContent)
    ## Uses the widest unwrapped value in the column.

proc fixedWidth*(width: Positive): WidthConstraint =
  ## Fixes a column's content width.
  WidthConstraint(kind: widthFixed, value: int(width))

proc minimumWidth*(width: Positive): WidthConstraint =
  ## Prevents a content-derived column from becoming narrower than ``width``.
  WidthConstraint(kind: widthMinimum, value: int(width))

proc maximumWidth*(width: Positive): WidthConstraint =
  ## Caps a content-derived column at ``width``.
  WidthConstraint(kind: widthMaximum, value: int(width))

proc percentageWidth*(percentage: range[1 .. 100]): WidthConstraint =
  ## Uses a percentage of the content space available within ``maxWidth``.
  WidthConstraint(kind: widthPercentage, value: int(percentage))

proc initCellPadding*(left = 1; right = 1; top = 0; bottom = 0): CellPadding =
  ## Constructs validated cell padding.
  if min(min(left, right), min(top, bottom)) < 0:
    raise newException(ValueError, "cell padding cannot be negative")
  CellPadding(left: left, right: right, top: top, bottom: bottom)

proc initTableMargin*(left = 0; right = 0; top = 0; bottom = 0): TableMargin =
  ## Constructs validated outer table margins.
  if min(min(left, right), min(top, bottom)) < 0:
    raise newException(ValueError, "table margins cannot be negative")
  TableMargin(left: left, right: right, top: top, bottom: bottom)

proc initShadow*(right = 1; bottom = 1; glyph = "░";
                 style = TerminalStyle()): Shadow =
  ## Constructs a validated table shadow. Zero sizes disable either edge.
  if right < 0 or bottom < 0:
    raise newException(ValueError, "shadow dimensions cannot be negative")
  if (right > 0 or bottom > 0) and
      (displayWidth(glyph) != 1 or '\n' in glyph or '\r' in glyph):
    raise newException(ValueError,
      "an enabled shadow glyph must occupy one terminal cell")
  Shadow(right: right, bottom: bottom, glyph: glyph, style: style)
