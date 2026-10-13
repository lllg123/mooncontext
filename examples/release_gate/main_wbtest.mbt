///|
test "pinned review example sends only the approved final payload" {
  let review = "# Review policy\n\nEvery model request must use evidence from a pinned source snapshot.\nAn audit failure must stop the request before it reaches the model adapter.\n"
  let patch = "diff --git a/src/review.mbt b/src/review.mbt\n@@ -1,2 +1,4 @@\n+  let report = audit(final_context, policy)\n+  if report.has_failures(deny_warnings=true) { return }\n   send_to_model(final_context)\n"
  let request = build_request(review, patch, "pass")
  assert_eq(
    @audit.fingerprint(review),
    request.evidence[0].expected_fingerprint,
  )
  assert_eq(@audit.fingerprint(patch), request.evidence[1].expected_fingerprint)
  guard @gate.approve(request, release_policy()) is Ok(approved) else {
    fail("expected approved context")
  }
  let delivered : Array[String] = []
  approved.deliver(payload => delivered.push(payload))
  assert_eq(delivered.length(), 1)
  assert_eq(
    @audit.fingerprint(delivered[0]),
    approved.report().audit.fingerprint,
  )
  for mode in ["stale", "unsafe", "leak"] {
    assert_true(
      @gate.approve(build_request(review, patch, mode), release_policy())
      is Err(_),
    )
  }
}
