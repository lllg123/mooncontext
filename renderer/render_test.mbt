///|
fn section(name : String, body : String, ordinal : Int) -> @ir.Section {
  {
    name,
    content: @ir.Content::Inline(body),
    source_ordinal: ordinal,
    priority: 50,
    required: false,
    provenance: [],
  }
}

///|
fn context(
  output : @ir.OutputFormat,
  sections : Array[@ir.Section],
) -> @ir.Context {
  { identity: "test", output, char_budget: 1000, sections, }
}

///|
fn plan(selected : Array[String]) -> @ir.SelectionPlan {
  {
    selected_section_ids: selected,
    omitted_sections: [],
    required_chars: 0,
    optional_chars: 0,
    total_chars: 0,
    remaining_chars: 0,
  }
}

///|
test "renders Markdown headings in source order" {
  let later = section("details", "Second body.", 2)
  let earlier = section("role", "First body.", 0)
  let artifact = @renderer.render(
    context(@ir.OutputFormat::Markdown, [later, earlier]),
    plan(["details", "role"]),
  )
  assert_eq(artifact, "## role\n\nFirst body.\n\n## details\n\nSecond body.\n")
}

///|
test "renders plain text with one blank line between sections" {
  let artifact = @renderer.render(
    context(@ir.OutputFormat::PlainText, [
      section("first", "alpha", 0),
      section("second", "beta", 1),
    ]),
    plan(["first", "second"]),
  )
  assert_eq(artifact, "alpha\n\nbeta\n")
}

///|
test "omits sections absent from the selection plan" {
  let artifact = @renderer.render(
    context(@ir.OutputFormat::PlainText, [
      section("selected", "keep", 0),
      section("omitted", "drop", 1),
    ]),
    plan(["selected"]),
  )
  assert_eq(artifact, "keep\n")
}

///|
test "renders an empty plan as an empty artifact" {
  let artifact = @renderer.render(
    context(@ir.OutputFormat::Markdown, [section("body", "ignored", 0)]),
    plan([]),
  )
  assert_eq(artifact, "")
}

///|
test "renders selected file content values" {
  let file_section : @ir.Section = {
    name: "file",
    content: @ir.Content::File("content/rules.md"),
    source_ordinal: 0,
    priority: 50,
    required: false,
    provenance: [],
  }
  let artifact = @renderer.render(
    context(@ir.OutputFormat::PlainText, [file_section]),
    plan(["file"]),
  )
  assert_eq(artifact, "content/rules.md\n")
}
