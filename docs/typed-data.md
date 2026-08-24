# Typed data and parser adapters

Phase 4 features live in optional modules. `import terminal_table` remains a
small rendering and model façade and does not load Nim's macro, CSV, or JSON
modules.

## Object collections

Import `terminal_table/typed_data` and call `tableFromObjects` with a `seq` or
`array` of one non-variant object type.

```nim
type Build = object
  internalId: int
  name: string
  durationMs: int

proc seconds(value: int): string =
  $(value div 1000) & "s"

let table = tableFromObjects(builds,
  tableColumn(name, "Build"),
  tableColumn(durationMs, "Duration", seconds))
```

The contract is deliberately explicit:

- With no column specifications, fields use declaration order and field names
  become headers.
- When specifications are present, they are the exact column selection and
  order. Omission is how a field is hidden.
- The second argument renames the header and must be a string literal.
- The third argument is a callable with the compile-time checked signature
  `proc(value: FieldType): string`.
- Unknown and duplicate fields are compile-time errors.
- The collection expression is evaluated once. Empty collections still retain
  their statically known headers.
- Variant objects are rejected because reading inactive branches is unsafe.

This is a macro rather than runtime reflection, so generated row access is
ordinary typed Nim code and adds no reflection metadata or per-cell dispatch.

## CSV

Import `terminal_table/csv_adapter`. `tableFromCsv` accepts text and
`tableFromCsvFile` accepts a filename. Both support configurable separator,
quote, escape, and initial-space handling. Quoted newlines and separators are
handled by Nim's standard `parsecsv` module. Ragged and empty input raises
`ValueError`; parser and file errors propagate.

Set `hasHeader = false` for a headerless table.

## JSON records

Import `terminal_table/json_adapter`. `tableFromJson` accepts JSON text or a
`JsonNode`. Input must be an array of objects. Without an explicit `columns`
list, the adapter computes the stable union of keys in first-seen order.

Missing keys and JSON nulls can be distinguished with `missingValue` and
`nullValue`. Strings are unquoted, scalar values use their normal text, and
nested arrays/objects retain compact JSON syntax. An empty array needs explicit
columns because no schema can be inferred.

## Other output formats

Markdown and HTML output renderers are intentionally deferred. The current
`markdownTheme` is a terminal/plain-text layout, while a semantic exporter
must define lossless behavior for row/column spans, panels, ANSI hyperlinks,
alignment, and multiline cells. Those rules should be designed as an output
adapter contract rather than silently discarding advanced table semantics.

