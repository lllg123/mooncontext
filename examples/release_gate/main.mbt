///|
extern "C" fn release_exit(code : Int) -> Unit = "exit"

///|
let release_path : String = "_build/release_gate/approved-context.md"

///|
fn bundle_policy() -> @gate.Policy {
  {
    allowed_root: "examples/release_gate/fixtures",
    text_policy: @audit.Policy::with_forbidden(
      char_budget=1200,
      required_markers=[],
      forbidden_markers=["sk-"],
    ),
    deny_warnings: true,
    required_rules: ["Answer using only the supplied, pinned evidence."],
    forbidden_instructions: ["TODO"],
  }
}

///|
fn snapshot_policy(mode : String) -> @git.Policy {
  let policy_path = if mode == "unsafe" {
    "examples/release_gate/fixtures/../private.md"
  } else {
    "examples/release_gate/fixtures/review-policy.md"
  }
  let policy_fingerprint = if mode == "stale" {
    "sha256:0000000000000000000000000000000000000000000000000000000000000000"
  } else {
    "sha256:0ebc58df932ce43065794d25f55c0137958765ae8e66318bbd3474be7cedb03d"
  }
  {
    repo_root: ".",
    revision: "6200a33900f77d99d6766b7c15d308e9c00656e3",
    bundle: bundle_policy(),
    pins: [
      { id: "POLICY", path: policy_path, fingerprint: policy_fingerprint, },
      {
        id: "PATCH",
        path: "examples/release_gate/fixtures/change.diff",
        fingerprint: "sha256:17fcf282a9ad753113780478bf67c80a4eb5818e5b5e345bc0c04b28782b9a8b",
      },
    ],
  }
}

///|
fn snapshot_request(mode : String) -> @git.Request {
  let question = if mode == "leak" {
    "TODO: send sk-example to the model."
  } else {
    "Is this change safe to send to the model? Cite POLICY and PATCH."
  }
  {
    system_rules: "Answer using only the supplied, pinned evidence.",
    question,
    citations: [
      {
        id: "POLICY",
        excerpt: "An audit failure must stop the request before it reaches the model adapter.",
      },
      {
        id: "PATCH",
        excerpt: "+  if report.has_failures(deny_warnings=true) { return }",
      },
    ],
  }
}

///|
fn print_gate_report(report : @gate.Report) -> Unit {
  println(@audit.format_report("final-context", report.audit))
  for source in report.sources {
    println("SOURCE \{source.id}: \{source.path} \{source.source_fingerprint}")
  }
  for finding in report.findings {
    println("\{finding.code} [\{finding.source_id}]: \{finding.message}")
  }
}

///|
async fn clear_release_artifact() -> Bool {
  try {
    if @fs.exists(release_path) {
      @fs.remove(release_path)
    }
    true
  } catch {
    _ => false
  }
}

///|
async fn publish_approved(snapshot : @git.ApprovedSnapshot) -> Bool {
  try {
    if !@fs.exists("_build/release_gate") {
      @fs.mkdir("_build/release_gate", recursive=true)
    }
    @fs.write_file(
      release_path,
      @utf8.encode(snapshot.text()),
      create_mode=@fs.CreateMode::CreateOrTruncate,
    )
    let stored = @fs.read_file(release_path).text()
    if @audit.fingerprint(stored) != snapshot.report().audit.fingerprint {
      println(
        "ARTIFACT_ERROR: stored fingerprint differs from approved context",
      )
      @fs.remove(release_path)
      return false
    }
    true
  } catch {
    error => {
      println("ARTIFACT_ERROR: \{error}")
      ignore(clear_release_artifact())
      false
    }
  }
}

///|
/// Run from the repository root: moon run examples/release_gate -- pass
async fn main {
  let args = @env.args()
  let mode = if args.length() > 1 { args[1] } else { "pass" }
  if mode != "pass" && mode != "stale" && mode != "unsafe" && mode != "leak" {
    println("Usage: moon run examples/release_gate -- [pass|stale|unsafe|leak]")
    release_exit(2)
    return
  }
  if !clear_release_artifact() {
    println("Cannot clear previous release artifact")
    release_exit(2)
    return
  }
  match @git.approve(snapshot_request(mode), snapshot_policy(mode)) {
    Ok(snapshot) => {
      print_gate_report(snapshot.report())
      if publish_approved(snapshot) {
        println("RELEASE_ARTIFACT: \{release_path}")
      } else {
        println("BLOCKED: approved context could not be written and verified")
        release_exit(2)
      }
    }
    Err(@git.SnapshotFailure::Rejected(report)) => {
      print_gate_report(report)
      println("BLOCKED: no context artifact emitted")
      release_exit(1)
    }
    Err(@git.SnapshotFailure::InvalidPolicy(message)) => {
      println("BLOCKED: \{message}")
      release_exit(1)
    }
    Err(@git.SnapshotFailure::SourceUnavailable(message)) => {
      println("BLOCKED: \{message}")
      release_exit(2)
    }
  }
}
