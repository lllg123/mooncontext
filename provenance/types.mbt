///|
/// Normalized source identity and path recorded in build outputs.
pub(all) struct SourceFile {
  id : @diagnostics.SourceId
  path : String
} derive(Debug, Eq)

///|
/// Map a half-open rendered character range back to its source span.
pub(all) struct SourceMapping {
  section_id : String
  generated_start : Int
  generated_end : Int
  source : @diagnostics.Span
} derive(Debug, Eq)

///|
/// Source files and ordered provenance ranges for one emitted artifact.
pub(all) struct SourceMap {
  files : Array[SourceFile]
  mappings : Array[SourceMapping]
} derive(Debug, Eq)

///|
/// Deterministic summary of the inputs, budget decision, and diagnostics.
pub(all) struct BuildManifest {
  context_identity : String
  inputs : Array[SourceFile]
  output : @ir.OutputFormat
  char_budget : Int
  selection : @ir.SelectionPlan?
  diagnostics : Array[@diagnostics.Diagnostic]
} derive(Debug)

///|
/// Artifact and its provenance metadata, or metadata for a failed build.
pub(all) struct BuildOutput {
  artifact : String?
  source_map : SourceMap
  manifest : BuildManifest
} derive(Debug)
