///|
fn lower_source(input : String) -> @ir.Context? raise {
  let source = @diagnostics.SourceId::{ value: 0, }
  let parsed = @syntax.parse(source, input)
  assert_eq(parsed.diagnostics.length(), 0)
  let evaluated = @semantics.evaluate(parsed.document, [])
  @ir.lower(parsed.document, evaluated)
}

///|
test "lowers evaluated sections and preserves inactive ordinal gaps" {
  let input =
    #|context "review";
    #|budget chars = 2400;
    #|output markdown;
    #|let mode = "review";
    #|let audience = "team";
    #|section "draft" when mode != "review" { text = "draft"; }
    #|section "body" priority = 90 required { text = "Hello ${audience}"; }
  guard lower_source(input) is Some(context) else {
    fail("expected canonical context IR")
  }
  assert_eq(context.identity, "review")
  assert_eq(context.output, @ir.OutputFormat::Markdown)
  assert_eq(context.char_budget, 2400)
  assert_eq(context.sections.length(), 1)
  let section = context.sections[0]
  assert_eq(section.name, "body")
  assert_eq(section.content, @ir.Content::Inline("Hello team"))
  assert_eq(section.source_ordinal, 1)
  assert_eq(section.priority, 90)
  assert_eq(section.required, true)
  assert_eq(section.provenance[0].content_start, 0)
  assert_eq(section.provenance[0].content_end, 10)
  assert_eq(section.provenance[0].source.source.value, 0)
}

///|
test "retains normalized file references as canonical content" {
  let input =
    #|context "files";
    #|budget chars = 100;
    #|output text;
    #|section "rules" { file = "content/rules.md"; }
  guard lower_source(input) is Some(context) else {
    fail("expected canonical context IR")
  }
  assert_eq(context.output, @ir.OutputFormat::PlainText)
  assert_eq(context.sections[0].content, @ir.Content::File("content/rules.md"))
  assert_eq(context.sections[0].provenance[0].content_end, 16)
}

///|
test "does not lower evaluation errors" {
  let input =
    #|context "missing";
    #|budget chars = 100;
    #|output text;
    #|section "body" { text = "Hello ${audience}"; }
  assert_eq(lower_source(input), None)
}

///|
test "does not lower incomplete root configuration" {
  let input =
    #|context "incomplete";
    #|budget chars = 100;
    #|section "body" { text = "hello"; }
  assert_eq(lower_source(input), None)
}

///|
test "does not lower duplicate root configuration" {
  let input =
    #|context "first";
    #|context "second";
    #|budget chars = 100;
    #|output text;
    #|section "body" { text = "hello"; }
  assert_eq(lower_source(input), None)
}
