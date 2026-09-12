///|
priv struct Parser {
  tokens : Array[Token]
  mut current : Int
  diagnostics : Array[@diagnostics.Diagnostic]
}

///|
fn Parser::peek(parser : Parser) -> Token {
  parser.tokens[parser.current]
}

///|
fn Parser::at_end(parser : Parser) -> Bool {
  parser.peek().kind is EndOfFile
}

///|
fn Parser::advance(parser : Parser) -> Token {
  let token = parser.peek()
  if !parser.at_end() {
    parser.current += 1
  }
  token
}

///|
fn Parser::previous_end(parser : Parser, fallback : Int) -> Int {
  if parser.current > 0 {
    parser.tokens[parser.current - 1].span.end
  } else {
    fallback
  }
}

///|
fn Parser::error_at(
  parser : Parser,
  token : Token,
  code : String,
  message : String,
) -> Unit {
  parser.diagnostics.push(
    @diagnostics.Diagnostic::new(
      @diagnostics.Severity::Error,
      code~,
      message~,
      primary=token.span,
    ),
  )
}

///|
fn token_is_keyword(token : Token, keyword : String) -> Bool {
  match token.kind {
    Identifier(value) => value == keyword
    _ => false
  }
}

///|
fn is_top_level_keyword(token : Token) -> Bool {
  token_is_keyword(token, "context") ||
  token_is_keyword(token, "budget") ||
  token_is_keyword(token, "output") ||
  token_is_keyword(token, "let") ||
  token_is_keyword(token, "include") ||
  token_is_keyword(token, "section")
}

///|
fn Parser::check(parser : Parser, kind : TokenKind) -> Bool {
  parser.peek().kind == kind
}

///|
fn Parser::consume(
  parser : Parser,
  kind : TokenKind,
  message : String,
) -> Token? {
  if parser.check(kind) {
    Some(parser.advance())
  } else {
    parser.error_at(parser.peek(), "E2002", message)
    None
  }
}

///|
fn Parser::take_identifier(
  parser : Parser,
  message : String,
) -> IdentifierSyntax? {
  match parser.peek().kind {
    Identifier(value) => {
      let token = parser.advance()
      Some({ value, span: token.span, })
    }
    _ => {
      parser.error_at(parser.peek(), "E2002", message)
      None
    }
  }
}

///|
fn Parser::take_string(parser : Parser, message : String) -> StringSyntax? {
  match parser.peek().kind {
    StringLiteral(value) => {
      let token = parser.advance()
      Some({ value, span: token.span, })
    }
    _ => {
      parser.error_at(parser.peek(), "E2002", message)
      None
    }
  }
}

///|
fn Parser::take_integer(parser : Parser, message : String) -> IntegerSyntax? {
  match parser.peek().kind {
    IntegerLiteral(digits) => {
      let token = parser.advance()
      Some({ digits, span: token.span, })
    }
    _ => {
      parser.error_at(parser.peek(), "E2002", message)
      None
    }
  }
}

///|
fn Parser::synchronize_statement(parser : Parser) -> Unit {
  while !parser.at_end() && !parser.check(RightBrace) {
    if parser.check(Semicolon) {
      ignore(parser.advance())
      return
    }
    if is_top_level_keyword(parser.peek()) {
      return
    }
    ignore(parser.advance())
  }
}

///|
fn Parser::finish_statement(parser : Parser, description : String) -> Unit {
  if parser.consume(Semicolon, "expected `;` after \{description}") is None {
    if !is_top_level_keyword(parser.peek()) && !parser.check(RightBrace) {
      parser.synchronize_statement()
    }
  }
}

///|
fn Parser::declaration_span(
  parser : Parser,
  source : @diagnostics.SourceId,
  start : Int,
) -> @diagnostics.Span {
  @diagnostics.Span::new(source, start~, end=parser.previous_end(start))
}

///|
fn Parser::parse_context(
  parser : Parser,
  keyword : Token,
) -> DeclarationSyntax? {
  let name = parser.take_string("expected context name string")
  parser.finish_statement("context declaration")
  match name {
    Some(value) =>
      Some(
        Context({
          name: value,
          span: parser.declaration_span(keyword.span.source, keyword.span.start),
        }),
      )
    None => None
  }
}

///|
fn Parser::parse_budget(parser : Parser, keyword : Token) -> DeclarationSyntax? {
  let unit = parser.take_identifier("expected budget unit")
  if unit is Some(value) && value.value != "chars" {
    parser.error_at(
      Token::{ kind: Identifier(value.value), span: value.span, },
      "E2001",
      "expected budget unit `chars`",
    )
  }
  ignore(parser.consume(Equal, "expected `=` after budget unit"))
  let amount = parser.take_integer("expected decimal budget amount")
  parser.finish_statement("budget declaration")
  match (unit, amount) {
    (Some(unit), Some(amount)) =>
      Some(
        Budget({
          unit,
          amount,
          span: parser.declaration_span(keyword.span.source, keyword.span.start),
        }),
      )
    _ => None
  }
}

///|
fn Parser::parse_output(parser : Parser, keyword : Token) -> DeclarationSyntax? {
  let format = parser.take_identifier("expected output format")
  parser.finish_statement("output declaration")
  match format {
    Some(value) =>
      Some(
        Output({
          format: value,
          span: parser.declaration_span(keyword.span.source, keyword.span.start),
        }),
      )
    None => None
  }
}

///|
fn Parser::parse_let(parser : Parser, keyword : Token) -> DeclarationSyntax? {
  let name = parser.take_identifier("expected variable name")
  ignore(parser.consume(Equal, "expected `=` after variable name"))
  let value = parser.take_string("expected variable value string")
  parser.finish_statement("variable declaration")
  match (name, value) {
    (Some(name), Some(value)) =>
      Some(
        Let({
          name,
          value,
          span: parser.declaration_span(keyword.span.source, keyword.span.start),
        }),
      )
    _ => None
  }
}

///|
fn Parser::parse_include(
  parser : Parser,
  keyword : Token,
) -> DeclarationSyntax? {
  let path = parser.take_string("expected include path string")
  parser.finish_statement("include declaration")
  match path {
    Some(value) =>
      Some(
        Include({
          path: value,
          span: parser.declaration_span(keyword.span.source, keyword.span.start),
        }),
      )
    None => None
  }
}

///|
fn Parser::parse_priority(
  parser : Parser,
  keyword : Token,
) -> SectionModifierSyntax? {
  ignore(parser.consume(Equal, "expected `=` after `priority`"))
  match parser.take_integer("expected priority integer") {
    Some(value) =>
      Some(
        Priority(
          value,
          parser.declaration_span(keyword.span.source, keyword.span.start),
        ),
      )
    None => None
  }
}

///|
fn Parser::parse_when(
  parser : Parser,
  keyword : Token,
) -> SectionModifierSyntax? {
  let variable = parser.take_identifier("expected condition variable")
  let operator = if parser.check(EqualEqual) {
    ignore(parser.advance())
    Some(ConditionOperator::Equal)
  } else if parser.check(BangEqual) {
    ignore(parser.advance())
    Some(ConditionOperator::NotEqual)
  } else {
    parser.error_at(
      parser.peek(),
      "E2002",
      "expected `==` or `!=` in condition",
    )
    None
  }
  let value = parser.take_string("expected condition value string")
  match (variable, operator, value) {
    (Some(variable), Some(operator), Some(value)) => {
      let span = parser.declaration_span(
        keyword.span.source,
        keyword.span.start,
      )
      Some(When({ variable, operator, value, span, }))
    }
    _ => None
  }
}

///|
fn modifier_name(modifier : SectionModifierSyntax) -> String {
  match modifier {
    Priority(_, _) => "priority"
    Required(_) => "required"
    When(_) => "when"
  }
}

///|
fn Parser::parse_content(parser : Parser) -> SectionContentSyntax? {
  let keyword = parser.advance()
  ignore(parser.consume(Equal, "expected `=` after section content kind"))
  let value = parser.take_string("expected section content string")
  parser.finish_statement("section content")
  match value {
    Some(value) => {
      let span = parser.declaration_span(
        keyword.span.source,
        keyword.span.start,
      )
      match keyword.kind {
        Identifier("text") => Some(Text(value, span))
        Identifier("file") => Some(File(value, span))
        _ => None
      }
    }
    None => None
  }
}

///|
fn Parser::parse_section(
  parser : Parser,
  keyword : Token,
) -> DeclarationSyntax? {
  let name = parser.take_string("expected section name string")
  let modifiers : Array[SectionModifierSyntax] = []
  let seen : Map[String, Bool] = Map([])
  while !parser.at_end() && !parser.check(LeftBrace) {
    let modifier_keyword = parser.peek()
    let modifier = if token_is_keyword(modifier_keyword, "priority") {
      ignore(parser.advance())
      parser.parse_priority(modifier_keyword)
    } else if token_is_keyword(modifier_keyword, "required") {
      ignore(parser.advance())
      Some(Required(modifier_keyword.span))
    } else if token_is_keyword(modifier_keyword, "when") {
      ignore(parser.advance())
      parser.parse_when(modifier_keyword)
    } else {
      parser.error_at(
        modifier_keyword, "E2001", "expected section modifier or `{`",
      )
      ignore(parser.advance())
      None
    }
    match modifier {
      Some(value) => {
        let key = modifier_name(value)
        if seen.contains(key) {
          parser.error_at(
            modifier_keyword,
            "E2003",
            "section modifier `\{key}` appears more than once",
          )
        }
        seen[key] = true
        modifiers.push(value)
      }
      None => ()
    }
  }
  let contents : Array[SectionContentSyntax] = []
  if parser.consume(LeftBrace, "expected `{` before section content") is Some(_) {
    while !parser.at_end() && !parser.check(RightBrace) {
      if token_is_keyword(parser.peek(), "text") ||
        token_is_keyword(parser.peek(), "file") {
        match parser.parse_content() {
          Some(content) => contents.push(content)
          None => ()
        }
      } else {
        parser.error_at(
          parser.peek(),
          "E2001",
          "expected `text`, `file`, or `}` in section",
        )
        parser.synchronize_statement()
      }
    }
    ignore(parser.consume(RightBrace, "expected `}` after section content"))
  }
  match name {
    Some(value) =>
      Some(
        Section({
          name: value,
          modifiers,
          contents,
          span: parser.declaration_span(keyword.span.source, keyword.span.start),
        }),
      )
    None => None
  }
}

///|
fn Parser::parse_declaration(parser : Parser) -> DeclarationSyntax? {
  let keyword = parser.advance()
  match keyword.kind {
    Identifier("context") => parser.parse_context(keyword)
    Identifier("budget") => parser.parse_budget(keyword)
    Identifier("output") => parser.parse_output(keyword)
    Identifier("let") => parser.parse_let(keyword)
    Identifier("include") => parser.parse_include(keyword)
    Identifier("section") => parser.parse_section(keyword)
    Identifier(name) => {
      parser.error_at(keyword, "E2001", "unknown declaration `\{name}`")
      parser.synchronize_statement()
      None
    }
    _ => {
      parser.error_at(keyword, "E2001", "expected a top-level declaration")
      parser.synchronize_statement()
      None
    }
  }
}

///|
/// Parse a root or included context source into a recovered syntax tree.
///
/// Lexical diagnostics are preserved. Syntax recovery continues at statement
/// and section boundaries so one malformed declaration does not hide later
/// errors.
///
/// # Example
/// ```mbt check
/// test {
///   let source = @diagnostics.SourceId::{ value: 0, }
///   let result = parse(source, "context \"demo\";")
///   assert_eq(result.diagnostics.length(), 0)
///   assert_eq(result.document.declarations.length(), 1)
/// }
/// ```
pub fn parse(source : @diagnostics.SourceId, text : String) -> ParseResult {
  let lexed = lex(source, text)
  let parser = Parser::{
    tokens: lexed.tokens,
    current: 0,
    diagnostics: lexed.diagnostics,
  }
  let declarations : Array[DeclarationSyntax] = []
  while !parser.at_end() {
    let before = parser.current
    match parser.parse_declaration() {
      Some(declaration) => declarations.push(declaration)
      None => ()
    }
    if parser.current == before {
      ignore(parser.advance())
    }
  }
  { document: { declarations, }, diagnostics: parser.diagnostics, }
}
