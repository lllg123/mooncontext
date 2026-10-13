///|
test "machine-readable audit reports identify the artifact" {
  let report = @audit.audit(
    "context",
    @audit.Policy::new(char_budget=100, required_markers=[]),
  )
  let output = audit_json("context.md", report)
  assert_true(output.contains("\"fingerprint\":\"\{report.fingerprint}\""))
  assert_true(output.contains("\"path\":\"context.md\""))
}

///|
test "batch output includes artifacts and an aggregate summary" {
  let first = @audit.audit(
    "first",
    @audit.Policy::new(char_budget=100, required_markers=[]),
  )
  let second = @audit.audit(
    "second",
    @audit.Policy::new(char_budget=3, required_markers=[]),
  )
  let output = audit_json_batch(
    2,
    ["first.md", "second.md"],
    [first, second],
    [],
    false,
  )
  assert_true(output.contains("\"artifacts\":["))
  assert_true(output.contains("\"path\":\"first.md\""))
  assert_true(output.contains("\"path\":\"second.md\""))
  assert_true(output.contains("\"summary\":{\"total\":2"))
  assert_true(output.contains("\"failed\":1"))
}

///|
test "batch output separates warnings failures and read errors" {
  let clean = @audit.audit(
    "ok",
    @audit.Policy::new(char_budget=10, required_markers=[]),
  )
  let warning = @audit.audit(
    "# Role\n# Role",
    @audit.Policy::new(char_budget=100, required_markers=[]),
  )
  let failed = @audit.audit(
    "too long",
    @audit.Policy::new(char_budget=3, required_markers=[]),
  )
  let errors : Array[AuditReadError] = [
    { path: "missing\".md", message: "not found\n", },
  ]
  let output = audit_json_batch(
    4,
    ["clean.md", "warning.md", "failed.md"],
    [clean, warning, failed],
    errors,
    false,
  )
  assert_true(
    output.contains(
      "\"summary\":{\"total\":4,\"audited\":3,\"passed\":1,\"warnings\":1,\"failed\":1,\"errors\":1}",
    ),
  )
  assert_true(output.contains("\"path\":\"missing\\\".md\""))
  assert_true(output.contains("\"message\":\"not found\\n\""))
  let strict_output = audit_json_batch(
    4,
    ["clean.md", "warning.md", "failed.md"],
    [clean, warning, failed],
    errors,
    true,
  )
  assert_true(strict_output.contains("\"failed\":2"))
}

///|
test "batch output handles all unreadable and empty artifact batches" {
  let errors : Array[AuditReadError] = [
    { path: "first.md", message: "missing", },
    { path: "second.md", message: "permission denied", },
  ]
  let output = audit_json_batch(2, [], [], errors, false)
  assert_true(output.contains("\"artifacts\":[]"))
  assert_true(output.contains("\"errors\":["))
  assert_true(
    output.contains(
      "\"summary\":{\"total\":2,\"audited\":0,\"passed\":0,\"warnings\":0,\"failed\":0,\"errors\":2}",
    ),
  )
}

///|
test "audit JSON quotes every control character in an accepted policy" {
  let parsed_policy = @audit.parse_policy_json(
    "{\"version\":1,\"char_budget\":100,\"forbidden_markers\":[\"bad\\u000cmark\"]}",
  )
  guard parsed_policy is Ok(config) else {
    fail("expected policy with escaped form feed to parse")
  }
  let report = @audit.audit("bad\u{000c}mark", config.policy)
  assert_true(report.has_failures(deny_warnings=true))
  let output = audit_json("context.md", report)
  let parsed = @json.parse(output)
  guard parsed is Object(_) else { fail("audit report must be valid JSON") }
  assert_false(output.contains("\u{000c}"))
  for code in 0..<32 {
    let value = StringBuilder()
    value.write_char(code.unsafe_to_char())
    let encoded = json_quote(value.to_string())
    let decoded : String = @json.from_json(@json.parse(encoded))
    assert_eq(decoded, value.to_string())
  }
}
