# Compiler pipeline

MoonContext is organized as a sequence of pure transformations around a small,
explicit file-loading boundary. Each stage owns one representation and must not
silently repair invalid input from an earlier stage.

```text
root path + definitions
          |
          v
source loading -> lexing -> parsing -> include resolution -> semantic analysis
                                                               |
                                                               v
artifact + map <- rendering <- budget planning <- context IR <- evaluation
```

## Stage contracts

| Stage | Input | Output | Required invariant |
| --- | --- | --- | --- |
| 1. Source loading | root path, compilation root | normalized source files | UTF-8, normalized `\n`, stable file IDs |
| 2. Lexing | one source file | tokens with spans | every token covers an exact source range |
| 3. Parsing | tokens | per-file syntax tree | malformed declarations produce diagnostics, not panics |
| 4. Include resolution | syntax trees | expanded declaration stream | safe paths, no duplicate files or cycles |
| 5. Semantic analysis | declarations | checked program | unique names, legal modifiers, resolved variables |
| 6. Evaluation | checked program, definitions | active interpolated sections | conditions resolved and values remain plain text |
| 7. IR lowering | active sections | canonical context IR | syntax details no longer affect downstream stages |
| 8. Budget planning | IR, renderer sizing rules | selection plan | deterministic, required content retained, limit respected |
| 9. Rendering | IR, selection plan | text artifact and source map | stable ordering and normalized final line break |
| 10. Manifest emission | all stage summaries | build manifest | records inputs, omissions, format, budget, and diagnostics |

Stages 1 and 4 may access the filesystem through an injected source provider.
All other stages operate only on owned data. Tests can therefore compile an
in-memory file graph without touching the host filesystem.

## Planned package boundaries

```text
lllg123/mooncontext
  public facade and compiler options

lllg123/mooncontext/diagnostics
  SourceId, Span, Diagnostic, labels and human rendering

lllg123/mooncontext/syntax
  tokens, lexer, syntax tree and parser

lllg123/mooncontext/resolver
  source provider, safe path resolution and include graph

lllg123/mooncontext/semantics
  symbol collection, validation, conditions and interpolation

lllg123/mooncontext/ir
  canonical sections, provenance and selection-plan types

lllg123/mooncontext/budget
  rendered-size accounting and stable greedy selection

lllg123/mooncontext/renderer
  Markdown, text, source-map and manifest emission

lllg123/mooncontext/cmd/main
  check, build and explain command routing
```

Public concrete types will be owned by the facade or a public package named by
users. Low-level scanners and path helpers may later move under `internal/`, but
internal types must not leak through the public interface.

## Core representations

These are conceptual contracts, not frozen MoonBit field names.

### Source layer

- `SourceId`: stable numeric identity assigned in first-discovery order
- `SourceFile`: normalized path, normalized text, and line-start index
- `Span`: source ID plus half-open character offsets `[start, end)`
- `Token`: token kind, source spelling where needed, and span

Offsets are measured in normalized source characters. Human diagnostics derive
one-based line and column values from the source table.

### Syntax layer

The syntax tree retains a span for every declaration, modifier, value, and
missing-token recovery point. String nodes retain both decoded value and source
span so interpolation errors can identify the original placeholder.

### Checked program

Semantic analysis produces:

- one root configuration
- a declaration-ordered section collection
- a variable table with declaration and override provenance
- normalized include and content-file references

No undefined names, duplicate names, invalid priorities, or invalid root-only
declarations survive this boundary.

### Context IR

The canonical IR contains only context identity, output format, character
budget, evaluated sections, source ordinals, priorities, required flags, and
provenance segments. It does not contain tokens, comments, include declarations,
or unevaluated expressions.

### Selection plan

The plan records selected section IDs, omitted section IDs with reasons,
required and optional character costs, total rendered character cost, and
remaining budget. Rendering consumes the plan without making new selection
decisions.

## Error recovery

The lexer emits an error token for an invalid character or malformed literal
and resumes at the next safe boundary. The parser synchronizes at `;`, `}`, or a
top-level declaration keyword. A recovered syntax tree is used only to find
additional diagnostics; semantic analysis and artifact emission do not proceed
when an error exists.

The default diagnostic limit will prevent adversarial input from generating
unbounded errors. Hitting the limit adds one terminal diagnostic and stops
recovery cleanly.

## Determinism contract

For identical normalized input files, compiler definitions, compiler version,
and options, MoonContext must produce byte-identical artifacts, source maps,
manifests, diagnostics, and `explain` output.

To preserve this contract:

- file IDs use first-discovery order, never filesystem enumeration order;
- maps are serialized using explicit sorted keys;
- equal-priority sections use their source ordinal;
- paths in user-visible output use normalized forward slashes;
- timestamps, absolute host paths, random IDs, and locale-sensitive formatting
  are excluded from build artifacts;
- line endings are always `\n` and non-empty artifacts end in one line break.

## Compiler outcomes

A compilation returns one of three conceptual outcomes:

- success with artifact, source map, manifest, and non-fatal warnings;
- checked failure with ordered diagnostics and no successful artifact;
- invocation failure for invalid CLI options or an inaccessible root input.

The planned CLI maps these outcomes to exit codes `0`, `1`, and `2`
respectively. Library callers receive structured outcomes rather than process
exit codes.

## Verification strategy

Every compiler stage will receive:

- focused unit tests for its local invariants;
- black-box tests for public behavior;
- malformed-input tests that must return diagnostics instead of panicking;
- golden tests for stable diagnostics and rendered artifacts;
- cross-target checks for pure packages where supported;
- end-to-end tests using an in-memory source provider.

Milestone validation remains `moon fmt`, `moon check --deny-warn`, `moon test`,
`moon build`, and `moon info` with review of generated interfaces.
