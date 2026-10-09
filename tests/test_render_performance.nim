import std/[algorithm, monotimes, strutils, times, unittest]

import terminal_table

when not defined(release):
  {.error: "Run performance checks with -d:release (or nimble test).".}

const
  rowCounts = [1000, 2000, 4000, 8000]
  sampleCount = 5
  targetBatchNanoseconds = 20_000_000'i64
  maxBatchRenders = 16
  maxTimePerRowGrowth = 3.0

type RenderWorkload = object
  table: Table
  expectedBytes: int
  batchRenders: int
  samples: seq[float]

proc sampleTable(rowCount: int; theme: TableTheme): Table =
  result = initTable(["A", "B", "C", "D"])
  result.theme = theme
  result.useColor = false
  for row in 0 ..< rowCount:
    # Keep content and column widths identical at every row count, so timings
    # measure row growth rather than additional digits or layout changes.
    result.addRow("x", "x", "x", "x")

proc prepare(workload: var RenderWorkload) =
  # Warm up each table, verify complete output, and calibrate short renders
  # into batches. The time target improves measurement resolution; it is not
  # an absolute deadline. Cap repetitions so calibration cannot explode.
  let started = getMonoTime()
  let output = workload.table.render()
  let elapsed = max(1'i64, (getMonoTime() - started).inNanoseconds)
  let expectedNewlines = if workload.table.theme.showRowSeparators:
    2 * workload.table.rows.len + 2
  else:
    workload.table.rows.len
  doAssert output.count('\n') == expectedNewlines
  workload.expectedBytes = output.len
  workload.batchRenders = int(min(maxBatchRenders.int64,
    max(1'i64, targetBatchNanoseconds div elapsed)))

proc measure(workload: var RenderWorkload) =
  var renderedBytes = 0
  let started = getMonoTime()
  for iteration in 0 ..< workload.batchRenders:
    renderedBytes += workload.table.render().len
  let elapsed = (getMonoTime() - started).inNanoseconds
  # Consume every result and verify the work outside the timed interval.
  doAssert renderedBytes == workload.expectedBytes * workload.batchRenders
  workload.samples.add elapsed.float / workload.batchRenders.float

proc median(samples: seq[float]): float =
  let ordered = samples.sorted()
  ordered[ordered.len div 2]

suite "rendering performance":
  for (name, theme) in [("modern", modernTheme), ("ASCII", asciiTheme),
      ("borderless", borderlessTheme)]:
    test name & " rendering scales with row count":
      # Regression for https://github.com/titanomachy/terminal-table/issues/3.
      var workloads: array[rowCounts.len, RenderWorkload]
      # Construct every table before timing; allocation while adding rows is
      # outside the rendering behavior this regression test covers.
      for index, rowCount in rowCounts:
        workloads[index].table = sampleTable(rowCount, theme)
      for workload in workloads.mitems:
        workload.prepare()

      # Rotate the order in each round to spread changes in host load across
      # sizes, then use medians rather than an unusually fast single sample.
      for round in 0 ..< sampleCount:
        for offset in 0 ..< workloads.len:
          workloads[(round + offset) mod workloads.len].measure()

      let baseline = workloads[0].samples.median()
      doAssert baseline > 0
      let baselineMeasurement = $rowCounts[0] & " rows: " &
        formatFloat(baseline / 1_000_000, ffDecimal, 2) & " ms"
      echo "    ", baselineMeasurement
      checkpoint baselineMeasurement
      for index in 1 ..< workloads.len:
        let elapsed = workloads[index].samples.median()
        let rowGrowth = rowCounts[index].float / rowCounts[0].float
        let timeGrowth = elapsed / baseline
        let measurement = $rowCounts[index] & " rows: " &
          formatFloat(elapsed / 1_000_000, ffDecimal, 2) & " ms, " &
          formatFloat(timeGrowth, ffDecimal, 2) & "x time for " &
          $(rowCounts[index] div rowCounts[0]) & "x rows"
        echo "    ", measurement
        checkpoint measurement
        # Linear work keeps time per row roughly constant; quadratic work
        # raises it with row count. Allow 3x headroom for CI noise and caches.
        check timeGrowth < rowGrowth * maxTimePerRowGrowth
