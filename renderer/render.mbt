///|
fn selected(plan : @ir.SelectionPlan, section_id : String) -> Bool {
  plan.selected_section_ids.any(id => id == section_id)
}

///|
fn source_ordered(
  context : @ir.Context,
  plan : @ir.SelectionPlan,
) -> Array[@ir.Section] {
  let sections = context.sections.filter(section => selected(plan, section.name))
  for index in 1..<sections.length() {
    let mut current = index
    while current > 0 &&
          sections[current].source_ordinal <
          sections[current - 1].source_ordinal {
      let previous = sections[current - 1]
      sections[current - 1] = sections[current]
      sections[current] = previous
      current -= 1
    }
  }
  sections
}

///|
fn write_content(output : StringBuilder, content : @ir.Content) -> Unit {
  match content {
    Inline(value) | File(value) => output.write_string(value)
  }
}

///|
fn write_section(
  output : StringBuilder,
  format : @ir.OutputFormat,
  section : @ir.Section,
) -> Unit {
  if format == Markdown {
    output.write_string("## ")
    output.write_string(section.name)
    output.write_string("\n\n")
  }
  write_content(output, section.content)
}

///|
/// Render selected context sections as deterministic Markdown or plain text.
///
/// Sections are emitted by source ordinal, separated by one blank line. Empty
/// plans produce an empty artifact; every non-empty artifact ends in `\n`.
///
/// ```mbt check
/// test {
///   let section : @ir.Section = {
///     name: "body",
///     content: Inline("hello"),
///     source_ordinal: 0,
///     priority: 50,
///     required: false,
///     provenance: [],
///   }
///   let context : @ir.Context = {
///     identity: "demo",
///     output: PlainText,
///     char_budget: 6,
///     sections: [section],
///   }
///   let plan : @ir.SelectionPlan = {
///     selected_section_ids: ["body"],
///     omitted_sections: [],
///     required_chars: 0,
///     optional_chars: 6,
///     total_chars: 6,
///     remaining_chars: 0,
///   }
///   assert_eq(render(context, plan), "hello\n")
/// }
/// ```
pub fn render(context : @ir.Context, plan : @ir.SelectionPlan) -> String {
  let sections = source_ordered(context, plan)
  if sections.length() == 0 {
    return ""
  }
  let output = StringBuilder()
  for index, section in sections {
    if index > 0 {
      output.write_string("\n\n")
    }
    write_section(output, context.output, section)
  }
  output.write_char('\n')
  output.to_string()
}
