## Optional compile-time conversion from homogeneous object collections.
##
## This module is deliberately not exported by the ``terminal_tables``
## façade. Import it when object reflection is useful:
##
## .. code-block:: nim
##
##   import terminal_tables/typed_data
##
##   let table = tableFromObjects(records,
##     tableColumn(name, "Name"),
##     tableColumn(score, "Score", formatScore))
##
## Column specifications select and order fields. An omitted field is hidden.
## A formatter must have the signature ``proc(value: FieldType): string``.

import std/macros

import ../terminal_tables

export terminal_tables

type
  ColumnSpec = object
    fieldName: string
    header: string
    formatter: NimNode

proc collectionElementType(collectionType: NimNode): NimNode =
  if collectionType.kind != nnkBracketExpr or collectionType.len < 2:
    error("tableFromObjects expects a seq or array of objects")
  let collectionName = collectionType[0].strVal
  case collectionName
  of "seq", "openArray":
    result = collectionType[1]
  of "array":
    result = collectionType[^1]
  else:
    error("tableFromObjects expects a seq or array of objects")

proc collectObjectFields(objectType: NimNode): seq[string] =
  let implementation = objectType.getTypeImpl
  if implementation.kind != nnkObjectTy:
    error("tableFromObjects collection elements must be objects")

  proc visit(record: NimNode; fields: var seq[string]) =
    case record.kind
    of nnkRecList:
      for child in record:
        visit(child, fields)
    of nnkIdentDefs:
      for index in 0 ..< record.len - 2:
        var name = record[index]
        if name.kind == nnkPragmaExpr:
          name = name[0]
        if name.kind == nnkPostfix:
          name = name[1]
        fields.add name.strVal
    of nnkRecCase:
      error("variant object fields require explicit normalization before table conversion")
    of nnkNilLit, nnkEmpty:
      discard
    else:
      discard

  # Inherited fields precede fields declared by the derived object.
  if implementation[1].kind == nnkOfInherit:
    result.add collectObjectFields(implementation[1][0])
  visit(implementation[2], result)

proc parseColumnSpec(node: NimNode; available: seq[string]): ColumnSpec =
  if node.kind notin {nnkCall, nnkCommand} or node.len < 2 or
      node[0].strVal != "tableColumn":
    error("expected tableColumn(field[, header[, formatter]])", node)
  if node.len > 4:
    error("tableColumn accepts a field, optional header, and optional formatter", node)
  if node[1].kind notin {nnkIdent, nnkSym}:
    error("tableColumn field must be an identifier", node[1])

  result.fieldName = node[1].strVal
  if result.fieldName notin available:
    error("unknown object field '" & result.fieldName & "'", node[1])
  result.header = result.fieldName
  if node.len >= 3:
    if node[2].kind notin {nnkStrLit .. nnkTripleStrLit}:
      error("tableColumn header must be a string literal", node[2])
    result.header = node[2].strVal
  if node.len == 4:
    result.formatter = node[3]

macro tableFromObjects*(records: typed;
                        columns: varargs[untyped]): untyped =
  ## Converts a sequence or array of objects into a table.
  ##
  ## With no ``tableColumn`` specifications, every field is included in
  ## declaration order and its field name becomes the header. Otherwise the
  ## specifications are the exact selected order. Omit a field to hide it.
  ## The source expression is evaluated exactly once.
  let elementType = collectionElementType(records.getTypeInst)
  let fields = collectObjectFields(elementType)
  if fields.len == 0:
    error("tableFromObjects cannot convert an object without fields", records)

  var specs: seq[ColumnSpec]
  if columns.len == 0:
    for field in fields:
      specs.add ColumnSpec(fieldName: field, header: field)
  else:
    for column in columns:
      let spec = parseColumnSpec(column, fields)
      for previous in specs:
        if previous.fieldName == spec.fieldName:
          error("object field '" & spec.fieldName & "' is selected more than once", column)
      specs.add spec

  let sourceSymbol = genSym(nskLet, "objectRows")
  let rowSymbol = genSym(nskForVar, "objectRow")
  let tableSymbol = genSym(nskVar, "objectTable")
  var headers = nnkBracket.newTree()
  var values = nnkBracket.newTree()
  for spec in specs:
    headers.add newLit(spec.header)
    let access = newDotExpr(rowSymbol, ident(spec.fieldName))
    if spec.formatter.isNil:
      values.add newCall(bindSym"$", access)
    else:
      values.add newCall(spec.formatter, access)

  result = quote do:
    block:
      let `sourceSymbol` = `records`
      var `tableSymbol` = initTable(`headers`)
      for `rowSymbol` in `sourceSymbol`:
        `tableSymbol`.addRow(initRow(`values`))
      `tableSymbol`
