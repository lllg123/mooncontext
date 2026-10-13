///|
fn sample_policy() -> @git.Policy {
  {
    repo_root: ".",
    revision: "6200a33900f77d99d6766b7c15d308e9c00656e3",
    bundle: {
      allowed_root: "examples/release_gate/fixtures",
      text_policy: @audit.Policy::with_forbidden(
        char_budget=1200,
        required_markers=[],
        forbidden_markers=["sk-"],
      ),
      deny_warnings: true,
      required_rules: ["Cite pinned evidence."],
      forbidden_instructions: ["TODO"],
    },
    pins: [
      {
        id: "POLICY",
        path: "examples/release_gate/fixtures/review-policy.md",
        fingerprint: "sha256:0ebc58df932ce43065794d25f55c0137958765ae8e66318bbd3474be7cedb03d",
      },
    ],
  }
}

///|
fn sample_request() -> @git.Request {
  {
    system_rules: "Cite pinned evidence.",
    question: "May the review continue?",
    citations: [
      {
        id: "POLICY",
        excerpt: "An audit failure must stop the request before it reaches the model adapter.",
      },
    ],
  }
}

///|
async test "loads an ordinary source blob from an exact commit" {
  let result = @git.approve(sample_request(), sample_policy())
  guard result is Ok(snapshot) else { fail("expected approved Git snapshot") }
  assert_eq(snapshot.revision(), sample_policy().revision)
  assert_true(snapshot.text().contains("## Source POLICY"))
  assert_eq(
    snapshot.report().sources[0].source_fingerprint,
    sample_policy().pins[0].fingerprint,
  )
}

///|
async test "rejects stale pins and paths outside the reviewed root" {
  let stale = sample_policy()
  stale.pins[0] = {
    id: "POLICY",
    path: stale.pins[0].path,
    fingerprint: "sha256:0000000000000000000000000000000000000000000000000000000000000000",
  }
  guard @git.approve(sample_request(), stale)
    is Err(@git.SnapshotFailure::Rejected(report)) else {
    fail("expected stale source fingerprint rejection")
  }
  assert_true(report.findings.any(item => item.code == "G1005"))
  let traversal = sample_policy()
  traversal.pins[0] = {
    id: "POLICY",
    path: "examples/release_gate/fixtures/../private.md",
    fingerprint: sample_policy().pins[0].fingerprint,
  }
  assert_true(
    @git.approve(sample_request(), traversal)
    is Err(@git.SnapshotFailure::InvalidPolicy(_)),
  )
}

///|
async test "rejects an unknown commit and an unpinned citation" {
  let bad_revision = sample_policy()
  let policy : @git.Policy = {
    repo_root: bad_revision.repo_root,
    revision: "0000000000000000000000000000000000000000",
    bundle: bad_revision.bundle,
    pins: bad_revision.pins,
  }
  assert_true(
    @git.approve(sample_request(), policy)
    is Err(@git.SnapshotFailure::SourceUnavailable(_)),
  )
  let request : @git.Request = {
    system_rules: "Cite pinned evidence.",
    question: "May the review continue?",
    citations: [{ id: "UNKNOWN", excerpt: "text", }],
  }
  assert_true(
    @git.approve(request, sample_policy())
    is Err(@git.SnapshotFailure::InvalidPolicy(_)),
  )
}
