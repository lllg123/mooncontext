///|
async test "compiles local context sources and emits provenance metadata" {
  let parsed = parse_command([
    "build", "cmd/main/testdata/cli.ctx", "--define", "language=MoonBit",
  ])
  let options = match parsed.options {
    Some(value) => value
    None => fail("expected the test command to parse")
  }
  let result = compile(options)
  assert_eq(result.diagnostics.length(), 0)
  match result.plan {
    Some(plan) =>
      assert_true(
        plan.omitted_sections.any(section => section.section_id == "large"),
      )
    None => fail("expected a budget plan")
  }
  match (result.context, result.plan) {
    (Some(context), Some(plan)) => {
      let emitted = @provenance.emit(
        context,
        Some(plan),
        result.sources,
        result.diagnostics,
      )
      assert_eq(
        emitted.artifact,
        Some("Hello MoonBit.\n\nThis content came from a file.\n\n"),
      )
      assert_true(
        emitted.source_map.files.any(file => {
          file.path == "cmd/main/testdata/cli-content.txt"
        }),
      )
      assert_true(
        emitted.source_map.mappings.any(mapping => {
          mapping.section_id == "notes" &&
          emitted.source_map.files[mapping.source.source.value].path ==
          "cmd/main/testdata/cli-content.txt"
        }),
      )
      assert_true(
        manifest_json(emitted.manifest).contains(
          "\"context_identity\":\"cli-test\"",
        ),
      )
    }
    _ => fail("expected a context IR and budget plan")
  }
}
