# MoonContext

MoonContext is a deterministic context compiler for LLM and agent workflows,
implemented in MoonBit. Its native CLI can check, build, and explain context
files.

## Documentation

- [Context language](docs/context-language.md)
- [Compiler pipeline](docs/compiler-pipeline.md)
- [Diagnostics](docs/diagnostics.md)
- [Runnable examples](docs/examples.md)
- [Release process](docs/releasing.md)

## Requirements

- MoonBit toolchain; install it using the [official instructions](https://docs.moonbitlang.com/en/stable/tutorial/tour.html#installation).
- Network access for `moon update` on a fresh checkout.

## Fresh checkout

Run from the repository root:

```text
moon update
moon fmt --check
moon check --deny-warn
moon test
```

Run a packaged example:

```text
moon run cmd/main -- --help
moon run cmd/main -- check examples/agent/context.ctx
moon run cmd/main -- build examples/code-review/context.ctx -o _build/code-review.txt
moon run cmd/main -- explain examples/knowledge-base/context.ctx
```

The CLI exits with status 0 on success, 1 for checked context errors, and 2
for invalid invocations or inaccessible inputs/outputs.

See [all examples and expected behavior](docs/examples.md) for the three
complete input trees and additional build commands.

GitHub Actions runs formatting, type checks, the complete test suite, and CLI
smoke checks for all examples on pushes and pull requests.

## License

Apache-2.0
