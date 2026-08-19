## Continuously append simulated service metrics to a resize-safe live table.
## Stop it with Ctrl+C.

when isMainModule:
  import std/[atomics, os, random, strformat, times]

  import ../src/terminal_tables

  randomize()

  var stopRequested: Atomic[bool]

  proc requestStop() {.noconv.} =
    ## A signal handler may only perform signal-safe work.
    stopRequested.store(true)

  proc statusText(latencyMs: int): string =
    if latencyMs < 45:
      green("healthy")
    elif latencyMs < 85:
      yellow("degraded")
    else:
      brightRed("critical")

  var table = initTable(
    ["Time", "Service", "Requests", "Latency", "Status"])
  table.theme = roundedTheme
  table.overflow = overflowTruncate
  table.header.style = initTerminalStyle(attributes = {taBold})
  table.column(0).setWidthPriority(10)
  table.column(1).setWidthPriority(8)
  table.column(2).setAlignment(alignRight)
  table.column(3).setAlignment(alignRight)

  var options = initLiveTableOptions()
  options.maxRows = 12
  var live = initLiveTable(table, options)
  let services = ["api", "worker", "queue", "scheduler"]

  live.startLive()
  setControlCHook(requestStop)
  try:
    while not stopRequested.load():
      let
        service = services[rand(services.high)]
        requests = rand(950) + 50
        latencyMs = rand(110) + 10
      live.addRow(
        now().format("HH:mm:ss"),
        service,
        requests,
        &"{latencyMs} ms",
        statusText(latencyMs)
      )
      live.draw()
      sleep(250)
  except IOError:
    # A closed output pipe is a normal way for a terminal program to stop.
    discard
  finally:
    when declared(unsetControlCHook):
      unsetControlCHook()
    live.stopLive()
