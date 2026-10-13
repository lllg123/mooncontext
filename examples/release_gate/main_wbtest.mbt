///|
async test "pinned review example approves real Git blobs and blocks unsafe modes" {
  guard @git.approve(snapshot_request("pass"), snapshot_policy("pass"))
    is Ok(snapshot) else {
    fail("expected approved source snapshot")
  }
  assert_eq(
    @audit.fingerprint(snapshot.text()),
    snapshot.report().audit.fingerprint,
  )
  assert_eq(snapshot.report().sources.length(), 2)
  for mode in ["stale", "unsafe", "leak"] {
    assert_true(
      @git.approve(snapshot_request(mode), snapshot_policy(mode)) is Err(_),
    )
  }
}

///|
async test "approved artifact can be written again in an existing build directory" {
  guard @git.approve(snapshot_request("pass"), snapshot_policy("pass"))
    is Ok(snapshot) else {
    fail("expected approved source snapshot")
  }
  assert_true(publish_approved(snapshot))
  assert_true(publish_approved(snapshot))
  assert_true(@fs.exists(release_path))
  assert_true(clear_release_artifact())
  assert_false(@fs.exists(release_path))
}
