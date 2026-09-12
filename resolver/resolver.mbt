///|
priv struct Resolver {
  source_texts : Map[String, String]
  source_ids : Map[String, @diagnostics.SourceId]
  sources : Array[ResolvedSource]
  declarations : Array[@syntax.DeclarationSyntax]
  diagnostics : Array[@diagnostics.Diagnostic]
  visited : Map[String, Bool]
  active_paths : Array[String]
  active_edges : Array[@diagnostics.Span]
}

///|
fn Resolver::add_error(
  self : Resolver,
  code : String,
  message : String,
  primary : @diagnostics.Span,
  labels? : Array[@diagnostics.Label] = [],
  help? : String,
) -> Unit {
  let diagnostic = match help {
    Some(value) =>
      @diagnostics.Diagnostic::new(
        @diagnostics.Severity::Error,
        code~,
        message~,
        primary~,
        labels~,
        help=value,
      )
    None =>
      @diagnostics.Diagnostic::new(
        @diagnostics.Severity::Error,
        code~,
        message~,
        primary~,
        labels~,
      )
  }
  self.diagnostics.push(diagnostic)
}

///|
fn Resolver::discover_source(
  self : Resolver,
  path : String,
  text : String,
) -> @diagnostics.SourceId {
  if self.source_ids.contains(path) {
    self.source_ids[path]
  } else {
    let id = @diagnostics.SourceId::{ value: self.sources.length(), }
    self.source_ids[path] = id
    self.sources.push({ id, path, text, })
    id
  }
}

///|
fn Resolver::cycle_labels(self : Resolver) -> Array[@diagnostics.Label] {
  self.active_edges.map(span => {
    @diagnostics.Label::new(span, "include edge in this cycle")
  })
}

///|
fn Resolver::resolve_include(
  self : Resolver,
  containing_path : String,
  include_decl : @syntax.IncludeDecl,
) -> Unit {
  let base = parent_path(containing_path)
  guard normalize_relative_path(base, include_decl.path.value) is Some(path) else {
    self.add_error(
      "E3003",
      "include path is absolute or escapes the compilation root",
      include_decl.path.span,
      help="use a relative path that remains inside the compilation root",
    )
    return
  }
  if self.active_paths.any(active => active == path) {
    self.add_error(
      "E3002",
      "include cycle detected through `\{path}`",
      include_decl.path.span,
      labels=self.cycle_labels(),
      help="remove one include edge from the cycle",
    )
    return
  }
  if self.visited.contains(path) {
    self.add_error(
      "E3004",
      "source `\{path}` is included more than once",
      include_decl.path.span,
    )
    return
  }
  if !self.source_texts.contains(path) {
    self.add_error(
      "E3001",
      "included source `\{path}` was not found",
      include_decl.path.span,
    )
    return
  }
  self.active_edges.push(include_decl.path.span)
  self.resolve_file(path, self.source_texts[path])
  ignore(self.active_edges.pop())
}

///|
fn Resolver::resolve_file(
  self : Resolver,
  path : String,
  text : String,
) -> Unit {
  self.visited[path] = true
  self.active_paths.push(path)
  let source = self.discover_source(path, text)
  let parsed = @syntax.parse(source, text)
  for diagnostic in parsed.diagnostics {
    self.diagnostics.push(diagnostic)
  }
  if parsed.diagnostics.length() == 0 {
    for declaration in parsed.document.declarations {
      match declaration {
        Include(include_decl) => self.resolve_include(path, include_decl)
        value => self.declarations.push(value)
      }
    }
  }
  ignore(self.active_paths.pop())
}

///|
fn build_source_table(inputs : Array[SourceInput]) -> Map[String, String] {
  let sources : Map[String, String] = Map([])
  for input in inputs {
    match normalize_relative_path("", input.path) {
      Some(path) => if !sources.contains(path) { sources[path] = input.text }
      None => ()
    }
  }
  sources
}

///|
/// Resolve includes depth-first at their declaration position.
///
/// Source inputs are addressed relative to the compilation root. Resolution
/// rejects absolute and escaping paths, missing files, cycles, and repeated
/// inclusion after normalization.
///
/// ```mbt check
/// test {
///   let root = "context \"demo\"; include \"shared.ctx\";"
///   let shared = "let mode = \"review\";"
///   let result = resolve("root.ctx", [
///     { path: "root.ctx", text: root, },
///     { path: "shared.ctx", text: shared, },
///   ])
///   assert_eq(result.diagnostics.length(), 0)
///   assert_eq(result.document.declarations.length(), 2)
/// }
/// ```
pub fn resolve(
  entry_path : String,
  inputs : Array[SourceInput],
) -> ResolveResult {
  let resolver = Resolver::{
    source_texts: build_source_table(inputs),
    source_ids: Map([]),
    sources: [],
    declarations: [],
    diagnostics: [],
    visited: Map([]),
    active_paths: [],
    active_edges: [],
  }
  match normalize_relative_path("", entry_path) {
    None =>
      resolver.add_error(
        "E3003",
        "root path is absolute or escapes the compilation root",
        @diagnostics.Span::new(
          @diagnostics.SourceId::{ value: 0, },
          start=0,
          end=0,
        ),
      )
    Some(path) =>
      if resolver.source_texts.contains(path) {
        resolver.resolve_file(path, resolver.source_texts[path])
      } else {
        resolver.add_error(
          "E3001",
          "root source `\{path}` was not found",
          @diagnostics.Span::new(
            @diagnostics.SourceId::{ value: 0, },
            start=0,
            end=0,
          ),
        )
      }
  }
  {
    document: {
      declarations: resolver.declarations,
      sources: resolver.sources,
    },
    diagnostics: resolver.diagnostics,
  }
}
