///|
test "fingerprints standard SHA-256 vectors" {
  inspect(
    @audit.fingerprint(""),
    content="sha256:e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855",
  )
  inspect(
    @audit.fingerprint("abc"),
    content="sha256:ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad",
  )
  inspect(
    @audit.fingerprint(
      "abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq",
    ),
    content="sha256:248d6a61d20638b8e5c026930c3e6039a33ce45964ff2167f6ecedd419db06c1",
  )
}

///|
test "fingerprints exact artifact bytes" {
  let without_newline = @audit.fingerprint("context")
  let with_newline = @audit.fingerprint("context\n")
  assert_not_eq(without_newline, with_newline)
  let first_report = @audit.audit(
    "context\n",
    @audit.Policy::new(char_budget=100, required_markers=[]),
  )
  let second_report = @audit.audit(
    "context\n",
    @audit.Policy::new(char_budget=1, required_markers=["missing"]),
  )
  assert_eq(first_report.fingerprint, with_newline)
  assert_eq(second_report.fingerprint, with_newline)
  assert_true(second_report.has_errors())
  assert_true(
    @audit.format_report("context.md", first_report).contains(
      "fingerprint: \{with_newline}",
    ),
  )
}
