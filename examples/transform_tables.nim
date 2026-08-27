## Table transformation and composition showcase. Compile from the package
## root with ``nim r --path:src examples/transform_tables.nim``.

import ../src/terminal_table

proc inventory(): Table =
  result = initTable(["Item", "North", "South"])
  result.theme = roundedTheme
  result.addRow("Widgets", "12", "9")
  result.addRow("Gadgets", "4", "11")

when isMainModule:
  let source = inventory()

  echo bold("Source")
  echo source.render()

  echo "\n", bold("Body transposed")
  echo source.transpose().render()

  let (north, south) = source.splitColumns(2)
  echo "\n", bold("Split and recomposed")
  echo horizontalConcat(north, south).render()

  echo "\n", bold("Duplicated summary row")
  echo source.duplicateRow(1, 2).render()
