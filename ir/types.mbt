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

///|
/// Stable reason why an active section was left out of a selection plan.
pub(all) enum OmissionReason {
  BudgetLimit
} derive(Debug, Eq)

///|
/// One active section omitted from the final context.
pub(all) struct OmittedSection {
  section_id : String
  reason : OmissionReason
} derive(Debug, Eq)

///|
/// Deterministic budget decision consumed by the renderer.
pub(all) struct SelectionPlan {
  selected_section_ids : Array[String]
  omitted_sections : Array[OmittedSection]
  required_chars : Int
  optional_chars : Int
  total_chars : Int
  remaining_chars : Int
} derive(Debug, Eq)
