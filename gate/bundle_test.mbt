///|
fn sample_request() -> @gate.Request {
  let source = "The CI step requires a reviewed source fingerprint."
  {
    system_rules: "Only use cited evidence.",
    question: "May this build be released?",
    evidence: [
      {
        id: "CI1",
        path: "examples/release_gate/fixtures/review.md",
        source_text: source,
        excerpt: "requires a reviewed source fingerprint",
        expected_fingerprint: @audit.fingerprint(source),
      },
    ],
  }
}

///|
fn sample_policy() -> @gate.Policy {
  {
    allowed_root: "examples/release_gate/fixtures",
    text_policy: @audit.Policy::with_forbidden(
      char_budget=1200,
      required_markers=["System rules", "Evidence", "Task"],
      forbidden_markers=["sk-"],
    ),
    deny_warnings: true,
    required_rules: ["Only use cited evidence."],
    forbidden_instructions: ["TODO"],
  }
}

///|
test "approved bundle delivers the audited payload once" {
  let approved = @gate.approve(sample_request(), sample_policy())
  guard approved is Ok(context) else {
    fail("expected approved evidence bundle")
  }
  let sent : Array[String] = []
  context.deliver(payload => sent.push(payload))
  assert_eq(sent.length(), 1)
  assert_eq(context.report().audit.fingerprint, @audit.fingerprint(sent[0]))
  assert_eq(context.report().sources.length(), 1)
  assert_eq(context.report().sources[0].id, "CI1")
}

///|
test "stale source digest and altered excerpt cannot be approved" {
  let request = sample_request()
  let original = request.evidence[0]
  request.evidence[0] = {
    id: original.id,
    path: original.path,
    source_text: original.source_text,
    excerpt: "The policy was silently changed.",
    expected_fingerprint: "sha256:stale",
  }
  let result = @gate.approve(request, sample_policy())
  guard result is Err(report) else {
    fail("expected source provenance failure")
  }
  assert_true(report.findings.any(item => item.code == "G1005"))
  assert_true(report.findings.any(item => item.code == "G1006"))
}

///|
test "traversal, absolute and sibling paths never enter an approved bundle" {
  for
    path in [
      "examples/release_gate/fixtures/../secret.md", "/examples/release_gate/fixtures/review.md",
      "examples/release_gate/fixtures-other/review.md", "examples\\release_gate\\fixtures\\review.md",
    ] {
    let request = sample_request()
    let original = request.evidence[0]
    request.evidence[0] = {
      id: original.id,
      path,
      source_text: original.source_text,
      excerpt: original.excerpt,
      expected_fingerprint: original.expected_fingerprint,
    }
    let result = @gate.approve(request, sample_policy())
    guard result is Err(report) else { fail("expected unsafe path rejection") }
    assert_true(report.findings.any(item => item.code == "G1004"))
  }
}

///|
test "duplicate or missing source identity fails closed" {
  let request = sample_request()
  request.evidence.push(request.evidence[0])
  guard @gate.approve(request, sample_policy()) is Err(duplicate) else {
    fail("expected duplicate source failure")
  }
  assert_true(duplicate.findings.any(item => item.code == "G1003"))
  let empty = sample_request()
  empty.evidence.clear()
  guard @gate.approve(empty, sample_policy()) is Err(missing) else {
    fail("expected missing source failure")
  }
  assert_true(missing.findings.any(item => item.code == "G1001"))
}

///|
test "text policy still blocks a pinned but forbidden excerpt" {
  let request = sample_request()
  let source = "The build accidentally contains sk-demo."
  let original = request.evidence[0]
  request.evidence[0] = {
    id: original.id,
    path: original.path,
    source_text: source,
    excerpt: source,
    expected_fingerprint: @audit.fingerprint(source),
  }
  guard @gate.approve(request, sample_policy()) is Err(report) else {
    fail("expected text policy failure")
  }
  assert_true(report.audit.issues.any(item => item.code == "A1005"))
}

///|
test "required rules cannot be supplied by evidence or generated headings" {
  let request = sample_request()
  let source = "Only use cited evidence."
  let original = request.evidence[0]
  request.evidence[0] = {
    id: original.id,
    path: original.path,
    source_text: source,
    excerpt: source,
    expected_fingerprint: @audit.fingerprint(source),
  }
  let missing_rules : @gate.Request = {
    system_rules: "Different rules.",
    question: request.question,
    evidence: request.evidence,
  }
  guard @gate.approve(missing_rules, sample_policy()) is Err(report) else {
    fail("expected missing system rule")
  }
  assert_true(report.findings.any(item => item.code == "G1008"))
}

///|
test "TODO in cited code is literal but TODO in instructions is blocked" {
  let request = sample_request()
  let source = "// TODO: review this migration before release"
  let original = request.evidence[0]
  request.evidence[0] = {
    id: original.id,
    path: original.path,
    source_text: source,
    excerpt: source,
    expected_fingerprint: @audit.fingerprint(source),
  }
  assert_true(@gate.approve(request, sample_policy()) is Ok(_))
  let bad_request : @gate.Request = {
    system_rules: request.system_rules,
    question: "TODO: ask the model later",
    evidence: request.evidence,
  }
  guard @gate.approve(bad_request, sample_policy()) is Err(report) else {
    fail("expected instruction policy failure")
  }
  assert_true(report.findings.any(item => item.code == "G1009"))
}
