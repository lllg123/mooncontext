///|
fn char_count(text : String) -> Int {
  let mut count = 0
  for _ in text {
    count += 1
  }
  count
}

///|
fn repeat_char(ch : Char, count : Int) -> String {
  let builder = StringBuilder()
  for _ in 0..<count {
    builder.write_char(ch)
  }
  builder.to_string()
}

///|
fn min_int(left : Int, right : Int) -> Int {
  if left < right {
    left
  } else {
    right
  }
}

///|
fn max_int(left : Int, right : Int) -> Int {
  if left > right {
    left
  } else {
    right
  }
}

///|
fn SourceFile::render_span(
  file : SourceFile,
  span : Span,
  label : String?,
) -> String {
  guard file.position(span.start) is Some(start) else { return "" }
  let last_offset = if span.end > span.start {
    span.end - 1
  } else {
    span.start
  }
  guard file.position(last_offset) is Some(last) else { return "" }
  let width = char_count("\{last.line}")
  let builder = StringBuilder()
  builder.write_string("  --> \{file.path}:\{start.line}:\{start.column}\n")
  builder.write_string("\{repeat_char(' ', width + 1)}|\n")
  for line_index in (start.line - 1)..<last.line {
    let line_number = line_index + 1
    let number_text = "\{line_number}"
    let line = file.lines[line_index]
    let line_length = char_count(line)
    let line_start = file.line_starts[line_index]
    let marker_start = max_int(span.start, line_start) - line_start
    let marker_end = min_int(span.end, line_start + line_length) - line_start
    let marker_length = max_int(1, marker_end - marker_start)
    builder.write_string(repeat_char(' ', width - char_count(number_text)))
    builder.write_string("\{number_text} | \{line}\n")
    builder.write_string("\{repeat_char(' ', width + 1)}| ")
    builder.write_string(repeat_char(' ', marker_start))
    builder.write_string(repeat_char('^', marker_length))
    if line_index == start.line - 1 {
      match label {
        Some(message) => builder.write_string(" \{message}")
        None => ()
      }
    }
    builder.write_char('\n')
  }
  builder.to_string()
}

///|
fn primary_label(diagnostic : Diagnostic) -> String? {
  for label in diagnostic.labels {
    if label.span == diagnostic.primary {
      return Some(label.message)
    }
  }
  None
}

///|
/// Format one diagnostic with source location, highlighted range, related
/// labels, and optional help text.
pub fn SourceMap::format(self : SourceMap, diagnostic : Diagnostic) -> String {
  let builder = StringBuilder()
  builder.write_string(
    "\{diagnostic.severity.name()}[\{diagnostic.code}]: \{diagnostic.message}\n",
  )
  match self.file(diagnostic.primary.source) {
    Some(file) =>
      builder.write_string(
        file.render_span(diagnostic.primary, primary_label(diagnostic)),
      )
    None => builder.write_string("  --> <unknown>\n")
  }
  for label in diagnostic.labels {
    if label.span != diagnostic.primary {
      match self.locate(label.span) {
        Some(location) =>
          builder.write_string(
            "   = note: \{location.path}:\{location.start.line}:\{location.start.column}: \{label.message}\n",
          )
        None => builder.write_string("   = note: <unknown>: \{label.message}\n")
      }
    }
  }
  match diagnostic.help {
    Some(help) => {
      builder.write_string("   |\n")
      builder.write_string("   = help: \{help}\n")
    }
    None => ()
  }
  builder.to_string()
}
