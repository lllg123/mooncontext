///|
extern "C" fn release_exit(code : Int) -> Unit = "exit"

///|
/// Stand-in for the output of an application's existing prompt renderer.
fn render_context(review_id : String, evidence : String) -> String {
  "# System rules\nReview the claim against the evidence.\n\n## Evidence\nReview \{review_id}: \{evidence}\n"
}

///|
fn release_policy() -> @audit.Policy {
  @audit.Policy::with_forbidden(
    char_budget=500,
    required_markers=["System rules", "Evidence"],
    forbidden_markers=["sk-", "TODO"],
  )
}

///|
/// The callback receives exactly the bytes that were audited, only on success.
fn release_if_approved(
  rendered : String,
  record_audit : (@audit.Report) -> Unit,
  send_to_model : (String) -> Unit,
) -> @audit.Report {
  let report = @audit.audit(rendered, release_policy())
  record_audit(report)
  if !report.has_failures(deny_warnings=true) {
    send_to_model(rendered)
  }
  report
}

///|
fn main {
  let arguments = @env.args()
  if arguments.length() != 2 ||
    (arguments[1] != "pass" && arguments[1] != "reject") {
    println("usage: moon run examples/release_gate -- pass|reject")
    release_exit(2)
    return
  }
  let reject = arguments[1] == "reject"
  let evidence = if reject {
    "TODO: replace temporary key sk-example before release."
  } else {
    "The change is covered by review evidence."
  }
  let final_context = render_context("PR-42", evidence)
  let report = release_if_approved(
    final_context,
    report => println(@audit.format_report("final-context", report)),
    _context => println("MODEL_CALL: mock API received the approved context"),
  )
  if report.has_failures(deny_warnings=true) {
    println("BLOCKED: final context was not sent to the model")
    release_exit(1)
  }
}
