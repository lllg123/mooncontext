# MoonContext

MoonContext is a deterministic context compiler for LLM and agent workflows,
implemented in MoonBit. Its native CLI can check, build, and explain context
files.

The draft v0.1 language and compiler behavior are specified in the design
documents below.

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
moon run cmd/main -- --help
moon run cmd/main check path/to/context.ctx --define language=MoonBit
moon run cmd/main build path/to/context.ctx -o context.md --source-map context.map.json --manifest context.manifest.json
moon run cmd/main explain path/to/context.ctx
```

The CLI exits with status 0 on success, 1 for checked context errors, and 2
for invalid invocations or inaccessible inputs/outputs.

## Verify

```text
moon fmt
moon check --deny-warn
moon test
moon info
```

## License

Apache-2.0
