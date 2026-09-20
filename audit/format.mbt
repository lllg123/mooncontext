///|
fn severity_name(severity : Severity) -> String {
  match severity {
    Error => "error"
    Warning => "warning"
  }
}

///|
/// Format a stable human-readable report suitable for CI logs.
pub fn format_report(path : String, report : Report) -> String {
  let output = StringBuilder()
  output.write_string("audit: \{path}\n")
  output.write_string("fingerprint: \{report.fingerprint}\n")
  output.write_string("characters: \{report.character_count}\n")
  output.write_string("headings: \{report.heading_count}\n")
  output.write_string("issues: \{report.issues.length()}\n")
  for issue in report.issues {
    output.write_string(
      "\{severity_name(issue.severity)} \{issue.code} \{path}:\{issue.line}:\{issue.column}: \{issue.message}\n",
    )
  }
  if report.issues.length() == 0 {
    output.write_string("status: ok\n")
  } else if report.has_errors() {
    output.write_string("status: failed\n")
  } else {
    output.write_string("status: warnings\n")
  }
  output.to_string()
}
