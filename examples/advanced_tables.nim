## Phase 3 selectors, panels, spans, decoration, and transformations.
## Compile from the package root with ``nim c -r examples/advanced_tables.nim``.

import ../src/terminal_table

proc dashboard(): Table =
  result = initTable(["Service", "Region", "Status", "Requests"])
  result.theme = roundedTheme
  result.setTitle("Production service overview")
  result.title.setAlignment(alignCenter)
  result.title.style = initTerminalStyle(foreground = colorBrightCyan,
    attributes = {taBold})
  discard result.addPanel("Updated live • all regions", panelTop)
  result.panel(0).setAlignment(alignCenter)

  result.addRow("gateway", "Global", "healthy", "2,815")
  result.addRow("api", "Europe", "healthy", "1,842")
  result.addRow("", "Asia Pacific", "degraded", "973")
  result.cell(1, 0).setSpan(rows = 2)
  result.cell(1, 0).setVerticalAlignment(valignCenter)
  result.setFooter(["Total", "", "", "4,657"])
  result.footerCell(0).setSpan(columns = 3)

  result.highlight(headerSelector() or footerSelector(),
    initTerminalStyle(attributes = {taBold}))
  result.highlight(predicateSelector(proc(context: CellContext): bool =
    context.cell.text == "healthy"),
    initTerminalStyle(foreground = colorGreen))
  result.highlight(predicateSelector(proc(context: CellContext): bool =
    context.cell.text == "degraded"),
    initTerminalStyle(foreground = colorYellow))
  result.align(columnSelector(3), alignRight)
  result.column(0).setWidthPriority(10)
  result.column(1).setWidthPriority(5)
  result.colorBorders(initTerminalStyle(foreground = colorBrightBlack))
  result.setShadow(initShadow(style = initTerminalStyle(
    foreground = colorBrightBlack)))

when isMainModule:
  var table = dashboard()
  echo table.render(maxWidth = 62)

  echo "\n", bold("Transposed body")
  var transformed = table.transpose()
  transformed.clearTitle()
  transformed.panels = @[]
  transformed.clearShadow()
  transformed.theme = psqlTheme
  echo transformed.render(maxWidth = 62)
