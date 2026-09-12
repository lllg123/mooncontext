///|
/// Identifies whether declarations came from the compilation root or an
/// included source file.
pub(all) enum SourceKind {
  Root
  Included
} derive(Debug, Eq)

///|
/// Diagnostics produced while validating a parsed context document.
pub(all) struct ValidationResult {
  diagnostics : Array[@diagnostics.Diagnostic]
} derive(Debug)
