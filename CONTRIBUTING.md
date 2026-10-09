# Contributing

Contributions are welcome through focused issues and pull requests.

## Development

Install `terminal_style` from its GitHub repository, or use a sibling
`terminal-style` workspace checkout, which is detected automatically. With
Nim 2.0.0 or newer, run from the package root:

```sh
nimble install https://github.com/titanomachy/terminal-style
```

Then run:

```sh
nimble check
nimble test
nimble examples
nimble docs
```

`nimble test` also runs release-mode rendering performance checks for modern,
ASCII, and borderless themes at 1,000, 2,000, 4,000, and 8,000 rows. The checks
use fixed cell text and medians of interleaved timing batches to catch quadratic
growth without relying on an absolute speed requirement. Run them directly with
`nim r -d:release --path:src tests/test_render_performance.nim`.

They also render a fixed 4,000-row table 200 times with modern and borderless
themes, comparing the first and last timing windows and checking that every
output is identical. This bounded check catches substantial accumulating
slowdown; it is not a long-running soak test.

Core rendering must stay deterministic, return strings, and measure ANSI and
Unicode content in terminal cells. Keep parsers and macros in optional modules.
New public behavior needs doc comments, validation and output tests, and a
finite example. Update the advanced-layout contract before changing span or
border-intersection semantics.

By contributing, you agree that your contribution is licensed under the MIT
license in `LICENSE`. Do not submit code whose license is unknown or
incompatible; record incorporated third-party material in
`THIRD_PARTY_NOTICES.md`.
