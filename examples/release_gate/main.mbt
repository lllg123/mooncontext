///|
extern "C" fn release_exit(code : Int) -> Unit = "exit"

///|
fn release_policy() -> @gate.Policy {
  {
    allowed_root: "examples/release_gate/fixtures",
    text_policy: @audit.Policy::with_forbidden(
      char_budget=1200,
      required_markers=["System rules", "Evidence", "Task"],
      forbidden_markers=["sk-", "TODO"],
    ),
    deny_warnings: true,
  }
}

///|
fn build_request(
  review : String,
  patch : String,
  mode : String,
) -> @gate.Request {
  let review_path = if mode == "unsafe" {
    "examples/release_gate/fixtures/../private.md"
  } else {
    "examples/release_gate/fixtures/review-policy.md"
  }
  let review_text = if mode == "stale" {
    review + "\nUnreviewed change."
  } else {
    review
  }
  let question = if mode == "leak" {
    "TODO: send sk-example to the model."
  } else {
    "Is this change safe to send to the model? Cite POLICY and PATCH."
  }
  {
    system_rules: "Answer using only the supplied, pinned evidence.",
    question,
    evidence: [
      {
        id: "POLICY",
        path: review_path,
        source_text: review_text,
        excerpt: "An audit failure must stop the request before it reaches the model adapter.",
        expected_fingerprint: "sha256:0ebc58df932ce43065794d25f55c0137958765ae8e66318bbd3474be7cedb03d",
      },
      {
        id: "PATCH",
        path: "examples/release_gate/fixtures/change.diff",
        source_text: patch,
        excerpt: "+  if report.has_failures(deny_warnings=true) { return }",
        expected_fingerprint: "sha256:17fcf282a9ad753113780478bf67c80a4eb5818e5b5e345bc0c04b28782b9a8b",
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
/// Run from the repository root: moon run examples/release_gate -- pass
async fn main {
  let args = @env.args()
  let mode = if args.length() > 1 { args[1] } else { "pass" }
  if mode != "pass" && mode != "stale" && mode != "unsafe" && mode != "leak" {
    println("Usage: moon run examples/release_gate -- [pass|stale|unsafe|leak]")
    release_exit(2)
    return
  }
  let review = @fs.read_file("examples/release_gate/fixtures/review-policy.md").text() catch {
    error => {
      println("Cannot read review policy: \{error}")
      release_exit(2)
      return
    }
  }
  let patch = @fs.read_file("examples/release_gate/fixtures/change.diff").text() catch {
    error => {
      println("Cannot read change diff: \{error}")
      release_exit(2)
      return
    }
  }
  match @gate.approve(build_request(review, patch, mode), release_policy()) {
    Ok(approved) => {
      print_gate_report(approved.report())
      approved.deliver(payload => {
        println("MODEL_CALL: \{payload.length()} audited characters")
      })
    }
    Err(report) => {
      print_gate_report(report)
      println("BLOCKED: model adapter was not called")
      release_exit(1)
    }
  }
}
