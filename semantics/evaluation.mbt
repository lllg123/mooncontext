///|
fn build_environment(
  document : @syntax.DocumentSyntax,
  definitions : Array[Definition],
) -> Map[String, String] {
  let environment : Map[String, String] = Map([])
  for declaration in document.declarations {
    match declaration {
      Let(value) =>
        if !environment.contains(value.name.value) {
          environment[value.name.value] = value.value.value
        }
      _ => ()
    }
  }
  for definition in definitions {
    environment[definition.name] = definition.value
  }
  environment
}

///|
fn write_range(
  output : StringBuilder,
  chars : Array[Char],
  start : Int,
  end : Int,
) -> Unit {
  for index in start..<end {
    output.write_char(chars[index])
  }
}

///|
fn interpolate_text(
  value : @syntax.StringSyntax,
  environment : Map[String, String],
  diagnostics : Array[@diagnostics.Diagnostic],
) -> String {
  let chars = [ for ch in value.value => ch ]
  let output = StringBuilder()
  let mut current = 0
  while current < chars.length() {
    if chars[current] != '$' || current + 1 >= chars.length() {
      output.write_char(chars[current])
      current += 1
      continue
    }
    if chars[current + 1] == '$' &&
      current + 2 < chars.length() &&
      chars[current + 2] == '{' {
      output.write_string("${")
      current += 3
      continue
    }
    if chars[current + 1] != '{' {
      output.write_char(chars[current])
      current += 1
      continue
    }
    let name_start = current + 2
    let mut name_end = name_start
    while name_end < chars.length() && chars[name_end] != '}' {
      name_end += 1
    }
    let mut valid = name_end < chars.length() &&
      name_end > name_start &&
      is_identifier_start(chars[name_start])
    if valid {
      for index in (name_start + 1)..<name_end {
        if !is_identifier_continue(chars[index]) {
          valid = false
        }
      }
    }
    if !valid {
      output.write_char(chars[current])
      current += 1
      continue
    }
    let name_builder = StringBuilder()
    write_range(name_builder, chars, name_start, name_end)
    let name = name_builder.to_string()
    if environment.contains(name) {
      output.write_string(environment[name])
    } else {
      add_error(
        diagnostics,
        "E4002",
        "undefined variable `\{name}`",
        value.span,
        help="declare it with `let \{name} = \"...\";` or provide an explicit definition",
      )
      write_range(output, chars, current, name_end + 1)
    }
    current = name_end + 1
  }
  output.to_string()
}

///|
fn condition_matches(
  condition : @syntax.ConditionSyntax,
  environment : Map[String, String],
  diagnostics : Array[@diagnostics.Diagnostic],
) -> Bool {
  let name = condition.variable.value
  if !environment.contains(name) {
    add_error(
      diagnostics,
      "E4002",
      "undefined variable `\{name}`",
      condition.variable.span,
      help="declare it with `let \{name} = \"...\";` or provide an explicit definition",
    )
    return false
  }
  let equal = environment[name] == condition.value.value
  match condition.operator {
    Equal => equal
    NotEqual => !equal
  }
}

///|
fn evaluate_section(
  section : @syntax.SectionDecl,
  environment : Map[String, String],
  diagnostics : Array[@diagnostics.Diagnostic],
) -> EvaluatedSection? {
  let mut active = true
  let mut priority = 50
  let mut required = false
  for modifier in section.modifiers {
    match modifier {
      Priority(amount, _) =>
        match parse_integer(amount.digits) {
          Some(value) => priority = value
          None => ()
        }
      Required(_) => required = true
      When(condition) => {
        let selected = condition_matches(condition, environment, diagnostics)
        active = active && selected
      }
    }
  }
  if !active {
    return None
  }
  match section.contents.get(0) {
    Some(Text(value, span)) =>
      Some({
        name: section.name.value,
        content: InlineText(
          interpolate_text(value, environment, diagnostics),
          span,
        ),
        priority,
        required,
        span: section.span,
      })
    Some(File(path, span)) =>
      Some({
        name: section.name.value,
        content: FileReference(path.value, span),
        priority,
        required,
        span: section.span,
      })
    None => None
  }
}

///|
/// Evaluate explicit definitions, section conditions, and inline variable
/// interpolation. Definitions override source `let` declarations.
///
/// ```mbt check
/// test {
///   let source = @diagnostics.SourceId::{ value: 0, }
///   let parsed = @syntax.parse(
///     source, "let mode = \"draft\"; section \"body\" when mode == \"review\" { text = \"${mode}\"; }",
///   )
///   let result = evaluate(parsed.document, [{ name: "mode", value: "review", }])
///   assert_eq(result.diagnostics.length(), 0)
///   assert_eq(result.sections.length(), 1)
/// }
/// ```
pub fn evaluate(
  document : @syntax.DocumentSyntax,
  definitions : Array[Definition],
) -> EvaluationResult {
  let environment = build_environment(document, definitions)
  let diagnostics : Array[@diagnostics.Diagnostic] = []
  let sections : Array[EvaluatedSection] = []
  for declaration in document.declarations {
    match declaration {
      Section(section) =>
        match evaluate_section(section, environment, diagnostics) {
          Some(value) => sections.push(value)
          None => ()
        }
      _ => ()
    }
  }
  { sections, diagnostics, }
}
