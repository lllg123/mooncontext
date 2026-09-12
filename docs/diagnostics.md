# Diagnostic model

Diagnostics are part of the compiler's public behavior. They must be stable,
ordered, source-aware, and useful without exposing host-specific absolute paths.

## Structure

Each diagnostic contains:

| Field | Meaning |
| --- | --- |
| severity | `error` or `warning` |
| code | stable identifier such as `E2001` |
| message | concise description independent of source formatting |
| primary span | main source range responsible for the diagnostic |
| labels | optional related ranges and short explanations |
| help | optional actionable suggestion |

Errors prevent artifact emission. Warnings do not fail a build unless the
caller enables a planned `--deny-warn` option.

## Code families

| Range | Owner | Examples |
| --- | --- | --- |
| `E1xxx` | lexer | invalid character, malformed escape, unterminated string |
| `E2xxx` | parser | unexpected token, missing token, invalid declaration shape |
| `E3xxx` | resolver | missing file, import cycle, unsafe path, repeated include |
| `E4xxx` | semantic analysis | duplicate name, undefined variable, invalid modifier |
| `E5xxx` | budget planner | required content exceeds budget |
| `W6xxx` | lint and advisory checks | unused source variable |

Initial codes reserved by the v0.1 contract:

| Code | Meaning |
| --- | --- |
| `E1001` | unexpected character |
| `E1002` | unterminated quoted or triple-quoted string |
| `E1003` | invalid string escape or Unicode scalar |
| `E2001` | unexpected token |
| `E2002` | expected token or declaration is missing |
| `E2003` | invalid or repeated section modifier |
| `E3001` | included source or content file not found |
| `E3002` | include cycle detected |
| `E3003` | path is absolute or escapes the compilation root |
| `E3004` | normalized source file included more than once |
| `E4001` | duplicate section or variable name |
| `E4002` | undefined interpolation or condition variable |
| `E4003` | priority is outside `0..100` |
| `E4004` | missing, repeated, or misplaced root configuration |
| `E4005` | section does not contain exactly one content declaration |
| `E4006` | budget is zero or outside the supported integer range |
| `E4007` | declaration name or attribute is invalid |
| `E5001` | required rendered content exceeds the character budget |
| `W6001` | declared source variable is never referenced |

Codes are never reassigned to a different meaning. More specific codes may be
added inside a family without changing existing ones.

## Human rendering

```text
error[E4002]: undefined variable `audience`
  --> prompts/review.ctx:8:29
   |
 8 |   text = "Review this for ${audience}.";
   |                             ^^^^^^^^ not declared in this compilation
   |
   = help: add `let audience = "...";` or pass `--define audience=value`
```

Paths are relative to the compilation root and use `/`. Line and column values
are one-based. Spans use normalized source text, so the same file produces the
same location on Windows, macOS, and Linux.

When a problem involves multiple files, the primary span identifies the use
that failed and labels identify related declarations. An include-cycle error,
for example, labels every include edge in traversal order.

## Ordering and limits

Diagnostics are sorted by source discovery ordinal, span start, severity, and
code. Diagnostics without a usable span sort after diagnostics from the same
source. Stable ordering is required even if later compiler stages become
parallel.

After the configured diagnostic limit is reached, the compiler appends one
terminal message explaining that additional diagnostics were suppressed. The
compiler must not panic or emit a partial successful artifact.

## Machine-readable form

The manifest and future JSON diagnostic output use normalized paths, numeric
half-open offsets, one-based line and column values, and the same stable codes.
Human-readable snippets are presentation data and are not required for clients
that consume the structured fields.
