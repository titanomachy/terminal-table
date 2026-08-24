import std/[json, os, sequtils, tempfiles, unittest]

import terminal_table/typed_data
import terminal_table/csv_adapter
import terminal_table/json_adapter

type
  Build = object
    internalId: int
    name: string
    durationMs: int
    passed: bool

proc seconds(value: int): string =
  $(value div 1000) & "s"

proc invalidFormatter(value: int): int = value

static:
  doAssert not compiles(block:
    let rows: seq[Build] = @[]
    discard tableFromObjects(rows, tableColumn(unknownField)))
  doAssert not compiles(block:
    let rows: seq[Build] = @[]
    discard tableFromObjects(rows,
      tableColumn(name), tableColumn(name)))
  doAssert not compiles(block:
    let rows: seq[Build] = @[]
    discard tableFromObjects(rows,
      tableColumn(durationMs, "Duration", invalidFormatter)))

suite "typed object conversion":
  test "discovers object fields in declaration order":
    let builds = @[Build(internalId: 7, name: "compiler",
      durationMs: 2400, passed: true)]
    let table = tableFromObjects(builds)
    check table.header.cells[0].text == "internalId"
    check table.header.cells[^1].text == "passed"
    check table.rows[0].cells.mapIt(it.text) ==
      @["7", "compiler", "2400", "true"]

  test "selects renames orders hides and formats fields":
    let builds = @[Build(internalId: 7, name: "compiler",
      durationMs: 2400, passed: true)]
    let table = tableFromObjects(builds,
      tableColumn(passed, "Result"),
      tableColumn(name, "Build"),
      tableColumn(durationMs, "Duration", seconds))
    check table.header.cells.mapIt(it.text) ==
      @["Result", "Build", "Duration"]
    check table.rows[0].cells.mapIt(it.text) ==
      @["true", "compiler", "2s"]

  test "preserves headers for empty collections and evaluates input once":
    var evaluations = 0
    proc records(): seq[Build] =
      inc evaluations
      @[]
    let table = tableFromObjects(records(), tableColumn(name, "Name"))
    check evaluations == 1
    check table.hasHeader
    check table.header.cells[0].text == "Name"
    check table.rows.len == 0

  test "accepts fixed-size object arrays":
    let builds = [
      Build(internalId: 1, name: "one", durationMs: 1000, passed: true),
      Build(internalId: 2, name: "two", durationMs: 2000, passed: false)
    ]
    let table = tableFromObjects(builds, tableColumn(name))
    check table.rows.mapIt(it.cells[0].text) == @["one", "two"]

suite "CSV adapter":
  test "parses headers quotes separators and multiline values":
    let table = tableFromCsv("Name,Notes\napi,\"fast, stable\"\nweb,\"two\nlines\"\n")
    check table.header.cells.mapIt(it.text) == @["Name", "Notes"]
    check table.rows.len == 2
    check table.cell(0, 1).text == "fast, stable"
    check table.cell(1, 1).text == "two\nlines"

  test "supports headerless data and custom separators":
    let table = tableFromCsv("a;b\n1;2", hasHeader = false,
      separator = ';')
    check not table.hasHeader
    check table.rows[0].cells.mapIt(it.text) == @["a", "b"]

  test "reads CSV files and closes their handles":
    let (file, path) = createTempFile("terminal_table_", ".csv")
    var fileIsOpen = true
    try:
      file.write("Key,Value\nlanguage,Nim")
      file.close()
      fileIsOpen = false
      let table = tableFromCsvFile(path)
      check table.cell(0, 1).text == "Nim"
    finally:
      if fileIsOpen:
        file.close()
      removeFile(path)

  test "rejects empty and ragged CSV":
    expect ValueError:
      discard tableFromCsv("")
    expect ValueError:
      discard tableFromCsv("a,b\n1")

suite "JSON adapter":
  test "infers a stable union of object keys":
    let table = tableFromJson("""[
      {"name":"api","healthy":true,"load":1.5},
      {"name":"worker","region":"eu","load":null}
    ]""", missingValue = "-", nullValue = "null")
    check table.header.cells.mapIt(it.text) ==
      @["name", "healthy", "load", "region"]
    check table.rows[0].cells.mapIt(it.text) ==
      @["api", "true", "1.5", "-"]
    check table.rows[1].cells.mapIt(it.text) ==
      @["worker", "-", "null", "eu"]

  test "supports explicit columns and a headerless table":
    let data = parseJson("""[{"x":1,"ignored":2}]""")
    let table = tableFromJson(data, ["missing", "x"],
      includeHeader = false, missingValue = "n/a")
    check not table.hasHeader
    check table.rows[0].cells.mapIt(it.text) == @["n/a", "1"]

  test "rejects invalid record shapes and ambiguous empty arrays":
    expect ValueError:
      discard tableFromJson("{}")
    expect ValueError:
      discard tableFromJson("[1, 2]")
    expect ValueError:
      discard tableFromJson("[]")
    check tableFromJson("[]", ["A"]).columnCount == 1
