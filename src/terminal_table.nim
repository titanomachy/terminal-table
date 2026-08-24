## Pure-Nim, Unicode-aware terminal table construction and rendering.
##
## Import this façade to access models, builders, selectors, modifiers,
## advanced layouts, transformations, themes, deterministic rendering, live
## table displays, and the shared ``terminal_style`` API.
##
## .. code-block:: nim
##
##   import terminal_table
##
##   var table = initTable(["Name", "Role"])
##   table.addRow("Alice", "Admin")
##   table.addRow("Bob", "User")
##   table.theme = roundedTheme
##   table.column(1).alignment = alignRight
##   echo table.render(maxWidth = 80)

import terminal_table/[builders, layouts, live_tables, modifiers, renderers,
  selectors, tables, themes, transformations]

export builders, layouts, live_tables, modifiers, renderers, selectors, tables,
  themes, transformations
