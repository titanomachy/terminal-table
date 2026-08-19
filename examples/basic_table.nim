## A small table that can be compiled directly from this repository:
## ``nim c -r examples/basic_table.nim``.

import ../src/terminal_tables

when isMainModule:
  var table = initTable(["Name", "Role", "Status"])
  table.addRow("Alice", "Administrator", green("online"))
  table.addRow("Bob", "Developer", yellow("away"))
  table.theme = roundedTheme
  table.column(1).alignment = alignCenter
  table.column(2).alignment = alignRight

  echo table.render(maxWidth = 60)
