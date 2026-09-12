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
