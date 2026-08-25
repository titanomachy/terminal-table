# Package

version       = "0.1.1"
author        = "titanomachy"
description   = "Pure-Nim terminal table construction and rendering"
license       = "MIT"
srcDir        = "src"


# Dependencies

requires "nim >= 2.0.0"
requires "terminal_style >= 0.1.1"

task test, "Run the terminal table test suite":
  exec "nim r --path:src tests/test_terminal_table.nim"
  exec "nim r --path:src tests/test_typed_data.nim"

task examples, "Check that all examples compile":
  exec "nim check examples/basic_table.nim"
  exec "nim check examples/all_tables.nim"
  exec "nim check examples/advanced_tables.nim"
  exec "nim check examples/csv_viewer.nim"
  exec "nim check examples/data_adapters.nim"
  exec "nim check examples/live_data_table.nim"
  exec "nim check examples/transform_tables.nim"

task docs, "Generate terminal_table API documentation":
  exec "nim doc --project --index:on --outdir:htmldocs --path:src src/terminal_table.nim"
  exec "nim doc --index:on --outdir:htmldocs --path:src src/terminal_table/typed_data.nim"
  exec "nim doc --index:on --outdir:htmldocs --path:src src/terminal_table/csv_adapter.nim"
  exec "nim doc --index:on --outdir:htmldocs --path:src src/terminal_table/json_adapter.nim"
  exec "nim buildIndex --out:htmldocs/theindex.html htmldocs"
  exec "nim md2html --out:htmldocs/index.html docs/api-index.md"
