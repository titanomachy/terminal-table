## Complete core and advanced feature showcase. Compile from the package root with
## ``nim r --path:src examples/all_tables.nim``.

import ../src/terminal_table
import ../src/terminal_table/typed_data
import ../src/terminal_table/csv_adapter
import ../src/terminal_table/json_adapter

type ExampleMetric = object
  internalId: int
  service: string
  requests: int

proc requestCount(value: int): string =
  $value & " req"

proc showTheme(name: string; theme: TableTheme) =
  echo "\n", bold(name)
  var table = initTable(["Region", "Requests", "Health"])
  table.theme = theme
  table.addRow("Europe", 1842, green("healthy"))
  table.addRow("Asia Pacific", 973, yellow("degraded"))
  table.column(1).alignment = alignRight
  echo table.render(maxWidth = 48)

when isMainModule:
  showTheme("ASCII", asciiTheme)
  showTheme("Modern Unicode", modernTheme)
  showTheme("Rounded", roundedTheme)
  showTheme("Borderless", borderlessTheme)
  showTheme("Markdown", markdownTheme)
  showTheme("psql", psqlTheme)

  echo "\n", bold("Responsive and multiline")
  var responsive = initTable(["Service", "Notes"])
  responsive.theme = roundedTheme
  responsive.columns[0].width = minimumWidth(8)
  responsive.addRow("api", "Healthy\nThree replicas available")
  responsive.addRow("worker", "A long message wraps to the requested width")
  responsive.header.style = initTerminalStyle(attributes = {taBold})
  responsive.cell(0, 0).setVerticalAlignment(valignCenter)
  echo responsive.render(maxWidth = 44)

  echo "\n", bold("Dynamic builder")
  var builder = initTableBuilder(["Key", "Value"])
  builder.addRow("language", "Nim")
  builder.addCell("phase")
  builder.addCell("2")
  builder.finishRow()
  var dynamicTable = builder.build()
  dynamicTable.theme = psqlTheme
  echo dynamicTable.render()

  echo "\n", bold("Selectors, spans, panels, footer, and shadow")
  var advanced = initTable(["Service", "Region", "Status", "Requests"])
  advanced.theme = roundedTheme
  advanced.setTitle("Production overview")
  advanced.title.setAlignment(alignCenter)
  discard advanced.addPanel("Updated live • all regions", panelTop)
  advanced.addRow("api", "Europe", "healthy", "1,842")
  advanced.addRow("", "Asia Pacific", "degraded", "973")
  advanced.cell(0, 0).setSpan(rows = 2)
  advanced.cell(0, 0).setVerticalAlignment(valignCenter)
  advanced.setFooter(["Total", "", "", "2,815"])
  advanced.footerCell(0).setSpan(columns = 3)
  advanced.highlight(headerSelector() or footerSelector(),
    initTerminalStyle(attributes = {taBold}))
  advanced.highlight(predicateSelector(proc(context: CellContext): bool =
    context.cell.text == "healthy"),
    initTerminalStyle(foreground = colorGreen))
  advanced.highlight(predicateSelector(proc(context: CellContext): bool =
    context.cell.text == "degraded"),
    initTerminalStyle(foreground = colorYellow))
  advanced.align(columnSelector(3), alignRight)
  advanced.column(0).setWidthPriority(10)
  advanced.colorBorders(initTerminalStyle(foreground = colorBrightBlack))
  advanced.setShadow(initShadow(style = initTerminalStyle(
    foreground = colorBrightBlack)))
  echo advanced.render(maxWidth = 62)

  echo "\n", bold("Transpose and composition")
  var matrix = initTable(Positive(3))
  matrix.theme = psqlTheme
  matrix.addRow("a", "b", "c")
  matrix.addRow("d", "e", "f")
  echo matrix.transpose().render()

  echo "\n", bold("Typed and JSON data adapters")
  let metrics = @[
    ExampleMetric(internalId: 1, service: "api", requests: 1842),
    ExampleMetric(internalId: 2, service: "worker", requests: 973)
  ]
  var typedTable = tableFromObjects(metrics,
    tableColumn(service, "Service"),
    tableColumn(requests, "Traffic", requestCount))
  typedTable.theme = roundedTheme
  echo typedTable.render()

  var delimited = tableFromCsv("Region;Requests\nEurope;1842\nAsia;973",
    separator = ';')
  delimited.theme = borderlessTheme
  echo delimited.render()

  var records = tableFromJson(
    """[{"region":"Europe","healthy":true},{"region":"Asia","healthy":false}]""")
  records.theme = psqlTheme
  echo records.render()
