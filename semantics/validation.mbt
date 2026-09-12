///|
fn declaration_span(
  declaration : @syntax.DeclarationSyntax,
) -> @diagnostics.Span {
  match declaration {
    Context(value) => value.span
    Budget(value) => value.span
    Output(value) => value.span
    Let(value) => value.span
    Include(value) => value.span
    Section(value) => value.span
  }
}

///|
fn add_error(
  diagnostics : Array[@diagnostics.Diagnostic],
  code : String,
  message : String,
  span : @diagnostics.Span,
  labels? : Array[@diagnostics.Label] = [],
  help? : String,
) -> Unit {
  let diagnostic = match help {
    Some(value) =>
      @diagnostics.Diagnostic::new(
        @diagnostics.Severity::Error,
        code~,
        message~,
        primary=span,
        labels~,
        help=value,
      )
    None =>
      @diagnostics.Diagnostic::new(
        @diagnostics.Severity::Error,
        code~,
        message~,
        primary=span,
        labels~,
      )
  }
  diagnostics.push(diagnostic)
}

///|
fn first_span(
  source : @diagnostics.SourceId,
  document : @syntax.DocumentSyntax,
) -> @diagnostics.Span {
  match document.declarations.get(0) {
    Some(declaration) => declaration_span(declaration)
    None => @diagnostics.Span::new(source, start=0, end=0)
  }
}

///|
fn record_unique_name(
  diagnostics : Array[@diagnostics.Diagnostic],
  seen : Map[String, @diagnostics.Span],
  category : String,
  name : String,
  span : @diagnostics.Span,
) -> Unit {
  if seen.contains(name) {
    add_error(
      diagnostics,
      "E4001",
      "duplicate \{category} name `\{name}`",
      span,
      labels=[@diagnostics.Label::new(seen[name], "first declared here")],
      help="rename one of the \{category}s",
    )
  } else {
    seen[name] = span
  }
}

///|
fn parse_integer(digits : String) -> Int? {
  try @string.parse_int(digits) catch {
    _ => None
  } noraise {
    value => Some(value)
  }
}

///|
fn is_identifier_start(ch : Char) -> Bool {
  ch == '_' || (ch >= 'a' && ch <= 'z') || (ch >= 'A' && ch <= 'Z')
}

///|
fn is_identifier_continue(ch : Char) -> Bool {
  is_identifier_start(ch) || (ch >= '0' && ch <= '9')
}

///|
fn interpolation_references(value : String) -> Array[String] {
  let chars = [ for ch in value => ch ]
  let references : Array[String] = []
  let mut current = 0
  while current + 1 < chars.length() {
    if chars[current] == '$' &&
      chars[current + 1] == '$' &&
      current + 2 < chars.length() &&
      chars[current + 2] == '{' {
      current += 3
      continue
    }
    if chars[current] != '$' || chars[current + 1] != '{' {
      current += 1
      continue
    }
    let start = current + 2
    let mut end = start
    while end < chars.length() && chars[end] != '}' {
      end += 1
    }
    if end < chars.length() && end > start && is_identifier_start(chars[start]) {
      let mut valid = true
      for index in (start + 1)..<end {
        if !is_identifier_continue(chars[index]) {
          valid = false
        }
      }
      if valid {
        let name = StringBuilder()
        for index in start..<end {
          name.write_char(chars[index])
        }
        references.push(name.to_string())
      }
    }
    current = if end < chars.length() { end + 1 } else { chars.length() }
  }
  references
}

///|
fn validate_reference(
  diagnostics : Array[@diagnostics.Diagnostic],
  variables : Map[String, @diagnostics.Span],
  name : String,
  span : @diagnostics.Span,
) -> Unit {
  if !variables.contains(name) {
    add_error(
      diagnostics,
      "E4002",
      "undefined variable `\{name}`",
      span,
      help="declare it with `let \{name} = \"...\";`",
    )
  }
}

///|
fn validate_section(
  diagnostics : Array[@diagnostics.Diagnostic],
  variables : Map[String, @diagnostics.Span],
  sections : Map[String, @diagnostics.Span],
  section : @syntax.SectionDecl,
) -> Unit {
  record_unique_name(
    diagnostics,
    sections,
    "section",
    section.name.value,
    section.name.span,
  )
  if section.name.value == "" {
    add_error(
      diagnostics,
      "E4007",
      "section name must not be empty",
      section.name.span,
    )
  }
  let modifiers : Map[String, @diagnostics.Span] = Map([])
  for modifier in section.modifiers {
    let (name, span) = match modifier {
      Priority(amount, span) => {
        match parse_integer(amount.digits) {
          Some(value) if value >= 0 && value <= 100 => ()
          _ =>
            add_error(
              diagnostics,
              "E4003",
              "priority must be between 0 and 100",
              amount.span,
            )
        }
        ("priority", span)
      }
      Required(span) => ("required", span)
      When(condition) => {
        validate_reference(
          diagnostics,
          variables,
          condition.variable.value,
          condition.variable.span,
        )
        ("when", condition.span)
      }
    }
    if modifiers.contains(name) {
      add_error(
        diagnostics,
        "E4007",
        "section modifier `\{name}` may appear only once",
        span,
        labels=[
          @diagnostics.Label::new(
            modifiers[name],
            "first modifier appears here",
          ),
        ],
      )
    } else {
      modifiers[name] = span
    }
  }
  if section.contents.length() != 1 {
    add_error(
      diagnostics,
      "E4005",
      "section must contain exactly one text or file declaration",
      section.span,
    )
  }
  for content in section.contents {
    match content {
      Text(value, _) =>
        for name in interpolation_references(value.value) {
          validate_reference(diagnostics, variables, name, value.span)
        }
      File(_, _) => ()
    }
  }
}

///|
fn count_root_declarations(
  document : @syntax.DocumentSyntax,
) -> (Int, Int, Int) {
  for
    declaration in document.declarations
    context_count = 0, budget_count = 0, output_count = 0 {
    match declaration {
      Context(_) => continue context_count + 1, budget_count, output_count
      Budget(_) => continue context_count, budget_count + 1, output_count
      Output(_) => continue context_count, budget_count, output_count + 1
      _ => continue context_count, budget_count, output_count
    }
  } nobreak {
    (context_count, budget_count, output_count)
  }
}

///|
fn validate_root_shape(
  diagnostics : Array[@diagnostics.Diagnostic],
  source : @diagnostics.SourceId,
  document : @syntax.DocumentSyntax,
  kind : SourceKind,
) -> Unit {
  let (contexts, budgets, outputs) = count_root_declarations(document)
  let anchor = first_span(source, document)
  match kind {
    Root => {
      if contexts == 0 {
        add_error(
          diagnostics, "E4004", "root file is missing `context`", anchor,
        )
      }
      if budgets == 0 {
        add_error(diagnostics, "E4004", "root file is missing `budget`", anchor)
      }
      if outputs == 0 {
        add_error(diagnostics, "E4004", "root file is missing `output`", anchor)
      }
      match document.declarations.get(0) {
        Some(Context(_)) => ()
        Some(declaration) =>
          add_error(
            diagnostics,
            "E4004",
            "`context` must be the first declaration in a root file",
            declaration_span(declaration),
          )
        None => ()
      }
    }
    Included =>
      if contexts + budgets + outputs > 0 {
        for declaration in document.declarations {
          match declaration {
            Context(_) | Budget(_) | Output(_) =>
              add_error(
                diagnostics,
                "E4004",
                "included files cannot declare root configuration",
                declaration_span(declaration),
              )
            _ => ()
          }
        }
      }
  }
}

///|
/// Validate declaration names, root attributes, section rules, and variable
/// references in one parsed source file.
///
/// ```mbt check
/// test {
///   let source = @diagnostics.SourceId::{ value: 0, }
///   let parsed = @syntax.parse(
///     source, "context \"demo\"; budget chars = 10; output text; section \"body\" { text = \"ok\"; }",
///   )
///   let result = validate(source, parsed.document, Root)
///   assert_eq(result.diagnostics.length(), 0)
/// }
/// ```
pub fn validate(
  source : @diagnostics.SourceId,
  document : @syntax.DocumentSyntax,
  kind : SourceKind,
) -> ValidationResult {
  let diagnostics : Array[@diagnostics.Diagnostic] = []
  validate_root_shape(diagnostics, source, document, kind)
  let variables : Map[String, @diagnostics.Span] = Map([])
  for declaration in document.declarations {
    match declaration {
      Let(value) =>
        if !variables.contains(value.name.value) {
          variables[value.name.value] = value.name.span
        }
      _ => ()
    }
  }
  let seen_variables : Map[String, @diagnostics.Span] = Map([])
  let seen_sections : Map[String, @diagnostics.Span] = Map([])
  let mut context_seen = false
  let mut budget_seen = false
  let mut output_seen = false
  for declaration in document.declarations {
    match declaration {
      Context(value) => {
        if context_seen {
          add_error(
            diagnostics,
            "E4004",
            "root configuration `context` may appear only once",
            value.span,
          )
        }
        context_seen = true
        if value.name.value == "" {
          add_error(
            diagnostics,
            "E4007",
            "context name must not be empty",
            value.name.span,
          )
        }
      }
      Budget(value) => {
        if budget_seen {
          add_error(
            diagnostics,
            "E4004",
            "root configuration `budget` may appear only once",
            value.span,
          )
        }
        budget_seen = true
        if value.unit.value != "chars" {
          add_error(
            diagnostics,
            "E4007",
            "unsupported budget unit `\{value.unit.value}`",
            value.unit.span,
            help="use `budget chars = N;`",
          )
        }
        match parse_integer(value.amount.digits) {
          Some(amount) if amount > 0 => ()
          _ =>
            add_error(
              diagnostics,
              "E4006",
              "budget must be a positive supported integer",
              value.amount.span,
            )
        }
      }
      Output(value) => {
        if output_seen {
          add_error(
            diagnostics,
            "E4004",
            "root configuration `output` may appear only once",
            value.span,
          )
        }
        output_seen = true
        if value.format.value != "markdown" && value.format.value != "text" {
          add_error(
            diagnostics,
            "E4007",
            "unsupported output format `\{value.format.value}`",
            value.format.span,
            help="use `markdown` or `text`",
          )
        }
      }
      Let(value) =>
        record_unique_name(
          diagnostics,
          seen_variables,
          "variable",
          value.name.value,
          value.name.span,
        )
      Section(value) =>
        validate_section(diagnostics, variables, seen_sections, value)
      Include(_) => ()
    }
  }
  { diagnostics, }
}
