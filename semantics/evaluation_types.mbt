///|
/// Explicit variable supplied by the caller, such as a command-line
/// `--define name=value` argument.
pub(all) struct Definition {
  name : String
  value : String
} derive(Debug, Eq)

///|
/// Content retained after conditions and inline interpolation are evaluated.
pub(all) enum EvaluatedContent {
  InlineText(String, @diagnostics.Span)
  FileReference(String, @diagnostics.Span)
} derive(Debug, Eq)

///|
/// Active section with all selection modifiers reduced to concrete values.
pub(all) struct EvaluatedSection {
  name : String
  content : EvaluatedContent
  priority : Int
  required : Bool
  span : @diagnostics.Span
} derive(Debug, Eq)

///|
/// Active sections and diagnostics produced during evaluation.
pub(all) struct EvaluationResult {
  sections : Array[EvaluatedSection]
  diagnostics : Array[@diagnostics.Diagnostic]
} derive(Debug)
