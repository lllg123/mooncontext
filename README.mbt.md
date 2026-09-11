# MoonContext

MoonContext is a deterministic context compiler for LLM and agent workflows,
implemented in MoonBit. The project is being developed as a sequence of small,
tested compiler stages.

The project currently provides a buildable library, a runnable CLI, and a
black-box smoke test. The draft v0.1 language and compiler behavior are now
specified; implementation of the compiler stages follows that contract.

## Design documents

- [Context language](docs/context-language.md)
- [Compiler pipeline](docs/compiler-pipeline.md)
- [Diagnostics](docs/diagnostics.md)
- [Design examples](docs/examples.md)

## Requirements

- MoonBit toolchain with support for the current `moon.mod` and `moon.pkg`
  formats

## Run

```text
moon run cmd/main
```

Expected output:

```text
MoonContext v0.1.0: compiler scaffold ready
```

## Verify

```text
moon fmt
moon check --deny-warn
moon test
moon info
```

## License

Apache-2.0
