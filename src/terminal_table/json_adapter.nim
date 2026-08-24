## Optional JSON-record input adapter backed by Nim's standard library.
##
## A JSON table is an array of objects. Columns can be supplied explicitly or
## inferred as the stable union of keys in first-seen order.

import std/json

import ../terminal_table

export terminal_table

proc jsonCellText(node: JsonNode; nullValue: string): string =
  case node.kind
  of JString:
    node.getStr
  of JInt:
    $node.getBiggestInt
  of JFloat:
    $node.getFloat
  of JBool:
    $node.getBool
  of JNull:
    nullValue
  of JObject, JArray:
    $node

proc tableFromJson*(data: JsonNode; columns: openArray[string] = [];
                    includeHeader = true; missingValue = "";
                    nullValue = ""): Table =
  ## Converts an array of JSON objects into a rectangular table.
  ##
  ## If ``columns`` is empty, keys are inferred across every object in stable
  ## first-seen order. Missing keys and JSON nulls use their configured text.
  if data.kind != JArray:
    raise newException(ValueError, "JSON table input must be an array of objects")

  var selected = @columns
  for item in data:
    if item.kind != JObject:
      raise newException(ValueError, "every JSON table row must be an object")
    if columns.len == 0:
      for key, _ in item:
        if key notin selected:
          selected.add key

  if selected.len == 0:
    raise newException(ValueError,
      "cannot infer columns from empty JSON input; supply columns explicitly")
  if includeHeader:
    result = initTable(selected)
  else:
    result = initTable(Positive(selected.len))

  for item in data:
    var values: seq[string]
    for key in selected:
      if item.hasKey(key):
        values.add jsonCellText(item[key], nullValue)
      else:
        values.add missingValue
    result.addRow(initRow(values))

proc tableFromJson*(input: string; columns: openArray[string] = [];
                    includeHeader = true; missingValue = "";
                    nullValue = ""): Table =
  ## Parses JSON text and delegates to the ``JsonNode`` overload.
  tableFromJson(parseJson(input), columns, includeHeader, missingValue,
    nullValue)
