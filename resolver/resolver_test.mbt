///|
fn source(path : String, text : String) -> @resolver.SourceInput {
  { path, text, }
}

///|
fn diagnostic_codes(result : @resolver.ResolveResult) -> Array[String] {
  result.diagnostics.map(diagnostic => diagnostic.code)
}

///|
test "expands nested includes in depth-first declaration order" {
  let root =
    #|context "demo";
    #|include "./shared/base.ctx";
    #|section "root" { text = "root"; }
  let base =
    #|let mode = "review";
    #|include "../parts/rules.ctx";
    #|section "shared" { text = "shared"; }
  let rules =
    #|section "rules" { text = "rules"; }
  let result = @resolver.resolve("root.ctx", [
    source("parts/rules.ctx", rules),
    source("root.ctx", root),
    source("shared/base.ctx", base),
  ])
  assert_eq(result.diagnostics.length(), 0)
  assert_eq(result.document.declarations.length(), 5)
  guard result.document.declarations
    is [
      @syntax.DeclarationSyntax::Context(_),
      @syntax.DeclarationSyntax::Let(_),
      @syntax.DeclarationSyntax::Section(rules_section),
      @syntax.DeclarationSyntax::Section(shared_section),
      @syntax.DeclarationSyntax::Section(root_section),
    ] else {
    fail("expected depth-first declaration expansion")
  }
  assert_eq(rules_section.name.value, "rules")
  assert_eq(shared_section.name.value, "shared")
  assert_eq(root_section.name.value, "root")
  assert_eq(result.document.sources.map(item => item.path), [
    "root.ctx", "shared/base.ctx", "parts/rules.ctx",
  ])
}

///|
async test "loads only the transitive include graph through a provider" {
  let files : Map[String, String] = {
    "root.ctx": "context \"demo\"; include \"shared/base.ctx\";",
    "shared/base.ctx": "include \"nested/rules.ctx\";",
    "shared/nested/rules.ctx": "section \"rules\" { text = \"ok\"; }",
    "unused.ctx": "section \"unused\" { text = \"unused\"; }",
  }
  let requested : Array[String] = []
  let result = @resolver.resolve_with_provider("root.ctx", path => {
    requested.push(path)
    files.get(path)
  })
  assert_eq(result.diagnostics.length(), 0)
  assert_eq(result.document.sources.map(source => source.path), [
    "root.ctx", "shared/base.ctx", "shared/nested/rules.ctx",
  ])
  assert_eq(requested, [
    "root.ctx", "shared/base.ctx", "shared/nested/rules.ctx",
  ])
}

///|
test "reports a missing included source" {
  let root =
    #|context "missing";
    #|include "shared/missing.ctx";
  let result = @resolver.resolve("root.ctx", [source("root.ctx", root)])
  assert_eq(diagnostic_codes(result), ["E3001"])
}

///|
test "rejects absolute and escaping include paths" {
  let root =
    #|context "unsafe";
    #|include "../outside.ctx";
    #|include "C:\\device.ctx";
  let result = @resolver.resolve("root.ctx", [source("root.ctx", root)])
  assert_eq(diagnostic_codes(result), ["E3003", "E3003"])
}

///|
test "rejects expansion and device include paths" {
  let root =
    #|context "unsafe";
    #|include "$HOME/shared.ctx";
    #|include "%TEMP%/shared.ctx";
    #|include "NUL.ctx";
    #|include "shared/CoM1.txt";
    #|include "shared/[draft].ctx";
    #|include "shared/name.";
  let result = @resolver.resolve("root.ctx", [source("root.ctx", root)])
  assert_eq(diagnostic_codes(result), [
    "E3003", "E3003", "E3003", "E3003", "E3003", "E3003",
  ])
}

///|
test "normalizes safe file content paths relative to their source" {
  let root =
    #|context "content";
    #|include "shared/base.ctx";
  let shared =
    #|section "body" { file = "../content/./prompt.txt"; }
  let result = @resolver.resolve("root.ctx", [
    source("root.ctx", root),
    source("shared/base.ctx", shared),
  ])
  assert_eq(result.diagnostics.length(), 0)
  guard result.document.declarations[1]
    is @syntax.DeclarationSyntax::Section(
      { contents: [@syntax.SectionContentSyntax::File(path, _)], .. }
    ) else {
    fail("expected one file-backed section")
  }
  assert_eq(path.value, "content/prompt.txt")
}

///|
test "rejects file content paths outside the compilation root" {
  let root =
    #|context "content";
    #|include "shared/base.ctx";
  let shared =
    #|section "body" { file = "../../secret.txt"; }
  let result = @resolver.resolve("root.ctx", [
    source("root.ctx", root),
    source("shared/base.ctx", shared),
  ])
  assert_eq(diagnostic_codes(result), ["E3003"])
  assert_eq(result.document.declarations.length(), 1)
}

///|
test "uses the entry directory as the default compilation root" {
  let root =
    #|context "nested";
    #|include "../outside.ctx";
    #|section "body" { file = "../secret.txt"; }
  let result = @resolver.resolve("project/root.ctx", [
    source("project/root.ctx", root),
    source("outside.ctx", "let leaked = \"yes\";"),
  ])
  assert_eq(diagnostic_codes(result), ["E3003", "E3003"])
  assert_eq(result.document.declarations.length(), 1)
}

///|
test "detects an include cycle before repeated inclusion" {
  let root =
    #|context "cycle";
    #|include "a.ctx";
  let a =
    #|include "nested/b.ctx";
  let b =
    #|include "../root.ctx";
  let result = @resolver.resolve("root.ctx", [
    source("root.ctx", root),
    source("a.ctx", a),
    source("nested/b.ctx", b),
  ])
  assert_eq(diagnostic_codes(result), ["E3002"])
  assert_eq(result.diagnostics[0].labels.length(), 2)
}

///|
test "detects repeated includes after path normalization" {
  let root =
    #|context "repeat";
    #|include "shared/./base.ctx";
    #|include "shared/base.ctx";
  let result = @resolver.resolve("root.ctx", [
    source("root.ctx", root),
    source("shared/base.ctx", "let x = \"y\";"),
  ])
  assert_eq(diagnostic_codes(result), ["E3004"])
}

///|
test "retains parser diagnostics and stops expanding that source" {
  let root =
    #|context "broken"
    #|include "ignored.ctx";
  let result = @resolver.resolve("root.ctx", [
    source("root.ctx", root),
    source("ignored.ctx", "let x = \"y\";"),
  ])
  assert_true(result.diagnostics.length() > 0)
  assert_eq(result.document.sources.length(), 1)
  assert_eq(result.document.declarations.length(), 0)
}
