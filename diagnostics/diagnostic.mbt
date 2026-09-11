///|
/// Severity of a compiler diagnostic.
pub(all) enum Severity {
  Error
  Warning
} derive(Debug, Eq)

///|
/// Related source range with an explanatory message.
pub(all) struct Label {
  span : Span
  message : String
} derive(Debug, Eq)

///|
/// Create a related diagnostic label.
pub fn Label::new(span : Span, message : String) -> Label {
  { span, message, }
}

///|
/// Structured compiler diagnostic.
pub(all) struct Diagnostic {
  severity : Severity
  code : String
  message : String
  primary : Span
  labels : Array[Label]
  help : String?
} derive(Debug)

///|
/// Create a diagnostic with optional labels and help text.
pub fn Diagnostic::new(
  severity : Severity,
  code~ : String,
  message~ : String,
  primary~ : Span,
  labels? : Array[Label] = [],
  help? : String,
) -> Diagnostic {
  { severity, code, message, primary, labels, help, }
}

///|
fn Severity::name(severity : Severity) -> String {
  match severity {
    Error => "error"
    Warning => "warning"
  }
}
