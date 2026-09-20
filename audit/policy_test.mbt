///|
test "parses a complete reusable JSON policy" {
  let parsed = parse_policy_json(
    (
      #|{
      #|  "version": 1,
      #|  "char_budget": 1200,
      #|  "required_markers": ["Role", "Evidence"],
      #|  "forbidden_markers": ["sk-", "TODO"],
      #|  "deny_warnings": true
      #|}
      #|
    ),
  )
  guard parsed is Ok(config) else { fail("expected a valid policy") }
  assert_eq(config.version, 1)
  assert_eq(config.policy.char_budget, 1200)
  assert_eq(config.policy.required_markers, ["Role", "Evidence"])
  assert_eq(config.policy.forbidden_markers, ["sk-", "TODO"])
  assert_true(config.deny_warnings)
}

///|
test "defaults optional policy fields" {
  let parsed = parse_policy_json("{\"version\":1,\"char_budget\":80}")
  guard parsed is Ok(config) else { fail("expected a valid policy") }
  assert_eq(config.policy.required_markers, [])
  assert_eq(config.policy.forbidden_markers, [])
  assert_false(config.deny_warnings)
}

///|
test "rejects malformed JSON and non-object roots" {
  assert_true(parse_policy_json("{") is Err(_))
  assert_true(parse_policy_json("[]") is Err(_))
}

///|
test "rejects unsupported versions and invalid budgets" {
  assert_true(parse_policy_json("{\"version\":2,\"char_budget\":80}") is Err(_))
  assert_true(parse_policy_json("{\"version\":1,\"char_budget\":0}") is Err(_))
  assert_true(
    parse_policy_json("{\"version\":1,\"char_budget\":\"80\"}") is Err(_),
  )
  assert_true(
    parse_policy_json("{\"version\":1,\"char_budget\":80.5}") is Err(_),
  )
}

///|
test "rejects unknown fields and malformed marker arrays" {
  assert_true(
    parse_policy_json(
      (
        #|{"version":1,"char_budget":80,"deny_warning":true}
      ),
    )
    is Err(_),
  )
  assert_true(
    parse_policy_json(
      (
        #|{"version":1,"char_budget":80,"required_markers":[""]}
      ),
    )
    is Err(_),
  )
  assert_true(
    parse_policy_json(
      (
        #|{"version":1,"char_budget":80,"forbidden_markers":"TODO"}
      ),
    )
    is Err(_),
  )
}
