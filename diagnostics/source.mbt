///|
/// Stable identity assigned to a source file in discovery order.
pub(all) struct SourceId {
  value : Int
} derive(Debug, Eq)

///|
/// One-based line and column in normalized source text.
pub(all) struct Position {
  line : Int
  column : Int
} derive(Debug, Eq)

///|
/// Half-open character range `[start, end)` within one source file.
pub(all) struct Span {
  source : SourceId
  start : Int
  end : Int
} derive(Debug, Eq)

///|
/// Create a source span from normalized character offsets.
pub fn Span::new(source : SourceId, start~ : Int, end~ : Int) -> Span {
  { source, start, end, }
}

///|
/// A span resolved to its file path and one-based positions.
pub(all) struct LocatedSpan {
  path : String
  start : Position
  end : Position
} derive(Debug, Eq)

///|
pub struct SourceFile {
  path : String
  text : String
  lines : Array[String]
  line_starts : Array[Int]
  char_length : Int
}

///|
/// Collection of normalized source files used by one compilation.
pub struct SourceMap {
  files : Array[SourceFile]
}

///|
/// Create an empty source map.
pub fn SourceMap::new() -> SourceMap {
  { files: [], }
}

///|
fn prepare_source(path : String, input : String) -> SourceFile {
  let normalized = StringBuilder()
  let mut current_line = StringBuilder()
  let lines : Array[String] = []
  let line_starts : Array[Int] = [0]
  let mut char_length = 0
  let mut previous_was_cr = false
  for ch in input {
    if ch == '\n' && previous_was_cr {
      previous_was_cr = false
      continue
    }
    if ch == '\r' {
      normalized.write_char('\n')
      char_length += 1
      lines.push(current_line.to_string())
      current_line = StringBuilder()
      line_starts.push(char_length)
      previous_was_cr = true
    } else if ch == '\n' {
      normalized.write_char('\n')
      char_length += 1
      lines.push(current_line.to_string())
      current_line = StringBuilder()
      line_starts.push(char_length)
      previous_was_cr = false
    } else {
      normalized.write_char(ch)
      current_line.write_char(ch)
      char_length += 1
      previous_was_cr = false
    }
  }
  lines.push(current_line.to_string())
  { path, text: normalized.to_string(), lines, line_starts, char_length, }
}

///|
/// Add a UTF-8 source string and return its stable identity.
///
/// `\r\n` and lone `\r` line endings are normalized to `\n`.
pub fn SourceMap::add(
  self : SourceMap,
  path : String,
  text : String,
) -> SourceId {
  let source = SourceId::{ value: self.files.length(), }
  self.files.push(prepare_source(path, text))
  source
}

///|
fn SourceFile::line_index(file : SourceFile, offset : Int) -> Int {
  let mut result = 0
  for index in 1..<file.line_starts.length() {
    if file.line_starts[index] > offset {
      break
    }
    result = index
  }
  result
}

///|
fn SourceFile::position(file : SourceFile, offset : Int) -> Position? {
  if offset < 0 || offset > file.char_length {
    return None
  }
  let line_index = file.line_index(offset)
  Some({
    line: line_index + 1,
    column: offset - file.line_starts[line_index] + 1,
  })
}

///|
/// Resolve a valid half-open span to a path and one-based positions.
///
/// Returns `None` when the source ID or range is invalid.
pub fn SourceMap::locate(self : SourceMap, span : Span) -> LocatedSpan? {
  guard self.files.get(span.source.value) is Some(file) else { return None }
  if span.start < 0 || span.end < span.start || span.end > file.char_length {
    return None
  }
  guard file.position(span.start) is Some(start) else { return None }
  guard file.position(span.end) is Some(end) else { return None }
  Some({ path: file.path, start, end, })
}

///|
/// Return normalized source text for an ID.
pub fn SourceMap::text(self : SourceMap, source : SourceId) -> String? {
  match self.files.get(source.value) {
    Some(file) => Some(file.text)
    None => None
  }
}

///|
fn SourceMap::file(self : SourceMap, source : SourceId) -> SourceFile? {
  self.files.get(source.value)
}
