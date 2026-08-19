## Optional RFC-style CSV input adapter backed by Nim's standard library.
##
## Importing the main ``terminal_tables`` façade does not import a CSV parser.

import std/[parsecsv, streams]

import ../terminal_tables

export terminal_tables

proc tableFromParser(parser: var CsvParser; hasHeader: bool): Table =
  var rows: seq[seq[string]]
  while parser.readRow():
    rows.add parser.row
  if rows.len == 0:
    raise newException(ValueError, "CSV input does not contain any rows")

  let width = rows[0].len
  if width == 0:
    raise newException(ValueError, "CSV input does not contain any columns")
  for row in rows:
    if row.len != width:
      raise newException(ValueError, "CSV rows must all have the same number of fields")

  if hasHeader:
    result = initTable(rows[0])
    for index in 1 ..< rows.len:
      result.addRow(initRow(rows[index]))
  else:
    result = initTable(Positive(width))
    for row in rows:
      result.addRow(initRow(row))

proc tableFromCsv*(input: string; hasHeader = true; separator = ',';
                   quote = '"'; escape = '\0';
                   skipInitialSpace = false): Table =
  ## Parses CSV text into a table and validates that it is rectangular.
  ## Quoted separators, doubled quotes, and multiline fields are supported.
  let stream = newStringStream(input)
  var parser: CsvParser
  parser.open(stream, "<string>", separator, quote, escape, skipInitialSpace)
  try:
    result = tableFromParser(parser, hasHeader)
  finally:
    parser.close()
    stream.close()

proc tableFromCsvFile*(filename: string; hasHeader = true; separator = ',';
                       quote = '"'; escape = '\0';
                       skipInitialSpace = false): Table =
  ## Reads a CSV file into a table. File and CSV errors propagate to callers.
  var parser: CsvParser
  parser.open(filename, separator, quote, escape, skipInitialSpace)
  try:
    result = tableFromParser(parser, hasHeader)
  finally:
    parser.close()
