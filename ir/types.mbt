///|
/// Output representation selected by the root context configuration.
pub(all) enum OutputFormat {
  Markdown
  PlainText
} derive(Debug, Eq)

///|
/// Evaluated section content without parser-specific wrappers.
pub(all) enum Content {
  Inline(String)
  File(String)
} derive(Debug, Eq)

///|
/// A half-open range in canonical content traced to its source declaration.
pub(all) struct ProvenanceSegment {
  content_start : Int
  content_end : Int
  source : @diagnostics.Span
} derive(Debug, Eq)

///|
/// One active, evaluated section in deterministic source order.
pub(all) struct Section {
  name : String
  content : Content
  source_ordinal : Int
  priority : Int
  required : Bool
  provenance : Array[ProvenanceSegment]
} derive(Debug, Eq)

///|
/// Canonical context representation consumed by planning and rendering.
pub(all) struct Context {
  identity : String
  output : OutputFormat
  char_budget : Int
  sections : Array[Section]
} derive(Debug, Eq)
