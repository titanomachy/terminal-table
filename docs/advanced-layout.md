# Advanced layout contract

This document defines the Phase 3 behavior before the implementation details.
It is part of the public contract of `terminal_tables`.

## Selectors

Selectors address cells, not rendered terminal lines. Body row indexes are
zero-based and never change when a title, header, panel, or footer is added.
`headerSelector` and `footerSelector` address those named sections explicitly.
A segment is an inclusive rectangular range of body cells. Predicate selectors
receive a `CellContext` containing the section, body row index (`-1` outside the
body), column index, and current cell value. Combining selectors produces their
set union; a cell is modified at most once.

## Panels and sections

A title and every panel occupy the complete inner width of the table. Top
panels render between the title and header; bottom panels render between the
body and footer. A footer has the same fixed column count as the header and
body. Panels do not change body row indexes or the column count.

## Spans

A span is an inclusive rectangular region anchored by its top-left cell.
`columnSpan` and `rowSpan` default to one. Spans cannot overlap, leave the table,
or cross a section boundary. Headers and footers can span horizontally but,
because each is one row, cannot span vertically. Covered cell values remain in
the model but are not rendered; clearing a span reveals them again.

The anchor inherits style, alignment, padding, and overflow settings normally.
Its usable width is all covered columns, their padding space, and the removed
internal separators, less the anchor's own padding. ANSI controls never consume
width. Wrapping and truncation happen only after this combined width is known.
For a vertical span, wrapped lines are aligned within the combined height of
the covered rows. A row grows when the span needs more lines.

Vertical rules inside a horizontal span and horizontal rules inside a vertical
span are omitted. The renderer keeps the span's outside boundary intact and
uses the active theme's normal intersection glyphs where unmerged regions meet.

## Responsive widths and transformations

Lower numeric width priorities shrink first; equal priorities retain the
left-to-right fairness of the core renderer. Fixed and minimum widths remain
hard constraints. Shadows and margins count toward `maxWidth`.

Transformations preserve cell values and cell styles. Geometric operations
transform span anchors and dimensions when this is unambiguous. Concatenation
preserves existing span geometry. Row editing rejects tables containing
vertical spans, and column editing rejects tables containing horizontal spans,
so an edit cannot ambiguously cut or duplicate a merged region. Callers may
clear the affected span first. Split results are independent table values.
