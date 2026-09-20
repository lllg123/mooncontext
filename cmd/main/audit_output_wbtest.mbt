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
