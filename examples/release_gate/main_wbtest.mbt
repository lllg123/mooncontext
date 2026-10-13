///|
test "approved final context is the exact model-call payload" {
  let context = render_context("PR-42", "Reviewed and approved.")
  let sent : Array[String] = []
  let events : Array[String] = []
  let report = release_if_approved(context, _report => events.push("audit"), payload => {
    events.push("model")
    sent.push(payload)
  })
  assert_false(report.has_failures(deny_warnings=true))
  assert_eq(sent.length(), 1)
  assert_eq(sent[0], context)
  assert_eq(report.fingerprint, @audit.fingerprint(sent[0]))
  assert_eq(events, ["audit", "model"])
}

///|
test "rejected final context never invokes the model callback" {
  let context = render_context("PR-42", "TODO: key sk-example")
  let sent : Array[String] = []
  let events : Array[String] = []
  let report = release_if_approved(context, _report => events.push("audit"), payload => {
    events.push("model")
    sent.push(payload)
  })
  assert_true(report.has_failures(deny_warnings=true))
  assert_eq(sent.length(), 0)
  assert_eq(events, ["audit"])
  assert_true(report.issues.any(issue => issue.code == "A1005"))
}
