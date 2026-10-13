///|
fn valid_revision(revision : String) -> Bool {
  if revision.length() != 40 {
    return false
  }
  for ch in revision {
    if !((ch >= '0' && ch <= '9') || (ch >= 'a' && ch <= 'f')) {
      return false
    }
  }
  true
}

///|
async fn git_output(
  root : String,
  arguments : Array[String],
) -> Result[String, SnapshotFailure] {
  let args = ["-C", root, "-c", "core.quotePath=false"]
  for argument in arguments {
    args.push(argument)
  }
  let (status, output) = @process.collect_stdout("git", args) catch {
    _ =>
      return Err(
        SourceUnavailable("cannot start Git for the pinned repository"),
      )
  }
  if status != 0 {
    Err(SourceUnavailable("Git could not read the pinned repository snapshot"))
  } else {
    Ok(output.text())
  }
}

///|
fn find_pin(pins : Array[SourcePin], id : String) -> SourcePin? {
  for pin in pins {
    if pin.id == id {
      return Some(pin)
    }
  }
  None
}

///|
/// Read ordinary files from the exact Git commit, never from a mutable worktree.
/// The reviewed policy owns source paths and digests. No shell is invoked.
pub async fn approve(
  request : Request,
  policy : Policy,
) -> Result[ApprovedSnapshot, SnapshotFailure] {
  if policy.repo_root == "" || !valid_revision(policy.revision) {
    return Err(InvalidPolicy("repository root and full commit ID are required"))
  }
  if policy.pins.length() == 0 ||
    request.citations.length() != policy.pins.length() {
    return Err(
      InvalidPolicy("each pinned source requires exactly one citation"),
    )
  }
  let pin_ids : Map[String, Bool] = Map([])
  for pin in policy.pins {
    if pin.id == "" ||
      pin_ids.contains(pin.id) ||
      !@gate.source_path_is_allowed(policy.bundle.allowed_root, pin.path) ||
      !pin.fingerprint.has_prefix("sha256:") ||
      pin.fingerprint.length() != 71 {
      return Err(InvalidPolicy("invalid or duplicate source pin"))
    }
    pin_ids[pin.id] = true
  }
  let kind = git_output(policy.repo_root, ["cat-file", "-t", policy.revision])
  guard kind is Ok("commit\n") else {
    return Err(SourceUnavailable("pinned revision is not a Git commit"))
  }
  let seen : Map[String, Bool] = Map([])
  let evidence : Array[@gate.Evidence] = []
  for citation in request.citations {
    if seen.contains(citation.id) {
      return Err(InvalidPolicy("duplicate citation ID"))
    }
    seen[citation.id] = true
    guard find_pin(policy.pins, citation.id) is Some(pin) else {
      return Err(InvalidPolicy("citation has no reviewed source pin"))
    }
    let listing = git_output(policy.repo_root, [
      "ls-tree",
      "--full-tree",
      policy.revision,
      "--",
      pin.path,
    ])
    guard listing is Ok(line) &&
      (line.has_prefix("100644 blob ") || line.has_prefix("100755 blob ")) &&
      line.has_suffix("\t" + pin.path + "\n") else {
      return Err(SourceUnavailable("pinned path is not an ordinary Git file"))
    }
    let source = git_output(policy.repo_root, [
      "show",
      "\{policy.revision}:\{pin.path}",
    ])
    guard source is Ok(source_text) else {
      return Err(SourceUnavailable("cannot read pinned Git file"))
    }
    evidence.push({
      id: pin.id,
      path: pin.path,
      source_text,
      excerpt: citation.excerpt,
      expected_fingerprint: pin.fingerprint,
    })
  }
  let bundle : @gate.Request = {
    system_rules: request.system_rules,
    question: request.question,
    evidence,
  }
  match @gate.approve(bundle, policy.bundle) {
    Ok(context) => Ok({ context, revision: policy.revision, })
    Err(report) => Err(Rejected(report))
  }
}
