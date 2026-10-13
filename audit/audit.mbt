///|
fn add_issue(
  issues : Array[Issue],
  severity : Severity,
  code : String,
  message : String,
  line : Int,
  column : Int,
) -> Unit {
  issues.push({ severity, code, message, line, column, })
}

///|
fn line_characters(line : String) -> Array[Char] {
  [
    for ch in line => ch
  ]
}

///|
fn heading_name(line : String) -> String? {
  let chars = line_characters(line)
  let mut start = 0
  while start < chars.length() && start < 4 && chars[start] == ' ' {
    start += 1
  }
  if start > 3 {
    return None
  }
  let mut hashes = start
  while hashes < chars.length() && chars[hashes] == '#' {
    hashes += 1
  }
  if hashes == start ||
    hashes - start > 6 ||
    (hashes < chars.length() && !is_markdown_space(chars[hashes])) {
    return None
  }
  start = hashes
  while start < chars.length() && is_markdown_space(chars[start]) {
    start += 1
  }
  let mut end = chars.length()
  while end > start && is_markdown_space(chars[end - 1]) {
    end -= 1
  }
  let mut closing = end
  while closing > start && chars[closing - 1] == '#' {
    closing -= 1
  }
  if closing < end &&
    (closing == start || is_markdown_space(chars[closing - 1])) {
    end = closing
    while end > start && is_markdown_space(chars[end - 1]) {
      end -= 1
    }
  }
  let value = StringBuilder()
  for index in start..<end {
    value.write_char(chars[index])
  }
  Some(value.to_string())
}

///|
fn is_markdown_space(ch : Char) -> Bool {
  ch == ' ' || ch == '\t'
}

///|
fn fence_start(line : String) -> (Char, Int)? {
  let chars = line_characters(line)
  let mut index = 0
  while index < chars.length() && index < 4 && chars[index] == ' ' {
    index += 1
  }
  if index > 3 ||
    index >= chars.length() ||
    (chars[index] != '`' && chars[index] != '~') {
    return None
  }
  let fence = chars[index]
  let mut end = index
  while end < chars.length() && chars[end] == fence {
    end += 1
  }
  if end - index >= 3 {
    Some((fence, end - index))
  } else {
    None
  }
}

///|
fn fence_closes(line : String, fence : Char, minimum : Int) -> Bool {
  let chars = line_characters(line)
  let mut index = 0
  while index < chars.length() && index < 4 && chars[index] == ' ' {
    index += 1
  }
  if index > 3 {
    return false
  }
  let start = index
  while index < chars.length() && chars[index] == fence {
    index += 1
  }
  if index - start < minimum {
    return false
  }
  while index < chars.length() {
    if !is_markdown_space(chars[index]) {
      return false
    }
    index += 1
  }
  true
}

///|
fn split_lines(text : String) -> Array[String] {
  let lines : Array[String] = []
  let mut current = StringBuilder()
  let mut after_cr = false
  for ch in text {
    if ch == '\r' {
      lines.push(current.to_string())
      current = StringBuilder()
      after_cr = true
    } else if ch == '\n' {
      if !after_cr {
        lines.push(current.to_string())
        current = StringBuilder()
      }
      after_cr = false
    } else {
      after_cr = false
      current.write_char(ch)
    }
  }
  lines.push(current.to_string())
  lines
}

///|
fn character_count(text : String) -> Int {
  let mut count = 0
  for _ in text {
    count += 1
  }
  count
}

///|
fn check_placeholders(
  line : String,
  line_number : Int,
  issues : Array[Issue],
) -> Unit {
  let chars = line_characters(line)
  for index in 0..<chars.length() {
    if chars[index] == '$' &&
      index + 1 < chars.length() &&
      chars[index + 1] == '{' {
      add_issue(
        issues,
        Error,
        "A1003",
        "unresolved `${...}` placeholder in rendered context",
        line_number,
        index + 1,
      )
      return
    }
    if chars[index] == '{' &&
      index + 1 < chars.length() &&
      chars[index + 1] == '{' {
      add_issue(
        issues,
        Error,
        "A1004",
        "unresolved `{{...}}` template marker in rendered context",
        line_number,
        index + 1,
      )
      return
    }
  }
}

///|
priv struct ScannableText {
  chars : Array[Char]
  lines : Array[Int]
  columns : Array[Int]
}

///|
/// Normalize newline spelling for matching, without changing the audited bytes.
fn scannable_text(text : String) -> ScannableText {
  let chars : Array[Char] = []
  let lines : Array[Int] = []
  let columns : Array[Int] = []
  let mut line = 1
  let mut column = 1
  let mut after_cr = false
  for ch in text {
    if ch == '\n' && after_cr {
      after_cr = false
      continue
    }
    let normalized = if ch == '\r' { '\n' } else { ch }
    chars.push(normalized)
    lines.push(line)
    columns.push(column)
    if normalized == '\n' {
      line += 1
      column = 1
    } else {
      column += 1
    }
    after_cr = ch == '\r'
  }
  { chars, lines, columns, }
}

///|
/// Search the entire final payload, including matches spanning line endings.
fn check_forbidden_markers(
  text : String,
  forbidden_markers : Array[String],
  issues : Array[Issue],
) -> Unit {
  let source = scannable_text(text)
  for marker in forbidden_markers {
    if marker == "" {
      add_issue(
        issues,
        Error,
        "A0003",
        "forbidden marker must not be empty",
        1,
        1,
      )
      continue
    }
    let needle = scannable_text(marker).chars
    if needle.length() > source.chars.length() {
      continue
    }
    for start in 0..<=(source.chars.length() - needle.length()) {
      let mut matches = true
      for offset in 0..<needle.length() {
        if source.chars[start + offset] != needle[offset] {
          matches = false
          break
        }
      }
      if matches {
        add_issue(
          issues,
          Error,
          "A1005",
          "forbidden marker found: `\{marker}`",
          source.lines[start],
          source.columns[start],
        )
      }
    }
  }
}

///|
/// Audit an already-rendered context without imposing a source DSL.
///
/// The audit is deliberately independent of the template engine that produced
/// the text. It checks the contract at the boundary where a context enters a
/// model request or a CI artifact.
pub fn audit(text : String, policy : Policy) -> Report {
  let issues : Array[Issue] = []
  let lines = split_lines(text)
  let headings : Map[String, Int] = Map([])
  let mut heading_count = 0
  let mut inside_fence : (Char, Int)? = None
  for line_number, line in lines {
    match inside_fence {
      Some((fence, minimum)) => {
        if fence_closes(line, fence, minimum) {
          inside_fence = None
        }
        continue
      }
      None => ()
    }
    match fence_start(line) {
      Some(fence) => {
        inside_fence = Some(fence)
        continue
      }
      None => ()
    }
    check_placeholders(line, line_number + 1, issues)
    match heading_name(line) {
      Some(name) => {
        heading_count += 1
        if headings.contains(name) {
          add_issue(
            issues,
            Warning,
            "A2001",
            "duplicate Markdown heading `\{name}`",
            line_number + 1,
            1,
          )
        } else {
          headings[name] = line_number + 1
        }
      }
      None => ()
    }
  }
  check_forbidden_markers(text, policy.forbidden_markers, issues)
  let count = character_count(text)
  if policy.char_budget <= 0 {
    add_issue(
      issues,
      Error,
      "A0001",
      "character budget must be greater than zero",
      1,
      1,
    )
  } else if count > policy.char_budget {
    add_issue(
      issues,
      Error,
      "A1001",
      "context uses \{count} characters, exceeding budget \{policy.char_budget}",
      1,
      1,
    )
  }
  for marker in policy.required_markers {
    if marker == "" {
      add_issue(
        issues,
        Error,
        "A0002",
        "required marker must not be empty",
        1,
        1,
      )
    } else if !text.contains(marker) {
      add_issue(
        issues,
        Error,
        "A1002",
        "required context marker is missing: `\{marker}`",
        1,
        1,
      )
    }
  }
  {
    fingerprint: fingerprint(text),
    character_count: count,
    heading_count,
    issues,
  }
}
