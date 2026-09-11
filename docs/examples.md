# Design examples

These examples define intended v0.1 behavior before the parser and renderer are
implemented. They are specification examples, not yet executable fixtures.

## 1. Support agent context

```ctx
context "support-agent";
budget chars = 1200;
output markdown;

let product = "MoonContext";
let tier = "pro";

section "role" priority = 100 required {
  text = """
You support ${product}. Give reproducible steps and state uncertainty clearly.
""";
}

section "pro-policy" priority = 70 when tier == "pro" {
  text = "Pro users may attach private build logs for diagnosis.";
}
```

Expected Markdown:

```markdown
## role

You support MoonContext. Give reproducible steps and state uncertainty clearly.

## pro-policy

Pro users may attach private build logs for diagnosis.
```

This scenario verifies interpolation, a true condition, required content, and
source-order rendering.

## 2. Code-review context with reusable policy

Root file `review.ctx`:

```ctx
context "code-review";
budget chars = 1800;
output text;

let language = "MoonBit";
include "shared/review-policy.ctx";

section "repository" priority = 60 {
  file = "notes/repository-summary.md";
}
```

Included file `shared/review-policy.ctx`:

```ctx
section "review-policy" priority = 100 required {
  text = "Review ${language} correctness and security before discussing style.";
}
```

With `notes/repository-summary.md` containing `The parser is incremental.`, the
expected text output is:

```text
Review MoonBit correctness and security before discussing style.

The parser is incremental.
```

This scenario verifies include expansion at declaration position, safe content
loading, cross-file interpolation, and plain-text rendering.

## 3. Budgeted local knowledge pack

```ctx
context "knowledge-pack";
budget chars = 110;
output text;

section "contract" priority = 100 required {
  text = "Answer only from the selected local notes.";
}

section "release" priority = 80 {
  text = "Release 0.1 introduces deterministic context compilation.";
}

section "history" priority = 20 {
  text = "The first prototype explored several unrelated output formats.";
}
```

The required section is selected first. The `release` section is considered
before `history`; if only `release` fits with renderer separators, `history` is
omitted atomically. The artifact keeps source order, while `explain` records:

```text
selected  contract  required
selected  release   priority=80
omitted   history   budget
```

This scenario verifies deterministic priority selection and an explicit
budget-omission reason. Exact character totals will become golden fixtures when
the renderer is implemented.

## Rejection examples

An undefined variable is a semantic error:

```ctx
context "invalid-variable";
budget chars = 100;
output text;

section "body" required {
  text = "Hello ${missing}.";
}
```

An unsafe path is a resolver error:

```ctx
context "invalid-path";
budget chars = 100;
output text;

include "../outside.ctx";
```

Neither input produces a successful artifact.
