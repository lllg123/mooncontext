///|
fn span(start : Int) -> @diagnostics.Span {
  @diagnostics.Span::new(
    @diagnostics.SourceId::{ value: 0, },
    start~,
    end=start + 1,
  )
}

///|
fn section(
  name : String,
  content : String,
  ordinal : Int,
  priority : Int,
  required : Bool,
) -> @ir.Section {
  {
    name,
    content: @ir.Content::Inline(content),
    source_ordinal: ordinal,
    priority,
    required,
    provenance: [
      {
        content_start: 0,
        content_end: content.length(),
        source: span(ordinal),
      },
    ],
  }
}

///|
fn context(
  output : @ir.OutputFormat,
  budget : Int,
  sections : Array[@ir.Section],
) -> @ir.Context {
  { identity: "test", output, char_budget: budget, sections, }
}

///|
fn plan(result : @budget.AllocationResult) -> @ir.SelectionPlan raise {
  assert_eq(result.diagnostics.length(), 0)
  match result.plan {
    Some(plan) => plan
    None => fail("expected a selection plan")
  }
}

///|
test "selects exact-fit optional sections by priority" {
  let required = section("required", "aaaa", 0, 0, true)
  let lower = section("lower", "bbbb", 1, 10, false)
  let higher = section("higher", "bbb", 2, 90, false)
  let result = plan(
    @budget.allocate(
      context(@ir.OutputFormat::PlainText, 10, [required, lower, higher]),
    ),
  )
  assert_eq(result.selected_section_ids, ["required", "higher"])
  assert_eq(result.omitted_sections, [
    { section_id: "lower", reason: @ir.OmissionReason::BudgetLimit, },
  ])
  assert_eq(result.required_chars, 5)
  assert_eq(result.optional_chars, 5)
  assert_eq(result.total_chars, 10)
  assert_eq(result.remaining_chars, 0)
}

///|
test "breaks equal-priority ties by source ordinal" {
  let later = section("later", "abc", 2, 50, false)
  let earlier = section("earlier", "xyz", 1, 50, false)
  let result = plan(
    @budget.allocate(context(@ir.OutputFormat::PlainText, 4, [later, earlier])),
  )
  assert_eq(result.selected_section_ids, ["earlier"])
  assert_eq(result.omitted_sections.map(item => item.section_id), ["later"])
}

///|
test "continues after an oversized higher-priority section" {
  let higher = section("higher", "too-large", 0, 90, false)
  let lower = section("lower", "fits", 1, 10, false)
  let result = plan(
    @budget.allocate(context(@ir.OutputFormat::PlainText, 5, [higher, lower])),
  )
  assert_eq(result.selected_section_ids, ["lower"])
  assert_eq(result.omitted_sections.map(item => item.section_id), ["higher"])
}

///|
test "reports required content that exceeds the budget" {
  let required = section("required", "hello", 0, 100, true)
  let result = @budget.allocate(
    context(@ir.OutputFormat::PlainText, 5, [required]),
  )
  assert_eq(result.plan, None)
  assert_eq(result.diagnostics.map(item => item.code), ["E5001"])
  assert_eq(result.diagnostics[0].primary, span(0))
}

///|
test "accounts for markdown headings and final line break" {
  let body = section("role", "ok", 0, 50, false)
  let result = plan(
    @budget.allocate(context(@ir.OutputFormat::Markdown, 12, [body])),
  )
  assert_eq(result.selected_section_ids, ["role"])
  assert_eq(result.total_chars, 12)
  assert_eq(result.remaining_chars, 0)
}

///|
test "counts Unicode scalar values instead of encoded units" {
  let body = section("body", "中文", 0, 50, false)
  let result = plan(
    @budget.allocate(context(@ir.OutputFormat::PlainText, 3, [body])),
  )
  assert_eq(result.selected_section_ids, ["body"])
  assert_eq(result.total_chars, 3)
}

///|
test "returns an empty plan without rendering overhead" {
  let result = plan(
    @budget.allocate(context(@ir.OutputFormat::PlainText, 20, [])),
  )
  assert_eq(result.selected_section_ids, [])
  assert_eq(result.total_chars, 0)
  assert_eq(result.remaining_chars, 20)
}
