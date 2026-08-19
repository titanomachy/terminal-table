# Public API example map

Every exported table symbol has an API doc comment in its defining module.
The examples below are compiled by `nimble examples` and collectively exercise
the public feature families without requiring the package to be installed.

| API family | Defining modules | Runnable examples |
|---|---|---|
| Models, themes, rendering | `tables`, `themes`, `renderers` | `basic_table.nim`, `all_tables.nim` |
| Live and rolling tables | `live_tables` | `live_data_table.nim` |
| Runtime builders | `builders` | `all_tables.nim` |
| Layout, spans, panels, shadows | `layouts`, `tables`, `renderers` | `advanced_tables.nim`, `all_tables.nim` |
| Selectors and modifiers | `selectors`, `modifiers` | `advanced_tables.nim`, `all_tables.nim` |
| Rotation, extraction, and composition | `transformations` | `transform_tables.nim`, `all_tables.nim` |
| Typed object conversion | `typed_data` | `data_adapters.nim`, `all_tables.nim` |
| CSV and JSON input | `csv_adapter`, `json_adapter` | `data_adapters.nim`, `all_tables.nim` |

The examples use `when isMainModule` and relative source imports, so each is
both documentation and an executable development check. Exact output and
error contracts are covered by the test suites.
