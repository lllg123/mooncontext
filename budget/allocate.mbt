///|
fn character_length(value : String) -> Int {
  let mut length = 0
  for _ in value {
    length += 1
  }
  length
}

///|
fn content_length(content : @ir.Content) -> Int {
  match content {
    Inline(value) | File(value) => character_length(value)
  }
}

///|
fn rendered_size(
  output : @ir.OutputFormat,
  sections : Array[@ir.Section],
) -> Int {
  if sections.length() == 0 {
    return 0
  }
  let mut size = 1 + (sections.length() - 1) * 2
  for section in sections {
    size += content_length(section.content)
    if output == Markdown {
      size += 3 + character_length(section.name) + 2
    }
  }
  size
}

///|
fn comes_before(left : @ir.Section, right : @ir.Section) -> Bool {
  left.source_ordinal < right.source_ordinal
}

///|
fn considered_before(left : @ir.Section, right : @ir.Section) -> Bool {
  left.priority > right.priority ||
  (
    left.priority == right.priority &&
    left.source_ordinal < right.source_ordinal
  )
}

///|
fn sort_sections(
  sections : Array[@ir.Section],
  before : (@ir.Section, @ir.Section) -> Bool,
) -> Unit {
  for index in 1..<sections.length() {
    let mut current = index
    while current > 0 && before(sections[current], sections[current - 1]) {
      let previous = sections[current - 1]
      sections[current - 1] = sections[current]
      sections[current] = previous
      current -= 1
    }
  }
}

///|
fn source_ordered(context : @ir.Context) -> Array[@ir.Section] {
  let sections = context.sections.map(section => section)
  sort_sections(sections, comes_before)
  sections
}

///|
fn diagnostic_anchor(sections : Array[@ir.Section]) -> @diagnostics.Span {
  for section in sections {
    match section.provenance.get(0) {
      Some(segment) => return segment.source
      None => ()
    }
  }
  @diagnostics.Span::new(@diagnostics.SourceId::{ value: 0, }, start=0, end=0)
}

///|
fn required_overflow(
  context : @ir.Context,
  required : Array[@ir.Section],
  required_chars : Int,
) -> AllocationResult {
  let primary = diagnostic_anchor(required)
  let diagnostic = @diagnostics.Diagnostic::new(
    @diagnostics.Severity::Error,
    code="E5001",
    message="required content uses \{required_chars} characters, exceeding the budget of \{context.char_budget}",
    primary~,
    help="increase the character budget or reduce required content",
  )
  { plan: None, diagnostics: [diagnostic], }
}

///|
fn contains_section(sections : Array[@ir.Section], section_id : String) -> Bool {
  sections.any(section => section.name == section_id)
}

///|
/// Allocate the character budget with stable, atomic section selection.
///
/// Required sections are retained first. Optional sections are considered by
/// descending priority and then ascending source ordinal. Selected IDs and
/// omissions are returned in source order.
///
/// ```mbt check
/// test {
///   let span = @diagnostics.Span::new(
///     @diagnostics.SourceId::{ value: 0, },
///     start=0,
///     end=1,
///   )
///   let section : @ir.Section = {
///     name: "body",
///     content: Inline("hello"),
///     source_ordinal: 0,
///     priority: 50,
///     required: false,
///     provenance: [{ content_start: 0, content_end: 5, source: span, }],
///   }
///   let context : @ir.Context = {
///     identity: "demo",
///     output: PlainText,
///     char_budget: 6,
///     sections: [section],
///   }
///   guard allocate(context).plan is Some(plan) else {
///     fail("expected a selection plan")
///   }
///   assert_eq(plan.selected_section_ids, ["body"])
/// }
/// ```
pub fn allocate(context : @ir.Context) -> AllocationResult {
  let ordered = source_ordered(context)
  let required = ordered.filter(section => section.required)
  let required_chars = rendered_size(context.output, required)
  if required_chars > context.char_budget {
    return required_overflow(context, required, required_chars)
  }
  let candidates = ordered.filter(section => !section.required)
  sort_sections(candidates, considered_before)
  let selected = required.map(section => section)
  for candidate in candidates {
    selected.push(candidate)
    if rendered_size(context.output, selected) > context.char_budget {
      ignore(selected.pop())
    }
  }
  sort_sections(selected, comes_before)
  let total_chars = rendered_size(context.output, selected)
  let omitted : Array[@ir.OmittedSection] = []
  for section in ordered {
    if !contains_section(selected, section.name) {
      omitted.push({ section_id: section.name, reason: BudgetLimit, })
    }
  }
  {
    plan: Some({
      selected_section_ids: selected.map(section => section.name),
      omitted_sections: omitted,
      required_chars,
      optional_chars: total_chars - required_chars,
      total_chars,
      remaining_chars: context.char_budget - total_chars,
    }),
    diagnostics: [],
  }
}
