///|
priv struct Lexer {
  source : @diagnostics.SourceId
  chars : Array[Char]
  mut current : Int
  tokens : Array[Token]
  diagnostics : Array[@diagnostics.Diagnostic]
}

///|
fn is_ascii_letter(ch : Char) -> Bool {
  (ch >= 'a' && ch <= 'z') || (ch >= 'A' && ch <= 'Z')
}

///|
fn is_digit(ch : Char) -> Bool {
  ch >= '0' && ch <= '9'
}

///|
fn is_identifier_start(ch : Char) -> Bool {
  is_ascii_letter(ch) || ch == '_'
}

///|
fn is_identifier_continue(ch : Char) -> Bool {
  is_identifier_start(ch) || is_digit(ch)
}

///|
fn hex_value(ch : Char) -> Int? {
  if ch >= '0' && ch <= '9' {
    Some(ch.to_int() - '0'.to_int())
  } else if ch >= 'a' && ch <= 'f' {
    Some(ch.to_int() - 'a'.to_int() + 10)
  } else if ch >= 'A' && ch <= 'F' {
    Some(ch.to_int() - 'A'.to_int() + 10)
  } else {
    None
  }
}

///|
fn Lexer::at_end(self : Lexer) -> Bool {
  self.current >= self.chars.length()
}

///|
fn Lexer::peek(self : Lexer, distance : Int) -> Char? {
  self.chars.get(self.current + distance)
}

///|
fn Lexer::advance(self : Lexer) -> Char? {
  match self.chars.get(self.current) {
    Some(ch) => {
      self.current += 1
      Some(ch)
    }
    None => None
  }
}

///|
fn Lexer::span(self : Lexer, start : Int) -> @diagnostics.Span {
  @diagnostics.Span::new(self.source, start~, end=self.current)
}

///|
fn Lexer::emit(self : Lexer, kind : TokenKind, start : Int) -> Unit {
  self.tokens.push({ kind, span: self.span(start), })
}

///|
fn Lexer::error(
  self : Lexer,
  code : String,
  message : String,
  start : Int,
  end : Int,
) -> Unit {
  self.diagnostics.push(
    @diagnostics.Diagnostic::new(
      @diagnostics.Severity::Error,
      code~,
      message~,
      primary=@diagnostics.Span::new(self.source, start~, end~),
    ),
  )
}

///|
fn Lexer::scan_identifier(self : Lexer, start : Int) -> Unit {
  while self.peek(0) is Some(ch) && is_identifier_continue(ch) {
    ignore(self.advance())
  }
  let builder = StringBuilder()
  for index in start..<self.current {
    builder.write_char(self.chars[index])
  }
  self.emit(Identifier(builder.to_string()), start)
}

///|
fn Lexer::scan_integer(self : Lexer, start : Int) -> Unit {
  while self.peek(0) is Some(ch) && is_digit(ch) {
    ignore(self.advance())
  }
  let builder = StringBuilder()
  for index in start..<self.current {
    builder.write_char(self.chars[index])
  }
  self.emit(IntegerLiteral(builder.to_string()), start)
}

///|
fn Lexer::scan_unicode_escape(
  self : Lexer,
  builder : StringBuilder,
  escape_start : Int,
) -> Unit {
  if self.peek(0) != Some('{') {
    self.error("E1003", "expected `{` after `\\u`", escape_start, self.current)
    return
  }
  ignore(self.advance())
  let mut value = 0
  let mut digits = 0
  let mut valid = true
  while self.peek(0) is Some(ch) && ch != '}' && ch != '\n' && ch != '"' {
    match hex_value(ch) {
      Some(digit) => {
        value = value * 16 + digit
        digits += 1
      }
      None => valid = false
    }
    ignore(self.advance())
  }
  if self.peek(0) == Some('}') {
    ignore(self.advance())
  } else {
    valid = false
  }
  if digits == 0 || digits > 6 {
    valid = false
  }
  if value > 0x10ffff || (value >= 0xd800 && value <= 0xdfff) {
    valid = false
  }
  if valid {
    builder.write_char(value.unsafe_to_char())
  } else {
    self.error("E1003", "invalid Unicode escape", escape_start, self.current)
  }
}

///|
fn Lexer::scan_escape(
  self : Lexer,
  builder : StringBuilder,
  escape_start : Int,
) -> Unit {
  match self.advance() {
    Some('\\') => builder.write_char('\\')
    Some('"') => builder.write_char('"')
    Some('n') => builder.write_char('\n')
    Some('r') => builder.write_char('\r')
    Some('t') => builder.write_char('\t')
    Some('u') => self.scan_unicode_escape(builder, escape_start)
    Some(ch) =>
      self.error(
        "E1003",
        "invalid escape `\\\{ch}`",
        escape_start,
        self.current,
      )
    None => ()
  }
}

///|
fn Lexer::scan_quoted_string(self : Lexer, start : Int) -> Unit {
  let builder = StringBuilder()
  while !self.at_end() {
    match self.peek(0) {
      Some('"') => {
        ignore(self.advance())
        self.emit(StringLiteral(builder.to_string()), start)
        return
      }
      Some('\n') => {
        self.error("E1002", "unterminated string literal", start, self.current)
        return
      }
      Some('\\') => {
        let escape_start = self.current
        ignore(self.advance())
        self.scan_escape(builder, escape_start)
      }
      Some(ch) => {
        builder.write_char(ch)
        ignore(self.advance())
      }
      None => ()
    }
  }
  self.error("E1002", "unterminated string literal", start, self.current)
}

///|
fn trim_triple_string(chars : Array[Char]) -> String {
  let start = if chars.get(0) == Some('\n') { 1 } else { 0 }
  let end = if chars.length() > start &&
    chars.get(chars.length() - 1) == Some('\n') {
    chars.length() - 1
  } else {
    chars.length()
  }
  let builder = StringBuilder()
  for index in start..<end {
    builder.write_char(chars[index])
  }
  builder.to_string()
}

///|
fn Lexer::scan_triple_string(self : Lexer, start : Int) -> Unit {
  let content : Array[Char] = []
  while !self.at_end() {
    if self.peek(0) == Some('"') &&
      self.peek(1) == Some('"') &&
      self.peek(2) == Some('"') {
      self.current += 3
      self.emit(StringLiteral(trim_triple_string(content)), start)
      return
    }
    match self.advance() {
      Some(ch) => content.push(ch)
      None => ()
    }
  }
  self.error("E1002", "unterminated triple-quoted string", start, self.current)
}

///|
fn Lexer::skip_comment(self : Lexer) -> Unit {
  self.current += 2
  while self.peek(0) is Some(ch) && ch != '\n' {
    ignore(self.advance())
  }
}

///|
fn Lexer::scan_token(self : Lexer) -> Unit {
  let start = self.current
  guard self.advance() is Some(ch) else { return }
  if ch == ' ' || ch == '\t' || ch == '\n' {
    return
  }
  if is_identifier_start(ch) {
    self.scan_identifier(start)
    return
  }
  if is_digit(ch) {
    self.scan_integer(start)
    return
  }
  match ch {
    '{' => self.emit(LeftBrace, start)
    '}' => self.emit(RightBrace, start)
    ';' => self.emit(Semicolon, start)
    '=' =>
      if self.peek(0) == Some('=') {
        ignore(self.advance())
        self.emit(EqualEqual, start)
      } else {
        self.emit(Equal, start)
      }
    '!' =>
      if self.peek(0) == Some('=') {
        ignore(self.advance())
        self.emit(BangEqual, start)
      } else {
        self.error("E1001", "unexpected character `!`", start, self.current)
      }
    '/' =>
      if self.peek(0) == Some('/') {
        self.current = start
        self.skip_comment()
      } else {
        self.error("E1001", "unexpected character `/`", start, self.current)
      }
    '"' =>
      if self.peek(0) == Some('"') && self.peek(1) == Some('"') {
        self.current += 2
        self.scan_triple_string(start)
      } else {
        self.scan_quoted_string(start)
      }
    _ =>
      self.error("E1001", "unexpected character `\{ch}`", start, self.current)
  }
}

///|
/// Tokenize normalized context source without performing parsing.
///
/// Comments and whitespace are skipped. The result always ends with an EOF
/// token, even when recoverable lexical errors are present.
///
/// # Example
/// ```mbt check
/// test {
///   let source = @diagnostics.SourceId::{ value: 0, }
///   let result = lex(source, "name = 1;")
///   assert_eq(result.diagnostics.length(), 0)
///   assert_true(result.tokens[0].kind is Identifier("name"))
/// }
/// ```
pub fn lex(source : @diagnostics.SourceId, text : String) -> LexResult {
  let chars : Array[Char] = []
  for ch in text {
    chars.push(ch)
  }
  let lexer = Lexer::{ source, chars, current: 0, tokens: [], diagnostics: [], }
  while !lexer.at_end() {
    lexer.scan_token()
  }
  lexer.tokens.push({
    kind: EndOfFile,
    span: @diagnostics.Span::new(source, start=lexer.current, end=lexer.current),
  })
  { tokens: lexer.tokens, diagnostics: lexer.diagnostics, }
}
