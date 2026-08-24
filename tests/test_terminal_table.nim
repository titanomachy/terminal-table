import std/[os, sequtils, strutils, tempfiles, unittest]

import terminal_table

suite "table model and builders":
  test "constructs a header and validated rows":
    var table = initTable(["Name", "Role"])
    table.addRow("Alice", "Admin")
    table.addRow("Bob", "User")
    check table.columnCount == 2
    check table.hasHeader
    check table.rows.len == 2
    check table.cell(1, 0).text == "Bob"

  test "rejects ragged rows consistently":
    var table = initTable(["A", "B"])
    expect ValueError:
      table.addRow("only one")
    expect ValueError:
      table.setHeader(["too", "many", "columns"])

  test "builds runtime-shaped data and validates it at build time":
    var builder = initTableBuilder(["Key", "Value"])
    builder.addCell("language")
    builder.addCell("Nim")
    builder.finishRow()
    builder.addRow("version", 2)
    let table = builder.build()
    check table.rows.mapIt(it.cells.mapIt(it.text)) ==
      @[@["language", "Nim"], @["version", "2"]]

    builder.rows.add @["ragged"]
    expect ValueError:
      discard builder.build()

suite "themes and basic rendering":
  test "renders an exact ASCII table":
    var table = initTable(["Name", "Role"])
    table.theme = asciiTheme
    table.addRow("Alice", "Admin")
    check table.render() == """
+-------+-------+
| Name  | Role  |
+-------+-------+
| Alice | Admin |
+-------+-------+"""

  test "supports all built-in themes":
    var table = initTable(["A", "B"])
    table.addRow("1", "2")
    table.theme = modernTheme
    check table.render().startsWith("┌───┬───┐")
    table.theme = roundedTheme
    check table.render().startsWith("╭───┬───╮")
    table.theme = borderlessTheme
    check table.render() == " A  B \n 1  2 "
    table.theme = markdownTheme
    check table.render() == "| A | B |\n|---|---|\n| 1 | 2 |"
    table.theme = psqlTheme
    check table.render() == " A | B \n---+---\n 1 | 2 "

  test "accepts custom border definitions":
    let borders = BorderSet(
      topLeft: "#", topJoin: "#", topRight: "#",
      middleLeft: "#", middleJoin: "#", middleRight: "#",
      bottomLeft: "#", bottomJoin: "#", bottomRight: "#",
      horizontal: "=", vertical: "!")
    var table = initTable(["x"])
    table.theme = customTheme(borders)
    check table.render() == "#===#\n! x !\n#===#\n#===#"

suite "cell layout":
  test "aligns columns and individual cells horizontally":
    var table = initTable(["Key", "Value"])
    table.theme = asciiTheme
    table.columns[0].width = fixedWidth(5)
    table.columns[1].width = fixedWidth(5)
    table.column(1).alignment = alignRight
    table.addRow("x", "12")
    table.cell(0, 0).setAlignment(alignCenter)
    let lines = table.render().splitLines()
    check lines[1] == "| Key   | Value |"
    check lines[3] == "|   x   |    12 |"

  test "aligns multiline cells vertically":
    var table = initTable(Positive(2))
    table.theme = psqlTheme
    table.padding = initCellPadding(0, 0)
    table.columns[0].width = fixedWidth(3)
    table.columns[1].width = fixedWidth(3)
    table.addRow("x", "a\nb\nc")
    table.cell(0, 0).verticalAlignment = valignBottom
    check table.render() == "   |a  \n   |b  \nx  |c  "

  test "applies cell padding and table margins":
    var table = initTable(Positive(1))
    table.theme = asciiTheme
    table.padding = initCellPadding(2, 1, 1, 1)
    table.margin = initTableMargin(1, 2, 1, 1)
    table.addRow("x")
    let lines = table.render().splitLines()
    check lines.len == 7
    check lines.allIt(displayWidth(it) == 9)
    check lines[0] == repeat(' ', 9)
    check lines[3] == " |  x |  "

suite "widths and responsive fitting":
  test "supports fixed minimum maximum and content widths":
    var table = initTable(["A", "B", "C", "D"])
    table.theme = asciiTheme
    table.padding = initCellPadding(0, 0)
    table.addRow("long", "x", "long", "wide")
    table.columns[0].width = fixedWidth(2)
    table.columns[1].width = minimumWidth(3)
    table.columns[2].width = maximumWidth(2)
    table.columns[3].width = contentWidth
    let top = table.render().splitLines()[0]
    check top == "+--+---+--+----+"

  test "fits percentage and content columns to an explicit width":
    var table = initTable(["Service", "Description"])
    table.theme = roundedTheme
    table.columns[0].width = percentageWidth(30)
    table.addRow("api", "A deliberately long description that wraps")
    let output = table.render(maxWidth = 28)
    check output.splitLines().allIt(displayWidth(it) <= 28)
    check stripAnsi(output).contains("deliberately")

  test "fits very large content without width-dependent iteration":
    var table = initTable(Positive(2))
    table.theme = borderlessTheme
    table.padding = initCellPadding(0, 0)
    table.overflow = overflowTruncate
    table.addRow(repeat('x', 100_000), "short")
    check table.render(maxWidth = 20).splitLines().allIt(
      displayWidth(it) <= 20)

  test "reports impossible responsive constraints":
    var table = initTable(["A", "B"])
    table.columns[0].width = fixedWidth(10)
    table.columns[1].width = fixedWidth(10)
    expect ValueError:
      discard table.render(maxWidth = 12)

  test "keeps wide graphemes inside a narrow responsive allocation":
    var table = initTable(Positive(1))
    table.theme = asciiTheme
    table.padding = initCellPadding(0, 0)
    table.addRow("界界")
    let output = table.render(maxWidth = 3)
    check output.splitLines().allIt(displayWidth(it) == 3)
    check output.contains("…")

  test "wraps by words or characters and truncates with a suffix":
    var table = initTable(Positive(1))
    table.theme = borderlessTheme
    table.padding = initCellPadding(0, 0)
    table.columns[0].width = fixedWidth(4)
    table.addRow("one two")
    check table.render() == "one \ntwo "
    table.overflow = overflowWrapCharacters
    check table.render() == "one \ntwo "
    table.overflow = overflowTruncate
    table.truncationSuffix = ".."
    check table.render() == "on.."

suite "ANSI and Unicode rendering":
  test "measures styled and wide content in terminal cells":
    var table = initTable([bold("State"), "City"])
    table.theme = asciiTheme
    table.addRow(green("ready"), "東京")
    let output = table.render()
    check output.contains(termBold)
    check output.splitLines().allIt(displayWidth(it) == 16)

  test "can disable both supplied and configured colors":
    var table = initTable(["State"])
    table.addRow(red("failed"))
    table.style = initTerminalStyle(attributes = {taBold})
    table.borderStyle = initTerminalStyle(foreground = colorBlue)
    table.useColor = false
    check '\e' notin table.render()
    check table.render().contains("failed")

  test "cascades table row column and cell styles":
    var table = initTable(Positive(1))
    table.theme = borderlessTheme
    table.padding = initCellPadding(0, 0)
    table.addRow("styled")
    table.style = initTerminalStyle(attributes = {taBold})
    table.row(0).style = initTerminalStyle(foreground = colorGreen)
    table.column(0).style = initTerminalStyle(background = colorBlack)
    table.cell(0, 0).style = initTerminalStyle(attributes = {taUnderline})
    let output = table.render()
    check output.startsWith("\e[1;4;32;40m")
    check stripAnsi(output) == "styled"

suite "validation":
  test "rejects invalid dimensions and border glyphs":
    var table = initTable(["A"])
    expect ValueError:
      discard table.render(-1)
    table.padding.left = -1
    expect ValueError:
      discard table.render()
    table.padding = initCellPadding()
    table.theme.borders.horizontal = "界"
    expect ValueError:
      discard table.render()
    expect ValueError:
      discard initShadow(glyph = "界")

suite "selectors and modifiers":
  test "selects rows columns cells segments sections and predicates":
    var table = initTable(["A", "B", "C"])
    table.addRow("a0", "b0", "c0")
    table.addRow("a1", "b1", "c1")
    table.setFooter(["fa", "fb", "fc"])
    check table.matchingCells(rowSelector(1)).len == 3
    check table.matchingCells(columnSelector(1)).len == 4
    check table.matchingCells(cellSelector(0, 2)).len == 1
    check table.matchingCells(segmentSelector(0, 1, 1, 2)).len == 4
    check table.matchingCells(headerSelector() or footerSelector()).len == 6
    let endingInOne = predicateSelector(proc(context: CellContext): bool =
      context.cell.text.endsWith("1"))
    check table.matchingCells(endingInOne).len == 3

  test "applies alignment and highlighting once through selector unions":
    var table = initTable(["A", "B"])
    table.addRow("x", "y")
    let chosen = rowSelector(0) or cellSelector(0, 0)
    table.highlight(chosen, initTerminalStyle(foreground = colorCyan,
      attributes = {taBold}))
    table.align(cellSelector(0, 1), alignRight)
    check table.cell(0, 0).style.attributes == {taBold}
    check table.cell(0, 1).alignment == alignRight
    check table.render().contains("\e[1;36m")

suite "sections panels spans and decoration":
  test "renders a title top and bottom panels and footer in order":
    var table = initTable(["Name", "Value"])
    table.theme = asciiTheme
    table.setTitle("Report")
    discard table.addPanel("generated now", panelTop)
    table.addRow("items", "3")
    discard table.addPanel("end of data", panelBottom)
    table.setFooter(["total", "3"])
    let plain = stripAnsi(table.render())
    check plain.find("Report") < plain.find("Name")
    check plain.find("generated now") < plain.find("Name")
    check plain.find("end of data") > plain.find("items")
    check plain.find("total") > plain.find("end of data")
    check plain.splitLines().allIt(displayWidth(it) == displayWidth(plain.splitLines()[0]))

  test "shares one separator between adjacent header and footer":
    var table = initTable(["A"])
    table.theme = asciiTheme
    table.setFooter(["z"])
    check table.render().splitLines().len == 5

  test "renders horizontal and vertical spans at a fixed width":
    var table = initTable(Positive(3))
    table.theme = asciiTheme
    table.padding = initCellPadding(0, 0)
    table.addRow("combined", "hidden", "hidden")
    table.addRow("left", "x", "y")
    table.addRow("hidden", "p", "q")
    table.cell(0, 0).setSpan(columns = 3)
    table.cell(1, 0).setSpan(rows = 2)
    let output = table.render(maxWidth = 24)
    check output.contains("|combined")
    check not output.contains("hidden")
    check output.splitLines().allIt(displayWidth(it) <= 24)
    # The first data line has no internal vertical separator.
    check output.splitLines()[1].count('|') == 2

  test "wraps ANSI styled content across a combined span width":
    var table = initTable(Positive(2))
    table.theme = asciiTheme
    table.padding = initCellPadding(0, 0)
    table.addRow(green("alpha beta gamma"), "covered")
    table.cell(0, 0).setSpan(columns = 2)
    let output = table.render(maxWidth = 11)
    check output.contains(termGreen)
    check stripAnsi(output).contains("alpha")
    check output.splitLines().allIt(displayWidth(it) == 11)

  test "rejects spans that leave a section or overlap":
    var outside = initTable(Positive(2))
    outside.addRow("a", "b")
    outside.cell(0, 1).setSpan(columns = 2)
    expect ValueError:
      discard outside.render()

    var overlap = initTable(Positive(3))
    overlap.addRow("a", "b", "c")
    overlap.cell(0, 0).setSpan(columns = 2)
    overlap.cell(0, 1).setSpan(columns = 2)
    expect ValueError:
      discard overlap.render()

  test "uses width priorities and accounts for styled shadows":
    var table = initTable(Positive(2))
    table.theme = borderlessTheme
    table.padding = initCellPadding(0, 0)
    table.overflow = overflowTruncate
    table.addRow("AAAAAA", "BBBBBB")
    table.column(0).setWidthPriority(10)
    table.column(1).setWidthPriority(0)
    table.setShadow(initShadow(right = 1, bottom = 1, glyph = "#",
      style = initTerminalStyle(foreground = colorBrightBlack)))
    let output = table.render(maxWidth = 7)
    check output.splitLines().allIt(displayWidth(it) == 7)
    check stripAnsi(output).startsWith("AAAA")
    check output.contains(termBrightBlack)

suite "live tables":
  test "updates cells and retains a bounded rolling row window":
    var table = initTable(["Service", "Requests"])
    table.theme = borderlessTheme
    table.padding = initCellPadding(0, 0)
    table.addRow("api", "10")
    table.addRow("worker", "20")
    table.addRow("queue", "30")

    var options = initLiveTableOptions()
    options.availableWidth = 30
    options.maxRows = 2
    var live = initLiveTable(table, options)
    check live.maxRows == 2
    check live.table.rows.mapIt(it.cells[0].text) == @["worker", "queue"]

    live.updateCell(0, 1, 25)
    live.replaceRow(1, "queue", 35)
    live.addRow("scheduler", 40)
    check live.table.rows.mapIt(it.cells[0].text) == @["queue", "scheduler"]
    check live.table.cell(0, 1).text == "35"
    check live.renderFrame().splitLines().allIt(it.displayWidth <= 30)

    live.setMaxRows(1)
    check live.table.rows.len == 1
    check live.table.cell(0, 0).text == "scheduler"
    expect ValueError:
      live.setMaxRows(-1)
    expect ValueError:
      live.replaceRow(0, "ragged")

  test "validates live table options before changing terminal state":
    let table = initTable(Positive(1))
    var options = initLiveTableOptions()
    options.fallbackWidth = 0
    expect ValueError:
      discard initLiveTable(table, options)
    options = initLiveTableOptions()
    options.maxRows = -1
    expect ValueError:
      discard initLiveTable(table, options)
    expect ValueError:
      discard initLiveTable(table, output = nil)

  when defined(posix):
    test "redraws full-screen frames and restores terminal state":
      let (output, path) = createTempFile(
        "terminal_table_full_screen_", ".txt")
      var outputOpen = true
      defer:
        if outputOpen:
          output.close()
        if path.fileExists:
          path.removeFile()

      var table = initTable(Positive(1))
      table.theme = borderlessTheme
      table.padding = initCellPadding(0, 0)
      table.addRow("live value")
      var options = initLiveTableOptions()
      options.alternateScreen = false
      options.availableWidth = 20
      var live = initLiveTable(table, options, output)

      expect ValueError:
        live.draw()
      live.startLive()
      live.startLive()
      check live.isActive
      live.draw()
      live.stopLive()
      live.stopLive()
      check not live.isActive

      output.close()
      outputOpen = false
      let emitted = path.readFile()
      check emitted.startsWith("\e[2J\e[H\e[?25l")
      check "\e[Hlive value\e[J" in emitted
      check "\e[2K" notin emitted
      check emitted.endsWith("\e[0m\e[?25h")

    test "clears resize-wrapped physical rows in in-place mode":
      let (output, path) = createTempFile(
        "terminal_table_in_place_", ".txt")
      var outputOpen = true
      defer:
        if outputOpen:
          output.close()
        if path.fileExists:
          path.removeFile()

      var table = initTable(Positive(1))
      table.theme = borderlessTheme
      table.padding = initCellPadding(0, 0)
      table.overflow = overflowTruncate
      table.addRow("123456789012345678")
      var options = initLiveTableOptions()
      options.mode = ltmInPlace
      options.alternateScreen = false
      options.availableWidth = 20
      var live = initLiveTable(table, options, output)
      live.startLive()
      live.draw()
      live.options.availableWidth = 6
      live.draw()
      live.stopLive()

      output.close()
      outputOpen = false
      let emitted = path.readFile()
      # The old 18-cell line occupies three rows after shrinking to six cells.
      check "\e[3A\e[J" in emitted

suite "table transformations":
  test "transposes and rotates body values":
    var table = initTable(Positive(3))
    table.addRow("a", "b", "c")
    table.addRow("d", "e", "f")
    var transposed = table.transpose()
    check transposed.rows.mapIt(it.cells.mapIt(it.text)) ==
      @[@["a", "d"], @["b", "e"], @["c", "f"]]
    check table.rotateClockwise().rows.mapIt(it.cells.mapIt(it.text)) ==
      @[@["d", "a"], @["e", "b"], @["f", "c"]]
    check table.rotateCounterClockwise().rows.mapIt(it.cells.mapIt(it.text)) ==
      @[@["c", "f"], @["b", "e"], @["a", "d"]]
    check table.rotate180().rows.mapIt(it.cells.mapIt(it.text)) ==
      @[@["f", "e", "d"], @["c", "b", "a"]]

  test "transforms span dimensions with geometry":
    var table = initTable(Positive(2))
    table.addRow("wide", "covered")
    table.addRow("x", "y")
    table.cell(0, 0).setSpan(columns = 2)
    var transposed = table.transpose()
    check transposed.cell(0, 0).rowSpan == 2
    check transposed.cell(0, 0).columnSpan == 1
    discard transposed.render()

  test "concatenates and merges equally shaped tables":
    var left = initTable(Positive(1))
    left.addRow("left")
    var right = initTable(Positive(1))
    right.addRow("right")
    check horizontalConcat(left, right).rows[0].cells.mapIt(it.text) ==
      @["left", "right"]
    check verticalConcat(left, right).rows.mapIt(it.cells[0].text) ==
      @["left", "right"]
    var blank = initTable(Positive(1))
    blank.addRow("")
    check merge(blank, right).cell(0, 0).text == "right"

  test "extracts removes duplicates and splits rows and columns":
    var table = initTable(["A", "B", "C"])
    table.addRow("a", "b", "c")
    table.addRow("d", "e", "f")
    check table.extractRows([1]).rows[0].cells[0].text == "d"
    check table.removeRows([0]).rows.len == 1
    check table.duplicateRow(0, 2).rows.len == 4
    let rowParts = table.splitRows(1)
    check rowParts.before.rows.len == 1
    check rowParts.after.rows.len == 1
    check table.extractColumns([2, 0]).header.cells.mapIt(it.text) == @["C", "A"]
    check table.removeColumns([1]).columnCount == 2
    check table.duplicateColumn(1).columnCount == 4
    let columnParts = table.splitColumns(1)
    check columnParts.before.columnCount == 1
    check columnParts.after.columnCount == 2
