///|
/// One UTF-8 context source supplied by an injected in-memory provider.
pub(all) struct SourceInput {
  path : String
  text : String
} derive(Debug, Eq)

///|
/// A source discovered during depth-first include resolution.
pub(all) struct ResolvedSource {
  id : @diagnostics.SourceId
  path : String
  text : String
} derive(Debug, Eq)

///|
/// Include-free declarations and their first-discovery source table.
pub(all) struct ResolvedDocument {
  declarations : Array[@syntax.DeclarationSyntax]
  sources : Array[ResolvedSource]
} derive(Debug, Eq)

///|
/// Result of resolving a root source and all of its includes.
pub(all) struct ResolveResult {
  document : ResolvedDocument
  diagnostics : Array[@diagnostics.Diagnostic]
} derive(Debug)
