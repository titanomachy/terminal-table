## Typed objects, CSV, and JSON adapters. Compile from the package root with
## ``nim c -r examples/data_adapters.nim``.

import ../src/terminal_table/typed_data
import ../src/terminal_table/csv_adapter
import ../src/terminal_table/json_adapter

type Build = object
  id: int
  name: string
  durationMs: int
  passed: bool

proc duration(value: int): string =
  $(value.float / 1000) & " s"

when isMainModule:
  echo bold("Typed object data")
  let builds = @[
    Build(id: 101, name: "compiler", durationMs: 1840, passed: true),
    Build(id: 102, name: "tests", durationMs: 3210, passed: true)
  ]
  var typedTable = tableFromObjects(builds,
    tableColumn(name, "Build"),       # id is intentionally hidden
    tableColumn(durationMs, "Time", duration),
    tableColumn(passed, "Passed"))
  typedTable.theme = roundedTheme
  echo typedTable.render()

  echo "\n", bold("CSV data")
  var csvTable = tableFromCsv("Region,Requests\nEurope,1842\nAsia Pacific,973")
  csvTable.theme = psqlTheme
  csvTable.column(1).setAlignment(alignRight)
  echo csvTable.render()

  echo "\n", bold("JSON records")
  var jsonTable = tableFromJson("""[
    {"service":"api","status":"healthy"},
    {"service":"worker","status":"degraded","region":"eu"}
  ]""", missingValue = "-")
  jsonTable.theme = modernTheme
  echo jsonTable.render()

