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
