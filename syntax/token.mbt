///|
/// Token kinds produced by the context-language lexer.
pub(all) enum TokenKind {
  Identifier(String)
  StringLiteral(String)
  IntegerLiteral(String)
  LeftBrace
  RightBrace
  Equal
  EqualEqual
  BangEqual
  Semicolon
  EndOfFile
} derive(Debug, Eq)

///|
/// One token and its half-open source range.
pub(all) struct Token {
  kind : TokenKind
  span : @diagnostics.Span
} derive(Debug, Eq)

///|
/// Tokens and recoverable lexical diagnostics for one source file.
pub(all) struct LexResult {
  tokens : Array[Token]
  diagnostics : Array[@diagnostics.Diagnostic]
} derive(Debug)
