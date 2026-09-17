///|
test "parses check definitions and an input path" {
  let parsed = parse_command([
    "check", "contexts/review.ctx", "--define", "mode=review",
  ])
  assert_true(parsed.error is None)
  assert_false(parsed.help)
  match parsed.options {
    Some(options) => {
      assert_eq(options.action, "check")
      assert_eq(options.input, "contexts/review.ctx")
      assert_eq(options.definitions, [{ name: "mode", value: "review", }])
    }
    None => fail("expected parsed command options")
  }
}

///|
test "parses build artifact and provenance output paths" {
  let parsed = parse_command([
    "build", "root.ctx", "--source-map", "build/map.json", "--manifest", "build/manifest.json",
    "-o", "build/context.md",
  ])
  match parsed.options {
    Some(options) => {
      assert_eq(options.action, "build")
      assert_eq(options.output, Some("build/context.md"))
      assert_eq(options.source_map, Some("build/map.json"))
      assert_eq(options.manifest, Some("build/manifest.json"))
    }
    None => fail("expected parsed command options")
  }
}

///|
test "rejects malformed definitions and unknown commands" {
  let malformed = parse_command(["check", "root.ctx", "--define", "not-valid=x"])
  assert_true(malformed.error is Some(_))
  let unknown = parse_command(["publish", "root.ctx"])
  assert_true(unknown.error is Some(_))
  let invalid_output = parse_command(["check", "root.ctx", "-o", "result.txt"])
  assert_true(invalid_output.error is Some(_))
}

///|
test "preserves equals signs in definition values" {
  assert_eq(
    parse_definition("expression=a=b"),
    Some({ name: "expression", value: "a=b", }),
  )
}

///|
test "parses audit policy options" {
  let parsed = parse_command([
    "audit", "README.md", "--budget", "1200", "--require", "Role", "--require", "Rules",
    "--forbid", "sk-", "--report", "audit.txt", "--json", "--deny-warnings",
  ])
  match parsed.options {
    Some(options) => {
      assert_eq(options.action, "audit")
      assert_eq(options.input, "README.md")
      assert_eq(options.audit_budget, Some(1200))
      assert_eq(options.required_markers, ["Role", "Rules"])
      assert_eq(options.forbidden_markers, ["sk-"])
      assert_eq(options.report, Some("audit.txt"))
      assert_true(options.json)
      assert_true(options.deny_warnings)
    }
    None => fail("expected audit options")
  }
}

///|
test "requires an audit budget" {
  let parsed = parse_command(["audit", "README.md"])
  assert_true(parsed.error is Some(_))
}
