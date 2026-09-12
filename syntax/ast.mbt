///|
/// Identifier together with its exact source range.
pub(all) struct IdentifierSyntax {
  value : String
  span : @diagnostics.Span
} derive(Debug, Eq)

///|
/// Decoded string literal together with its source range.
pub(all) struct StringSyntax {
  value : String
  span : @diagnostics.Span
} derive(Debug, Eq)

///|
/// Decimal spelling of an integer together with its source range.
pub(all) struct IntegerSyntax {
  digits : String
  span : @diagnostics.Span
} derive(Debug, Eq)

///|
/// Root context declaration.
pub(all) struct ContextDecl {
  name : StringSyntax
  span : @diagnostics.Span
} derive(Debug, Eq)

///|
/// Character-budget declaration.
pub(all) struct BudgetDecl {
  unit : IdentifierSyntax
  amount : IntegerSyntax
  span : @diagnostics.Span
} derive(Debug, Eq)

///|
/// Output-format declaration. Semantic analysis validates the format name.
pub(all) struct OutputDecl {
  format : IdentifierSyntax
  span : @diagnostics.Span
} derive(Debug, Eq)

///|
/// String-variable declaration.
pub(all) struct LetDecl {
  name : IdentifierSyntax
  value : StringSyntax
  span : @diagnostics.Span
} derive(Debug, Eq)

///|
/// Source-include declaration.
pub(all) struct IncludeDecl {
  path : StringSyntax
  span : @diagnostics.Span
} derive(Debug, Eq)

///|
/// Operator supported by a v0.1 section condition.
pub(all) enum ConditionOperator {
  Equal
  NotEqual
} derive(Debug, Eq)

///|
/// Simple variable comparison attached to a section.
pub(all) struct ConditionSyntax {
  variable : IdentifierSyntax
  operator : ConditionOperator
  value : StringSyntax
  span : @diagnostics.Span
} derive(Debug, Eq)

///|
/// Section modifier retained in source order.
pub(all) enum SectionModifierSyntax {
  Priority(IntegerSyntax, @diagnostics.Span)
  Required(@diagnostics.Span)
  When(ConditionSyntax)
} derive(Debug, Eq)

///|
/// Inline or file-backed section content.
pub(all) enum SectionContentSyntax {
  Text(StringSyntax, @diagnostics.Span)
  File(StringSyntax, @diagnostics.Span)
} derive(Debug, Eq)

///|
/// Section declaration with all modifiers and content declarations preserved.
pub(all) struct SectionDecl {
  name : StringSyntax
  modifiers : Array[SectionModifierSyntax]
  contents : Array[SectionContentSyntax]
  span : @diagnostics.Span
} derive(Debug, Eq)

///|
/// Top-level context-language declaration.
pub(all) enum DeclarationSyntax {
  Context(ContextDecl)
  Budget(BudgetDecl)
  Output(OutputDecl)
  Let(LetDecl)
  Include(IncludeDecl)
  Section(SectionDecl)
} derive(Debug, Eq)

///|
/// Syntax tree for either a root or included context file.
pub(all) struct DocumentSyntax {
  declarations : Array[DeclarationSyntax]
} derive(Debug, Eq)

///|
/// Recovered syntax tree and all lexical or parse diagnostics.
pub(all) struct ParseResult {
  document : DocumentSyntax
  diagnostics : Array[@diagnostics.Diagnostic]
} derive(Debug)
