///|
test "parses a complete context document" {
  let source = source_id()
  let input =
    #|context "review";
    #|budget chars = 2400;
    #|output markdown;
    #|let mode = "review";
    #|include "shared/base.ctx";
    #|section "rules" priority = 90 required when mode == "review" {
    #|  text = "Check correctness.";
    #|}
  let result = @syntax.parse(source, input)
  assert_eq(result.diagnostics.length(), 0)
  assert_eq(result.document.declarations.length(), 6)
  guard result.document.declarations[0]
    is @syntax.DeclarationSyntax::Context(context) else {
    fail("expected a context declaration")
  }
  assert_eq(context.name.value, "review")
  guard result.document.declarations[5]
    is @syntax.DeclarationSyntax::Section(section) else {
    fail("expected a section declaration")
  }
  assert_eq(section.name.value, "rules")
  assert_eq(section.modifiers.length(), 3)
  assert_eq(section.contents.length(), 1)
  assert_true(section.contents[0] is @syntax.SectionContentSyntax::Text(_, _))
}

///|
test "recovers from incomplete declarations" {
  let input =
    #|context "broken"
    #|budget chars = ;
    #|output text;
    #|section "body" required {
    #|  text = "still parsed";
  let result = @syntax.parse(source_id(), input)
  assert_true(result.diagnostics.length() >= 3)
  assert_true(result.diagnostics[0].code == "E2002")
  assert_true(
    result.document.declarations.any(declaration => {
      declaration is @syntax.DeclarationSyntax::Output(_)
    }),
  )
  assert_true(
    result.document.declarations.any(declaration => {
      declaration is @syntax.DeclarationSyntax::Section(_)
    }),
  )
}

///|
test "reports repeated section modifiers" {
  let input =
    #|section "body" required required priority = 1 priority = 2 {
    #|  text = "body";
    #|}
  let result = @syntax.parse(source_id(), input)
  assert_eq(result.diagnostics.length(), 2)
  assert_true(result.diagnostics.all(diagnostic => diagnostic.code == "E2003"))
  guard result.document.declarations[0]
    is @syntax.DeclarationSyntax::Section(section) else {
    fail("expected a section declaration")
  }
  assert_eq(section.modifiers.length(), 4)
}

///|
test "preserves lexical diagnostics while parsing later declarations" {
  let result = @syntax.parse(source_id(), "@; output text;")
  assert_true(result.diagnostics.any(diagnostic => diagnostic.code == "E1001"))
  assert_true(
    result.document.declarations.any(declaration => {
      declaration is @syntax.DeclarationSyntax::Output(_)
    }),
  )
}

///|
test "handles empty input and missing section terminators at EOF" {
  let empty = @syntax.parse(source_id(), "")
  assert_eq(empty.diagnostics.length(), 0)
  assert_eq(empty.document.declarations.length(), 0)

  let incomplete = @syntax.parse(
    source_id(),
    "section \"body\" { text = \"open\";",
  )
  assert_true(
    incomplete.diagnostics.any(diagnostic => diagnostic.code == "E2002"),
  )
  guard incomplete.document.declarations
    is [@syntax.DeclarationSyntax::Section(section)] else {
    fail("expected the incomplete section to be recovered")
  }
  assert_eq(section.contents.length(), 1)
}

///|
test "continues after a stray closing brace" {
  let result = @syntax.parse(source_id(), "} output text;")
  assert_eq(result.diagnostics.map(item => item.code), ["E2001"])
  assert_true(
    result.document.declarations.any(declaration => {
      declaration is @syntax.DeclarationSyntax::Output(_)
    }),
  )
}
