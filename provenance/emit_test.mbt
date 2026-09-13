///|
fn source(id : Int, path : String, text : String) -> @resolver.ResolvedSource {
  { id: @diagnostics.SourceId::{ value: id, }, path, text, }
}

///|
fn section(
  name : String,
  body : String,
  ordinal : Int,
  source_id : Int,
  source_start : Int,
) -> @ir.Section {
  {
    name,
    content: @ir.Content::Inline(body),
    source_ordinal: ordinal,
    priority: 50,
    required: false,
    provenance: [
      {
        content_start: 0,
        content_end: body.length(),
        source: @diagnostics.Span::new(
          @diagnostics.SourceId::{ value: source_id, },
          start=source_start,
          end=source_start + body.length(),
        ),
      },
    ],
  }
}

///|
fn context(
  output : @ir.OutputFormat,
  sections : Array[@ir.Section],
) -> @ir.Context {
  { identity: "test-context", output, char_budget: 200, sections, }
}

///|
fn plan(
  selected : Array[String],
  omissions : Array[@ir.OmittedSection],
) -> @ir.SelectionPlan {
  {
    selected_section_ids: selected,
    omitted_sections: omissions,
    required_chars: 0,
    optional_chars: 0,
    total_chars: 0,
    remaining_chars: 200,
  }
}

///|
test "maps emitted content ranges to normalized source IDs and paths" {
  let body : @ir.Section = {
    name: "body",
    content: @ir.Content::Inline("hello"),
    source_ordinal: 0,
    priority: 50,
    required: false,
    provenance: [
      {
        content_start: 0,
        content_end: 2,
        source: @diagnostics.Span::new(
          @diagnostics.SourceId::{ value: 1, },
          start=10,
          end=12,
        ),
      },
      {
        content_start: 2,
        content_end: 5,
        source: @diagnostics.Span::new(
          @diagnostics.SourceId::{ value: 1, },
          start=12,
          end=15,
        ),
      },
    ],
  }
  let inputs = [
    source(1, "shared/base.ctx", "0123456789hello"),
    source(0, "root.ctx", "context"),
  ]
  let output = @provenance.emit(
    context(@ir.OutputFormat::Markdown, [body]),
    Some(plan(["body"], [])),
    inputs,
    [],
  )
  assert_eq(output.artifact, Some("## body\n\nhello\n"))
  assert_eq(output.source_map.files.map(file => file.path), [
    "root.ctx", "shared/base.ctx",
  ])
  assert_eq(output.source_map.mappings, [
    {
      section_id: "body",
      generated_start: 9,
      generated_end: 11,
      source: @diagnostics.Span::new(
        @diagnostics.SourceId::{ value: 1, },
        start=10,
        end=12,
      ),
    },
    {
      section_id: "body",
      generated_start: 11,
      generated_end: 14,
      source: @diagnostics.Span::new(
        @diagnostics.SourceId::{ value: 1, },
        start=12,
        end=15,
      ),
    },
  ])
}

///|
test "records omissions, format, budget, and diagnostics in the manifest" {
  let body = section("kept", "ok", 0, 0, 0)
  let omitted = @ir.OmittedSection::{
    section_id: "skipped",
    reason: @ir.OmissionReason::BudgetLimit,
  }
  let selection = plan(["kept"], [omitted])
  let diagnostic = @diagnostics.Diagnostic::new(
    @diagnostics.Severity::Warning,
    code="W6001",
    message="unused definition",
    primary=@diagnostics.Span::new(
      @diagnostics.SourceId::{ value: 0, },
      start=0,
      end=1,
    ),
  )
  let output = @provenance.emit(
    context(@ir.OutputFormat::PlainText, [body]),
    Some(selection),
    [source(0, "root.ctx", "context")],
    [diagnostic],
  )
  assert_eq(output.manifest.context_identity, "test-context")
  assert_eq(output.manifest.output, @ir.OutputFormat::PlainText)
  assert_eq(output.manifest.char_budget, 200)
  assert_eq(output.manifest.inputs.map(file => file.path), ["root.ctx"])
  assert_eq(output.manifest.selection, Some(selection))
  assert_eq(output.manifest.diagnostics.map(item => item.code), ["W6001"])
}

///|
test "keeps failure diagnostics but emits no artifact without a plan" {
  let diagnostic = @diagnostics.Diagnostic::new(
    @diagnostics.Severity::Error,
    code="E5001",
    message="required content exceeds budget",
    primary=@diagnostics.Span::new(
      @diagnostics.SourceId::{ value: 0, },
      start=0,
      end=1,
    ),
  )
  let output = @provenance.emit(
    context(@ir.OutputFormat::PlainText, []),
    None,
    [source(0, "root.ctx", "context")],
    [diagnostic],
  )
  assert_eq(output.artifact, None)
  assert_eq(output.source_map.mappings, [])
  assert_eq(output.manifest.selection, None)
  assert_eq(output.manifest.diagnostics.map(item => item.code), ["E5001"])
}

///|
test "maps Unicode output using scalar character offsets" {
  let body = section("body", "中文", 0, 0, 0)
  let output = @provenance.emit(
    context(@ir.OutputFormat::PlainText, [body]),
    Some(plan(["body"], [])),
    [source(0, "root.ctx", "中文")],
    [],
  )
  assert_eq(output.artifact, Some("中文\n"))
  assert_eq(output.source_map.mappings[0].generated_start, 0)
  assert_eq(output.source_map.mappings[0].generated_end, 2)
}

///|
test "maps supplementary Unicode characters as single output positions" {
  let body : @ir.Section = {
    name: "body",
    content: @ir.Content::Inline("😀x"),
    source_ordinal: 0,
    priority: 50,
    required: false,
    provenance: [
      {
        content_start: 0,
        content_end: 2,
        source: @diagnostics.Span::new(
          @diagnostics.SourceId::{ value: 0, },
          start=0,
          end=2,
        ),
      },
    ],
  }
  let output = @provenance.emit(
    context(@ir.OutputFormat::PlainText, [body]),
    Some(plan(["body"], [])),
    [source(0, "root.ctx", "😀x")],
    [],
  )
  assert_eq(output.artifact, Some("😀x\n"))
  assert_eq(output.source_map.mappings[0].generated_end, 2)
}

///|
test "ignores invalid provenance ranges instead of emitting broken maps" {
  let body = section("body", "ok", 0, 0, 0)
  body.provenance[0] = {
    content_start: 0,
    content_end: 10,
    source: @diagnostics.Span::new(
      @diagnostics.SourceId::{ value: 0, },
      start=0,
      end=2,
    ),
  }
  let output = @provenance.emit(
    context(@ir.OutputFormat::PlainText, [body]),
    Some(plan(["body"], [])),
    [source(0, "root.ctx", "ok")],
    [],
  )
  assert_eq(output.source_map.mappings, [])
}
