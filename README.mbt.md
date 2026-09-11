# MoonContext

MoonContext is a deterministic context compiler for LLM and agent workflows,
implemented in MoonBit. The project is being developed as a sequence of small,
tested compiler stages.

The first milestone provides a buildable library, a runnable CLI, and a
black-box smoke test. The context language and compilation pipeline will be
defined in the next milestone.

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
