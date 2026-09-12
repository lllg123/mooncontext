///|
fn evaluate_source(
  input : String,
  definitions : Array[@semantics.Definition],
) -> @semantics.EvaluationResult raise {
  let source = @diagnostics.SourceId::{ value: 0, }
  let parsed = @syntax.parse(source, input)
  assert_eq(parsed.diagnostics.length(), 0)
  @semantics.evaluate(parsed.document, definitions)
}

///|
fn inline_text(section : @semantics.EvaluatedSection) -> String raise {
  match section.content {
    InlineText(value, _) => value
    FileReference(path, _) => fail("expected inline text, found file `\{path}`")
  }
}

///|
test "replaces source variables and preserves escaped interpolation" {
  let input =
    #|let product = "MoonContext";
    #|section "body" { text = "Use ${product}; write $${literal}."; }
  let result = evaluate_source(input, [])
  assert_eq(result.diagnostics.length(), 0)
  assert_eq(result.sections.length(), 1)
  assert_eq(
    inline_text(result.sections[0]),
    "Use MoonContext; write ${literal}.",
  )
}

///|
test "explicit definitions override source variables and select conditions" {
  let input =
    #|let mode = "draft";
    #|section "review" when mode == "review" { text = "${audience}"; }
    #|section "draft" when mode != "review" { text = "draft"; }
  let result = evaluate_source(input, [
    { name: "mode", value: "review", },
    { name: "audience", value: "maintainers", },
  ])
  assert_eq(result.diagnostics.length(), 0)
  assert_eq(result.sections.length(), 1)
  assert_eq(result.sections[0].name, "review")
  assert_eq(inline_text(result.sections[0]), "maintainers")
}

///|
test "reports a missing condition variable and omits its section" {
  let input =
    #|section "private" when tier == "pro" { text = "secret"; }
  let result = evaluate_source(input, [])
  assert_eq(result.sections.length(), 0)
  assert_eq(result.diagnostics.map(item => item.code), ["E4002"])
}

///|
test "reports missing interpolation variables without losing source text" {
  let input =
    #|section "body" { text = "Hello ${audience}."; }
  let result = evaluate_source(input, [])
  assert_eq(result.sections.length(), 1)
  assert_eq(result.diagnostics.map(item => item.code), ["E4002"])
  assert_eq(inline_text(result.sections[0]), "Hello ${audience}.")
}

///|
test "uses default and explicit section selection attributes" {
  let input =
    #|section "default" { text = "default"; }
    #|section "required" priority = 90 required { text = "required"; }
  let result = evaluate_source(input, [])
  assert_eq(result.diagnostics.length(), 0)
  assert_eq(result.sections[0].priority, 50)
  assert_eq(result.sections[0].required, false)
  assert_eq(result.sections[1].priority, 90)
  assert_eq(result.sections[1].required, true)
}

///|
test "resolves variables independently of declaration order" {
  let input =
    #|section "body" { text = "${mode}"; }
    #|let mode = "review";
  let result = evaluate_source(input, [])
  assert_eq(result.diagnostics.length(), 0)
  assert_eq(inline_text(result.sections[0]), "review")
}
