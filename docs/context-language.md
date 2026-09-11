# MoonContext language draft v0.1

Status: implementation contract for the first usable compiler. Later changes
that break accepted source files require a language-version decision.

MoonContext source files use the `.ctx` extension. A root file describes one
compiled context. Included files contribute reusable variables, imports, and
sections. The language is deliberately declarative: it cannot execute commands,
read environment variables implicitly, access the network, or mutate files.

## Complete example

```ctx
context "code-review";
budget chars = 2400;
output markdown;

let language = "MoonBit";
let mode = "review";

include "shared/safety.ctx";

section "instructions" priority = 100 required {
  text = """
Review the supplied ${language} code. Report correctness issues before style.
""";
}

section "repository" priority = 70 when mode == "review" {
  file = "notes/repository.md";
}
```

The root file must declare `context`, `budget`, and `output` exactly once.
Included files must not declare those three root settings.

## Lexical rules

- Source files and referenced content files are UTF-8.
- Keywords are ASCII and case-sensitive.
- Identifiers match `[A-Za-z_][A-Za-z0-9_]*`.
- Integers are unsigned decimal values.
- `//` starts a comment that ends at the next line break.
- Whitespace is insignificant outside strings.
- Each declaration ends with `;`, except a `section` block.
- Line endings are normalized to `\n` before spans, interpolation, budgeting,
  and rendering are calculated.

A quoted string uses `"..."` and supports `\\`, `\"`, `\n`, `\r`, `\t`, and
`\u{HEX}` escapes. A triple-quoted string starts and ends with `"""`, preserves
interior line breaks after normalization, and has no character escapes. The
first line break after the opening delimiter and the last line break before the
closing delimiter are structural and are not part of the value.

Text interpolation uses `${name}` in `text` values and in the contents loaded
by `file`. A literal `${` is written as `$${`. Interpolation is not performed
in context names, section names, import paths, or file paths.

## Grammar

The following EBNF is normative for v0.1. `STRING` includes quoted and
triple-quoted strings; `IDENT` and `INT` follow the lexical rules above.

```ebnf
root_file       = context_decl, root_decl* ;
included_file   = shared_decl* ;

root_decl       = budget_decl | output_decl | shared_decl ;
shared_decl     = let_decl | include_decl | section_decl ;

context_decl    = "context", STRING, ";" ;
budget_decl     = "budget", "chars", "=", INT, ";" ;
output_decl     = "output", ("markdown" | "text"), ";" ;
let_decl        = "let", IDENT, "=", STRING, ";" ;
include_decl    = "include", STRING, ";" ;

section_decl    = "section", STRING, section_modifier*,
                  "{", content_decl, "}" ;
section_modifier = priority_modifier | "required" | when_modifier ;
priority_modifier = "priority", "=", INT ;
when_modifier   = "when", IDENT, ("==" | "!="), STRING ;
content_decl    = ("text", "=", STRING, ";")
                | ("file", "=", STRING, ";") ;
```

Modifiers may appear in any order, but each modifier may appear at most once.
A section contains exactly one `text` or `file` declaration. Nested sections
and arbitrary properties are not part of v0.1.

## Declarations and values

### Context

`context` gives the build a human-readable identity. It must be the first
non-comment declaration in the root file and its value must not be empty.

### Budget

`budget chars = N;` sets the maximum number of Unicode scalar values in the
final rendered output. `N` must be greater than zero. Renderer-added headings,
separators, and line breaks count toward the same limit.

The `chars` unit is intentionally independent of a model tokenizer. Token-aware
budgets can be introduced later without changing the meaning of v0.1 files.

### Output

`output markdown;` emits second-level headings for selected sections.
`output text;` emits section bodies separated by one blank line. Both renderers
end non-empty output with exactly one line break.

### Variables

`let name = "value";` declares a string variable in the resolved compilation
unit. Variable declarations are order-independent and names must be unique
across the root file and all included files.

An explicit compiler definition, planned as `--define name=value`, overrides a
source declaration of the same name. A referenced name with neither a source
declaration nor an explicit definition is an error. Values are substituted as
text and are never interpreted as source code.

### Includes

`include "shared/base.ctx";` expands declarations from another `.ctx` file at
the position of the include. Paths are resolved relative to the containing
source file and then normalized against the compilation root.

Absolute paths, paths escaping the compilation root, repeated inclusion of the
same normalized file, and import cycles are errors. The compiler does not
follow a path merely because its textual spelling differs after normalization.

### Sections

A section is the atomic unit of context selection.

- Names must be non-empty and unique after includes are expanded.
- `priority` ranges from 0 through 100 and defaults to 50.
- `required` prevents budget-based omission.
- `when name == "value"` and `when name != "value"` are the only v0.1
  conditions.
- `text` supplies inline content; `file` loads UTF-8 content from a safe relative
  path using the same path boundary as includes.

Conditions are evaluated before budgeting. A false condition removes the
section from consideration. Interpolation happens after conditions and before
rendered size is measured.

## Selection and ordering

Compilation uses this deterministic algorithm:

1. Resolve includes depth-first at their declaration position and assign every
   section a monotonically increasing source ordinal.
2. Evaluate conditions and discard false sections.
3. Render all required sections in source-ordinal order. If they exceed the
   budget, fail without producing a successful artifact.
4. Consider optional sections by descending priority and then ascending source
   ordinal. Add a section only if the entire rendered result still fits.
5. Render selected sections in source-ordinal order, regardless of the order in
   which optional sections were selected.

Sections are atomic in v0.1: the compiler never truncates a section to make it
fit. `explain` output will record every condition or budget omission.

## File and evaluation safety

The compilation root is the directory containing the root `.ctx` file unless a
caller explicitly supplies another enclosing directory. The root file itself,
every include, and every content path must remain inside it after canonical
normalization. Network URLs, device paths, shell expansion, environment
expansion, and symbolic-link escapes are rejected.

Compilation has configurable limits for source size, include depth, file count,
and diagnostic count. Concrete defaults belong to the CLI design and may change
without changing the language grammar.

## Non-goals for v0.1

- Expressions beyond one string equality or inequality
- Arithmetic, loops, user-defined functions, or macros
- Remote includes and implicit environment access
- Partial section truncation
- Model-specific tokenization
- JSON, YAML, or TOML as alternate source syntaxes
