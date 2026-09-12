///|
fn validate_source(
  input : String,
  kind : @semantics.SourceKind,
) -> Array[String] raise {
  let source = @diagnostics.SourceId::{ value: 0, }
  let parsed = @syntax.parse(source, input)
  assert_eq(parsed.diagnostics.length(), 0)
  let result = @semantics.validate(source, parsed.document, kind)
  result.diagnostics.map(diagnostic => diagnostic.code)
}

///|
test "accepts a valid root document" {
  let input =
    #|context "review";
    #|budget chars = 2400;
    #|output markdown;
    #|let mode = "review";
    #|section "rules" priority = 90 required when mode == "review" {
    #|  text = "Apply ${mode} rules.";
    #|}
  let codes = validate_source(input, @semantics.SourceKind::Root)
  assert_eq(codes.length(), 0)
}

///|
test "reports duplicate variables and sections" {
  let input =
    #|context "duplicates";
    #|budget chars = 100;
    #|output text;
    #|let mode = "one";
    #|let mode = "two";
    #|section "body" { text = "one"; }
    #|section "body" { text = "two"; }
  let codes = validate_source(input, @semantics.SourceKind::Root)
  assert_eq(codes, ["E4001", "E4001"])
}

///|
test "reports undefined condition and interpolation variables" {
  let input =
    #|context "references";
    #|budget chars = 100;
    #|output text;
    #|section "body" when mode == "review" {
    #|  text = "Hello ${audience}; literal $${ignored}.";
    #|}
  let codes = validate_source(input, @semantics.SourceKind::Root)
  assert_eq(codes, ["E4002", "E4002"])
}

///|
test "reports invalid declaration attributes and section rules" {
  let input =
    #|context "";
    #|budget chars = 0;
    #|output html;
    #|section "" priority = 101 {
    #|}
  let codes = validate_source(input, @semantics.SourceKind::Root)
  assert_eq(codes, ["E4007", "E4006", "E4007", "E4007", "E4003", "E4005"])
}

///|
test "enforces root and included-file declarations" {
  let root_input =
    #|let mode = "review";
    #|section "body" { text = "ok"; }
  let root_codes = validate_source(root_input, @semantics.SourceKind::Root)
  assert_eq(root_codes, ["E4004", "E4004", "E4004", "E4004"])
  let included_input =
    #|context "shared";
    #|budget chars = 10;
    #|output text;
  let included_codes = validate_source(
    included_input,
    @semantics.SourceKind::Included,
  )
  assert_eq(included_codes, ["E4004", "E4004", "E4004"])
}
