# Package

version       = "0.1.0"
author        = "titanomachy"
description   = "Pure-Nim terminal table construction and rendering"
license       = "MIT"
srcDir        = "src"


# Dependencies

requires "nim >= 2.0.0"
requires "terminal_styles >= 0.1.0"

task test, "Run the terminal table test suite":
  exec "nim r --path:src tests/test_terminal_tables.nim"
  exec "nim r --path:src tests/test_typed_data.nim"

task examples, "Check that all examples compile":
  exec "nim check examples/basic_table.nim"
  exec "nim check examples/all_tables.nim"
  exec "nim check examples/advanced_tables.nim"
  exec "nim check examples/csv_viewer.nim"
  exec "nim check examples/data_adapters.nim"
  exec "nim check examples/live_data_table.nim"
  exec "nim check examples/transform_tables.nim"

task docs, "Generate terminal_tables API documentation":
  exec "nim doc --outdir:htmldocs --path:src src/terminal_tables.nim"
  exec "nim doc --outdir:htmldocs --path:src src/terminal_tables/builders.nim"
  exec "nim doc --outdir:htmldocs --path:src src/terminal_tables/layouts.nim"
  exec "nim doc --outdir:htmldocs --path:src src/terminal_tables/live_tables.nim"
  exec "nim doc --outdir:htmldocs --path:src src/terminal_tables/modifiers.nim"
  exec "nim doc --outdir:htmldocs --path:src src/terminal_tables/renderers.nim"
  exec "nim doc --outdir:htmldocs --path:src src/terminal_tables/selectors.nim"
  exec "nim doc --outdir:htmldocs --path:src src/terminal_tables/tables.nim"
  exec "nim doc --outdir:htmldocs --path:src src/terminal_tables/themes.nim"
  exec "nim doc --outdir:htmldocs --path:src src/terminal_tables/transformations.nim"
  exec "nim doc --outdir:htmldocs --path:src src/terminal_tables/typed_data.nim"
  exec "nim doc --outdir:htmldocs --path:src src/terminal_tables/csv_adapter.nim"
  exec "nim doc --outdir:htmldocs --path:src src/terminal_tables/json_adapter.nim"
