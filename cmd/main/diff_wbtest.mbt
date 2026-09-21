///|
fn diff_before_report() -> String {
  (
    #|{
    #|  "artifacts": [
    #|    {"path":"same.md","fingerprint":"sha256:same","issues":[]},
    #|    {"path":"changed.md","fingerprint":"sha256:old","issues":[]},
    #|    {"path":"removed.md","fingerprint":"sha256:removed","issues":[]}
    #|  ],
    #|  "errors": [{"path":"missing.md","message":"not found"}],
    #|  "summary": {}
    #|}
  )
}

///|
fn diff_after_report() -> String {
  (
    #|{
    #|  "artifacts": [
    #|    {"path":"same.md","fingerprint":"sha256:same","issues":[]},
    #|    {"path":"changed.md","fingerprint":"sha256:new","issues":[{"code":"A1001"}]},
    #|    {"path":"added.md","fingerprint":"sha256:added","issues":[]}
    #|  ],
    #|  "errors": [{"path":"new-missing.md","message":"not found"}],
    #|  "summary": {}
    #|}
  )
}

///|
test "compares single and batch report artifacts" {
  let before = match parse_audit_snapshot(diff_before_report()) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let after = match parse_audit_snapshot(diff_after_report()) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let diff = compare_audit_snapshots(before, after)
  assert_eq(diff.added, ["added.md"])
  assert_eq(diff.removed, ["removed.md"])
  assert_eq(diff.unchanged, ["same.md"])
  assert_eq(diff.changed.length(), 1)
  assert_eq(diff.changed[0].path, "changed.md")
  assert_eq(diff.changed[0].before_fingerprint, "sha256:old")
  assert_eq(diff.changed[0].after_fingerprint, "sha256:new")
  assert_eq(diff.changed[0].added_issues, ["A1001"])
  assert_eq(diff.changed[0].removed_issues, [])
  assert_eq(diff.errors_added, ["new-missing.md"])
  assert_eq(diff.errors_removed, ["missing.md"])
  assert_true(audit_diff_has_changes(diff))
}

///|
test "renders deterministic JSON and text diff output" {
  let before = match
    parse_audit_snapshot(
      "{\"path\":\"same.md\",\"fingerprint\":\"sha256:same\",\"issues\":[]}",
    ) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let after = match
    parse_audit_snapshot(
      "{\"path\":\"same.md\",\"fingerprint\":\"sha256:same\",\"issues\":[]}",
    ) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let diff = compare_audit_snapshots(before, after)
  assert_false(audit_diff_has_changes(diff))
  assert_true(diff_json(diff).contains("\"status\":\"unchanged\""))
  assert_true(diff_json(diff).contains("\"unchanged\":[\"same.md\"]"))
  assert_true(
    diff_text("before.json", "after.json", diff).contains("status: unchanged"),
  )
}

///|
test "rejects malformed or duplicate audit reports" {
  assert_true(parse_audit_snapshot("{") is Err(_))
  assert_true(
    parse_audit_snapshot(
      "{\"artifacts\":[{\"path\":\"a\",\"fingerprint\":\"x\"},{\"path\":\"a\",\"fingerprint\":\"y\"}]}",
    )
    is Err(_),
  )
  assert_true(
    parse_audit_snapshot("{\"artifacts\":[{\"path\":\"a\",\"fingerprint\":1}]}")
    is Err(_),
  )
}
