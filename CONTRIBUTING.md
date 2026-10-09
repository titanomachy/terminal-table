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

`nimble test` also runs release-mode rendering performance checks. These compare
the cost of rendering 1,000 and 8,000 rows with and without row separators to
catch quadratic growth without relying on an absolute speed requirement.
They also render a fixed 4,000-row table 200 times with each theme, comparing
the first and last timing windows and checking that every output is identical.
This bounded check catches substantial accumulating slowdown; it is not a
long-running soak test.

Core rendering must stay deterministic, return strings, and measure ANSI and
Unicode content in terminal cells. Keep parsers and macros in optional modules.
New public behavior needs doc comments, validation and output tests, and a
finite example. Update the advanced-layout contract before changing span or
border-intersection semantics.

By contributing, you agree that your contribution is licensed under the MIT
license in `LICENSE`. Do not submit code whose license is unknown or
incompatible; record incorporated third-party material in
`THIRD_PARTY_NOTICES.md`.
