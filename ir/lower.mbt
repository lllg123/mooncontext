///|
fn parse_positive_integer(digits : String) -> Int? {
  try @string.parse_int(digits) catch {
    _ => None
  } noraise {
    value => if value > 0 { Some(value) } else { None }
  }
}

///|
fn extract_configuration(
  document : @syntax.DocumentSyntax,
) -> (String, Int, OutputFormat)? {
  let mut identity : String? = None
  let mut char_budget : Int? = None
  let mut output : OutputFormat? = None
  for declaration in document.declarations {
    match declaration {
      Context(value) => {
        if identity is Some(_) || value.name.value == "" {
          return None
        }
        identity = Some(value.name.value)
      }
      Budget(value) => {
        if char_budget is Some(_) || value.unit.value != "chars" {
          return None
        }
        char_budget = parse_positive_integer(value.amount.digits)
        if char_budget is None {
          return None
        }
      }
      Output(value) => {
        if output is Some(_) {
          return None
        }
        output = match value.format.value {
          "markdown" => Some(Markdown)
          "text" => Some(PlainText)
          _ => None
        }
        if output is None {
          return None
        }
      }
      _ => ()
    }
  }
  guard identity is Some(identity) else { return None }
  guard char_budget is Some(char_budget) else { return None }
  guard output is Some(output) else { return None }
  Some((identity, char_budget, output))
}

///|
fn character_length(value : String) -> Int {
  let mut length = 0
  for _ in value {
    length += 1
  }
  length
}

///|
fn section_ordinal(
  document : @syntax.DocumentSyntax,
  target : @diagnostics.Span,
) -> Int? {
  let mut ordinal = 0
  for declaration in document.declarations {
    match declaration {
      Section(section) => {
        if section.span == target {
          return Some(ordinal)
        }
        ordinal += 1
      }
      _ => ()
    }
  }
  None
}

///|
fn lower_content(
  content : @semantics.EvaluatedContent,
) -> (Content, ProvenanceSegment) {
  let (canonical, value, source) = match content {
    InlineText(value, source) => (Inline(value), value, source)
    FileReference(value, source) => (File(value), value, source)
  }
  (
    canonical,
    { content_start: 0, content_end: character_length(value), source, },
  )
}

///|
/// Lower a validated, evaluated document into the canonical context IR.
///
/// Returns `None` when evaluation has errors, root configuration is not
/// canonical, or an evaluated section cannot be traced back to the syntax
/// document. False conditional sections keep their ordinal gap, so later
/// selection remains stable.
///
/// ```mbt check
/// test {
///   let source = @diagnostics.SourceId::{ value: 0, }
///   let parsed = @syntax.parse(
///     source, "context \"demo\"; budget chars = 80; output text; section \"body\" { text = \"hello\"; }",
///   )
///   let evaluated = @semantics.evaluate(parsed.document, [])
///   guard lower(parsed.document, evaluated) is Some(context) else {
///     fail("expected canonical context IR")
///   }
///   assert_eq(context.sections[0].source_ordinal, 0)
/// }
/// ```
pub fn lower(
  document : @syntax.DocumentSyntax,
  evaluation : @semantics.EvaluationResult,
) -> Context? {
  if evaluation.diagnostics.any(diagnostic => {
      diagnostic.severity == @diagnostics.Severity::Error
    }) {
    return None
  }
  guard extract_configuration(document) is Some((identity, char_budget, output)) else {
    return None
  }
  let sections : Array[Section] = []
  for evaluated in evaluation.sections {
    guard section_ordinal(document, evaluated.span) is Some(source_ordinal) else {
      return None
    }
    let (content, provenance) = lower_content(evaluated.content)
    sections.push({
      name: evaluated.name,
      content,
      source_ordinal,
      priority: evaluated.priority,
      required: evaluated.required,
      provenance: [provenance],
    })
  }
  Some({ identity, output, char_budget, sections, })
}
