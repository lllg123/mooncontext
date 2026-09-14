# Runnable examples

The examples below are checked by CI from a clean checkout. Run commands from
the repository root after installing MoonBit and running `moon update`.

## Support agent

Files: [context.ctx](../examples/agent/context.ctx).

```sh
moon run cmd/main -- check examples/agent/context.ctx
moon run cmd/main -- build examples/agent/context.ctx -o _build/agent.md
```

This example interpolates the product name, selects guidance using an explicit
variable condition, and renders required Markdown.

## Code review

Files: [root context](../examples/code-review/context.ctx),
[included policy](../examples/code-review/shared/review-policy.ctx), and
[repository notes](../examples/code-review/notes/repository-summary.md).

```sh
moon run cmd/main -- check examples/code-review/context.ctx
moon run cmd/main -- build examples/code-review/context.ctx -o _build/code-review.txt
```

The build expands an include, loads a safe relative content file, interpolates
the declared language, and emits plain text.

## Local knowledge base

Files: [context.ctx](../examples/knowledge-base/context.ctx).

```sh
moon run cmd/main -- explain examples/knowledge-base/context.ctx
moon run cmd/main -- build examples/knowledge-base/context.ctx -o _build/knowledge-base.txt
```

The required contract is retained, higher-priority notes are selected first,
and the low-priority history section is omitted as one unit when it exceeds the
character budget. `explain` reports the selection and omission reason.

## Complete fresh-checkout verification

```sh
moon update
moon fmt --check
moon check --deny-warn
moon test
moon run cmd/main -- check examples/agent/context.ctx
moon run cmd/main -- check examples/code-review/context.ctx
moon run cmd/main -- check examples/knowledge-base/context.ctx
```

See [the release guide](releasing.md) for the CI toolchain pin and release
checklist.
