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
