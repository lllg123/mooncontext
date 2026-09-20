///|
test "command-line audit options merge with reusable policy" {
  let parsed = parse_command([
    "audit", "context.md", "--policy", "policy.json", "--budget", "200", "--require",
    "CLI rule", "--forbid", "DEBUG", "--deny-warnings",
  ])
  guard parsed.options is Some(options) else { fail("expected audit options") }
  let loaded : @audit.PolicyConfig = {
    version: 1,
    policy: @audit.Policy::with_forbidden(
      char_budget=100,
      required_markers=["File rule"],
      forbidden_markers=["TODO"],
    ),
    deny_warnings: false,
  }
  guard effective_audit_policy(options, Some(loaded)) is Some((policy, strict)) else {
    fail("expected an effective policy")
  }
  assert_eq(policy.char_budget, 200)
  assert_eq(policy.required_markers, ["File rule", "CLI rule"])
  assert_eq(policy.forbidden_markers, ["TODO", "DEBUG"])
  assert_true(strict)
}

///|
test "loaded strictness cannot be weakened by command-line defaults" {
  let parsed = parse_command(["audit", "context.md", "--policy", "policy.json"])
  guard parsed.options is Some(options) else { fail("expected audit options") }
  let loaded : @audit.PolicyConfig = {
    version: 1,
    policy: @audit.Policy::new(char_budget=100, required_markers=[]),
    deny_warnings: true,
  }
  guard effective_audit_policy(options, Some(loaded)) is Some((_, strict)) else {
    fail("expected an effective policy")
  }
  assert_true(strict)
}
