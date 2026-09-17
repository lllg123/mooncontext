///|
test "accepts a bounded rendered context" {
  let report = audit(
    "# Role\nYou are a reviewer.\n\n## Rules\nKeep evidence.",
    Policy::new(char_budget=80, required_markers=["Role", "Rules"]),
  )
  assert_false(report.has_errors())
  assert_eq(report.character_count, 51)
  assert_eq(report.heading_count, 2)
}

///|
test "reports missing markers and unresolved placeholders" {
  let report = audit(
    "# Role\nHello \\${name}",
    Policy::new(char_budget=100, required_markers=["Rules"]),
  )
  assert_true(report.has_errors())
  assert_true(report.issues.any(issue => issue.code == "A1002"))
  assert_true(report.issues.any(issue => issue.code == "A1003"))
}

///|
test "reports budget overflow and duplicate headings" {
  let report = audit(
    "# Role\nLong text\n# Role\nMore text",
    Policy::new(char_budget=10, required_markers=[]),
  )
  assert_true(report.has_errors())
  assert_true(report.issues.any(issue => issue.code == "A1001"))
  assert_true(report.issues.any(issue => issue.code == "A2001"))
}

///|
test "rejects forbidden markers with source position" {
  let report = audit(
    "# Role\nUse token sk-test in development only.",
    Policy::with_forbidden(char_budget=100, required_markers=[], forbidden_markers=[
      "sk-",
    ]),
  )
  assert_true(report.has_errors())
  let mut found = false
  for issue in report.issues {
    if issue.code == "A1005" {
      found = true
      assert_eq(issue.line, 2)
      assert_eq(issue.column, 11)
    }
  }
  assert_true(found)
}

///|
test "strict mode treats duplicate headings as failures" {
  let report = audit(
    "# Role\n# Role",
    Policy::new(char_budget=100, required_markers=[]),
  )
  assert_false(report.has_failures(deny_warnings=false))
  assert_true(report.has_failures(deny_warnings=true))
}
