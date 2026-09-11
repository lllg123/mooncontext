///|
fn source_id() -> @diagnostics.SourceId {
  @diagnostics.SourceId::{ value: 0, }
}

///|
test "tokenizes identifiers integers symbols and comments" {
  let result = @syntax.lex(
    source_id(),
    "name_1 42 { } = == != ; // ignored\nnext",
  )
  assert_eq(result.diagnostics.length(), 0)
  debug_inspect(
    result.tokens,
    content=(
      #|[
      #|  {
      #|    kind: Identifier("name_1"),
      #|    span: { source: { value: 0 }, start: 0, end: 6 },
      #|  },
      #|  {
      #|    kind: IntegerLiteral("42"),
      #|    span: { source: { value: 0 }, start: 7, end: 9 },
      #|  },
      #|  {
      #|    kind: LeftBrace,
      #|    span: { source: { value: 0 }, start: 10, end: 11 },
      #|  },
      #|  {
      #|    kind: RightBrace,
      #|    span: { source: { value: 0 }, start: 12, end: 13 },
      #|  },
      #|  { kind: Equal, span: { source: { value: 0 }, start: 14, end: 15 } },
      #|  {
      #|    kind: EqualEqual,
      #|    span: { source: { value: 0 }, start: 16, end: 18 },
      #|  },
      #|  {
      #|    kind: BangEqual,
      #|    span: { source: { value: 0 }, start: 19, end: 21 },
      #|  },
      #|  {
      #|    kind: Semicolon,
      #|    span: { source: { value: 0 }, start: 22, end: 23 },
      #|  },
      #|  {
      #|    kind: Identifier("next"),
      #|    span: { source: { value: 0 }, start: 35, end: 39 },
      #|  },
      #|  {
      #|    kind: EndOfFile,
      #|    span: { source: { value: 0 }, start: 39, end: 39 },
      #|  },
      #|]
    ),
  )
}

///|
test "decodes quoted string escapes" {
  let result = @syntax.lex(source_id(), "\"line\\n\\u{4E2D}\\\"\\\\\"")
  assert_eq(result.diagnostics.length(), 0)
  assert_eq(
    result.tokens[0].kind,
    @syntax.TokenKind::StringLiteral("line\n中\"\\"),
  )
}

///|
test "trims structural newlines in a triple-quoted string" {
  let input =
    #|"""
    #|hello
    #|world
    #|"""
  let result = @syntax.lex(source_id(), input)
  assert_eq(result.diagnostics.length(), 0)
  assert_eq(
    result.tokens[0].kind,
    @syntax.TokenKind::StringLiteral("hello\nworld"),
  )
}

///|
test "reports an unexpected character and continues" {
  let result = @syntax.lex(source_id(), "context @ \"demo\"")
  assert_eq(result.diagnostics.length(), 1)
  let diagnostic = result.diagnostics[0]
  assert_eq(diagnostic.code, "E1001")
  assert_eq(
    diagnostic.primary,
    @diagnostics.Span::new(source_id(), start=8, end=9),
  )
  assert_eq(result.tokens.length(), 3)
}

///|
test "reports invalid escapes and unterminated strings" {
  let invalid_escape = @syntax.lex(source_id(), "\"bad\\q\"")
  assert_eq(invalid_escape.diagnostics.length(), 1)
  assert_eq(invalid_escape.diagnostics[0].code, "E1003")
  let unterminated = @syntax.lex(source_id(), "\"open")
  assert_eq(unterminated.diagnostics.length(), 1)
  assert_eq(unterminated.diagnostics[0].code, "E1002")
  assert_true(unterminated.tokens[0].kind is @syntax.TokenKind::EndOfFile)
  let trailing_slash = @syntax.lex(source_id(), "\"bad\\")
  assert_eq(trailing_slash.diagnostics.length(), 1)
  assert_eq(trailing_slash.diagnostics[0].code, "E1002")
}
