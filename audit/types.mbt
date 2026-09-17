///|
/// Severity assigned to a context audit issue.
pub(all) enum Severity {
  Error
  Warning
} derive(Debug, Eq)

///|
/// One deterministic issue found while auditing a rendered context.
pub(all) struct Issue {
  severity : Severity
  code : String
  message : String
  line : Int
  column : Int
} derive(Debug, Eq)

///|
/// Policy applied to an existing Markdown or plain-text context artifact.
pub(all) struct Policy {
  char_budget : Int
  required_markers : Array[String]
} derive(Debug, Eq)

///|
/// Result of auditing one context artifact.
pub(all) struct Report {
  character_count : Int
  heading_count : Int
  issues : Array[Issue]
} derive(Debug, Eq)

///|
/// Create a policy for a bounded context artifact.
pub fn Policy::new(
  char_budget~ : Int,
  required_markers~ : Array[String],
) -> Policy {
  { char_budget, required_markers, }
}

///|
/// Return whether the report contains an error.
pub fn Report::has_errors(self : Report) -> Bool {
  self.issues.any(issue => issue.severity == Severity::Error)
}
