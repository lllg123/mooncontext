///|
test "locates a single-line character range" {
  let sources = @diagnostics.SourceMap::new()
  let source = sources.add("prompts/one.ctx", "alpha beta")
  let span = @diagnostics.Span::new(source, start=6, end=10)
  guard sources.locate(span) is Some(location) else {
    fail("expected a valid location")
  }
  assert_eq(location.path, "prompts/one.ctx")
  assert_eq(location.start, { line: 1, column: 7, })
  assert_eq(location.end, { line: 1, column: 11, })
}

///|
test "normalizes and locates a multi-line Unicode range" {
  let sources = @diagnostics.SourceMap::new()
  let source = sources.add("prompts/multi.ctx", "first\r\n中间\rlast")
  assert_eq(sources.text(source), Some("first\n中间\nlast"))
  let span = @diagnostics.Span::new(source, start=6, end=11)
  guard sources.locate(span) is Some(location) else {
    fail("expected a valid location")
  }
  assert_eq(location.start, { line: 2, column: 1, })
  assert_eq(location.end, { line: 3, column: 3, })
}

///|
test "accepts empty-file EOF spans and rejects invalid ranges" {
  let sources = @diagnostics.SourceMap::new()
  let empty_source = sources.add("empty.ctx", "")
  guard sources.locate(@diagnostics.Span::new(empty_source, start=0, end=0))
    is Some(location) else {
    fail("expected the empty-file EOF position to be valid")
  }
  assert_eq(location.start, { line: 1, column: 1, })
  assert_eq(location.end, { line: 1, column: 1, })

  let source = sources.add("unicode.ctx", "🙂x")
  guard sources.locate(@diagnostics.Span::new(source, start=1, end=2))
    is Some(unicode_location) else {
    fail("expected a Unicode scalar range to be valid")
  }
  assert_eq(unicode_location.start, { line: 1, column: 2, })
  assert_eq(unicode_location.end, { line: 1, column: 3, })

  assert_true(
    sources.locate(@diagnostics.Span::new(source, start=-1, end=0)) is None,
  )
  assert_true(
    sources.locate(@diagnostics.Span::new(source, start=2, end=1)) is None,
  )
  assert_true(
    sources.locate(@diagnostics.Span::new(source, start=0, end=3)) is None,
  )
  assert_true(
    sources.locate(
      @diagnostics.Span::new(
        @diagnostics.SourceId::{ value: 99, },
        start=0,
        end=0,
      ),
    )
    is None,
  )
}

///|
test "formats an error with a single-line label and help" {
  let sources = @diagnostics.SourceMap::new()
  let source = sources.add("prompts/main.ctx", "let value = \"ok\";")
  let primary = @diagnostics.Span::new(source, start=4, end=9)
  let diagnostic = @diagnostics.Diagnostic::new(
    @diagnostics.Severity::Error,
    code="E4002",
    message="undefined variable `value`",
    primary~,
    labels=[@diagnostics.Label::new(primary, "not declared")],
    help="declare `value` before use",
  )
  inspect(
    sources.format(diagnostic),
    content=(
      #|error[E4002]: undefined variable `value`
      #|  --> prompts/main.ctx:1:5
      #|  |
      #|1 | let value = "ok";
      #|  |     ^^^^^ not declared
      #|   |
      #|   = help: declare `value` before use
      #|
    ),
  )
}

///|
test "formats a range spanning multiple lines" {
  let sources = @diagnostics.SourceMap::new()
  let source = sources.add("prompts/multi.ctx", "alpha\nbeta\ngamma")
  let primary = @diagnostics.Span::new(source, start=3, end=13)
  let diagnostic = @diagnostics.Diagnostic::new(
    @diagnostics.Severity::Warning,
    code="W6001",
    message="unused declaration",
    primary~,
  )
  inspect(
    sources.format(diagnostic),
    content=(
      #|warning[W6001]: unused declaration
      #|  --> prompts/multi.ctx:1:4
      #|  |
      #|1 | alpha
      #|  |    ^^
      #|2 | beta
      #|  | ^^^^
      #|3 | gamma
      #|  | ^^
      #|
    ),
  )
}
