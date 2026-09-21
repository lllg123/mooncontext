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

///|
test "counts Unicode text at the exact budget boundary" {
  let empty = audit("", Policy::new(char_budget=1, required_markers=[]))
  assert_eq(empty.character_count, 0)
  assert_false(empty.has_errors())
  let exact = audit("你好", Policy::new(char_budget=2, required_markers=[]))
  assert_eq(exact.character_count, 2)
  assert_false(exact.has_errors())
  let overflow = audit(
    "你好",
    Policy::new(char_budget=1, required_markers=[]),
  )
  assert_true(overflow.has_errors())
  assert_true(overflow.issues.any(issue => issue.code == "A1001"))
}

///|
test "reports empty policy markers without panicking" {
  let report = audit(
    "content",
    Policy::with_forbidden(char_budget=100, required_markers=[""], forbidden_markers=[
      "",
    ]),
  )
  assert_true(report.issues.any(issue => issue.code == "A0002"))
  assert_true(report.issues.any(issue => issue.code == "A0003"))
}

///|
test "preserves one-based positions across lines and Unicode" {
  let report = audit(
    "标题\n前 sk-key",
    Policy::with_forbidden(char_budget=100, required_markers=[], forbidden_markers=[
      "sk-",
    ]),
  )
  let mut marker_issue : Issue? = None
  for issue in report.issues {
    if issue.code == "A1005" {
      marker_issue = Some(issue)
    }
  }
  guard marker_issue is Some(issue) else {
    fail("expected a forbidden marker issue")
  }
  assert_eq(issue.line, 2)
  assert_eq(issue.column, 3)
}
