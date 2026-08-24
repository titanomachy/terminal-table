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

Core rendering must stay deterministic, return strings, and measure ANSI and
Unicode content in terminal cells. Keep parsers and macros in optional modules.
New public behavior needs doc comments, validation and output tests, and a
finite example. Update the advanced-layout contract before changing span or
border-intersection semantics.

By contributing, you agree that your contribution is licensed under the MIT
license in `LICENSE`. Do not submit code whose license is unknown or
incompatible; record incorporated third-party material in
`THIRD_PARTY_NOTICES.md`.
