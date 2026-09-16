# MoonContext

MoonContext is a deterministic, verifiable context build tool for LLM and
agent workflows, implemented in MoonBit. It turns shared rules, variables,
local knowledge files, conditions, and character budgets into Markdown or
plain text that can be passed directly to a model. Its native CLI can check,
build, and explain every result before a model call is made.

## Why MoonContext

Copying Markdown by hand does not reliably represent imports, variables,
conditions, priorities, or budget decisions. YAML and JSON can store those
values, but every application must still invent the same evaluation rules;
long text and precise source diagnostics are also awkward. General-purpose
template engines often permit functions, environment access, or complex
expressions, which increases the security boundary and makes builds harder to
reproduce.

The `.ctx` format is intentionally small rather than a general-purpose
language. It has only the declarations needed for context construction and no
loops, arbitrary code execution, implicit environment access, or network
access. This restricted model lets MoonContext detect missing variables,
import cycles, malformed input, and unsafe paths before runtime; select whole
sections under a character budget without truncating required rules; and emit
source maps and manifests that explain where output came from. Identical
inputs and explicit definitions produce byte-identical artifacts suitable for
local development and CI.

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
