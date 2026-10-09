import std/[monotimes, strutils, times, unittest]

import terminal_table

proc sampleTable(rowCount: int; theme: TableTheme): Table =
  result = initTable(["A", "B", "C", "D"])
  result.theme = theme
  for row in 0 ..< rowCount:
    let text = $row
    result.addRow(text, text, text, text)

proc fastestRender(table: Table): int64 =
  # Warm up allocation and rendering before measuring. Take the fastest of
  # three samples to reduce interference from other work on shared CI hosts.
  discard table.render()
  result = high(int64)
  for sample in 0 ..< 3:
    let started = getMonoTime()
    let output = table.render()
    let elapsed = (getMonoTime() - started).inNanoseconds
    result = min(result, elapsed)
    # Consume the result outside the timed interval and check that every row
    # (and, when enabled, every separator) was actually rendered.
    let expectedNewlines = if table.theme.showRowSeparators:
      2 * table.rows.len + 2
    else:
      table.rows.len
    doAssert output.count('\n') == expectedNewlines

suite "rendering performance":
  test "rendering scales with row count, including row separators":
    # Regression for https://github.com/titanomachy/terminal-table/issues/3.
    # Eight times as many rows should cost roughly eight times as much, while
    # the old closure copying the table per separator costs about 64 times.
    # Allow three times the linear ratio for timing noise and allocator costs;
    # avoid a machine-dependent absolute deadline.
    for theme in [modernTheme, borderlessTheme]:
      let small = sampleTable(1000, theme).fastestRender()
      let large = sampleTable(8000, theme).fastestRender()
      let growth = large.float / max(1'i64, small).float
      let measurement = "row separators=" & $theme.showRowSeparators &
        ", 1000 rows=" & $small & " ns, 8000 rows=" & $large &
        " ns, growth=" & $growth
      echo "    ", measurement
      checkpoint measurement
      check growth < 24.0

  test "repeated rendering of a fixed table stays stable":
    # Build once: appending before each render measures row-count growth,
    # rather than slowdown across repeated renders of the same input.
    # Keep the run bounded for CI and compare the fastest samples in the
    # first and last windows to reduce interference from other processes.
    const repetitions = 200
    const windowSize = 20
    for theme in [modernTheme, borderlessTheme]:
      let table = sampleTable(4000, theme)
      let expected = table.render() # Also warms up the renderer.
      var first = high(int64)
      var last = high(int64)
      for sample in 0 ..< repetitions:
        let started = getMonoTime()
        let output = table.render()
        let elapsed = (getMonoTime() - started).inNanoseconds
        if sample < windowSize:
          first = min(first, elapsed)
        if sample >= repetitions - windowSize:
          last = min(last, elapsed)
        # Validate outside the timed interval; every render must keep the
        # same row count and produce exactly the same complete output.
        doAssert table.rows.len == 4000
        doAssert output == expected
      let growth = last.float / max(1'i64, first).float
      let measurement = "row separators=" & $theme.showRowSeparators &
        ", fixed rows=4000, renders=" & $repetitions &
        ", first window=" & $first & " ns, last window=" & $last &
        " ns, growth=" & $growth
      echo "    ", measurement
      checkpoint measurement
      # Allow generous headroom for timing noise, without an absolute
      # machine-dependent deadline or allocator-specific memory limits.
      check growth < 3.0
