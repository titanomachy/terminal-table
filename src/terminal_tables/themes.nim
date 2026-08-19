## Built-in and custom terminal table border themes.

type
  BorderSet* = object
    ## Glyphs used for the corners, joins, rules, and vertical borders.
    topLeft*, topJoin*, topRight*: string
    middleLeft*, middleJoin*, middleRight*: string
    bottomLeft*, bottomJoin*, bottomRight*: string
    horizontal*, vertical*: string

  TableTheme* = object
    ## Border glyphs and visibility rules for a table.
    borders*: BorderSet
    showTop*, showBottom*: bool
    showOuterVertical*, showColumnSeparators*: bool
    showHeaderSeparator*, showRowSeparators*: bool

const
  asciiTheme* = TableTheme(
    borders: BorderSet(
      topLeft: "+", topJoin: "+", topRight: "+",
      middleLeft: "+", middleJoin: "+", middleRight: "+",
      bottomLeft: "+", bottomJoin: "+", bottomRight: "+",
      horizontal: "-", vertical: "|"),
    showTop: true, showBottom: true, showOuterVertical: true,
    showColumnSeparators: true, showHeaderSeparator: true,
    showRowSeparators: true)
    ## Portable borders using only ASCII characters.

  modernTheme* = TableTheme(
    borders: BorderSet(
      topLeft: "┌", topJoin: "┬", topRight: "┐",
      middleLeft: "├", middleJoin: "┼", middleRight: "┤",
      bottomLeft: "└", bottomJoin: "┴", bottomRight: "┘",
      horizontal: "─", vertical: "│"),
    showTop: true, showBottom: true, showOuterVertical: true,
    showColumnSeparators: true, showHeaderSeparator: true,
    showRowSeparators: true)
    ## Square Unicode box-drawing borders.

  roundedTheme* = TableTheme(
    borders: BorderSet(
      topLeft: "╭", topJoin: "┬", topRight: "╮",
      middleLeft: "├", middleJoin: "┼", middleRight: "┤",
      bottomLeft: "╰", bottomJoin: "┴", bottomRight: "╯",
      horizontal: "─", vertical: "│"),
    showTop: true, showBottom: true, showOuterVertical: true,
    showColumnSeparators: true, showHeaderSeparator: true,
    showRowSeparators: true)
    ## Rounded Unicode outer corners.

  borderlessTheme* = TableTheme(
    borders: BorderSet(), showTop: false, showBottom: false,
    showOuterVertical: false, showColumnSeparators: false,
    showHeaderSeparator: false, showRowSeparators: false)
    ## Removes every border; cell padding still separates content.

  markdownTheme* = TableTheme(
    borders: BorderSet(
      topLeft: "|", topJoin: "|", topRight: "|",
      middleLeft: "|", middleJoin: "|", middleRight: "|",
      bottomLeft: "|", bottomJoin: "|", bottomRight: "|",
      horizontal: "-", vertical: "|"),
    showTop: false, showBottom: false, showOuterVertical: true,
    showColumnSeparators: true, showHeaderSeparator: true,
    showRowSeparators: false)
    ## Markdown-compatible pipes and a header delimiter.

  psqlTheme* = TableTheme(
    borders: BorderSet(
      topLeft: "", topJoin: "+", topRight: "",
      middleLeft: "", middleJoin: "+", middleRight: "",
      bottomLeft: "", bottomJoin: "+", bottomRight: "",
      horizontal: "-", vertical: "|"),
    showTop: false, showBottom: false, showOuterVertical: false,
    showColumnSeparators: true, showHeaderSeparator: true,
    showRowSeparators: false)
    ## PostgreSQL-style output with a header rule and no outer border.

proc customTheme*(borders: BorderSet; showTop = true; showBottom = true;
                  showOuterVertical = true; showColumnSeparators = true;
                  showHeaderSeparator = true;
                  showRowSeparators = false): TableTheme =
  ## Creates a theme from caller-provided border glyphs.
  TableTheme(borders: borders, showTop: showTop, showBottom: showBottom,
    showOuterVertical: showOuterVertical,
    showColumnSeparators: showColumnSeparators,
    showHeaderSeparator: showHeaderSeparator,
    showRowSeparators: showRowSeparators)
