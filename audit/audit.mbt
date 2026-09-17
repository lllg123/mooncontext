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
  if chars.length() >= 2 && chars[0] == '#' && chars[1] == ' ' {
    start = 2
  } else if chars.length() >= 3 &&
    chars[0] == '#' &&
    chars[1] == '#' &&
    chars[2] == ' ' {
    start = 3
  } else {
    return None
  }
  let value = StringBuilder()
  for index in start..<chars.length() {
    value.write_char(chars[index])
  }
  Some(value.to_string())
}

///|
fn split_lines(text : String) -> Array[String] {
  let lines : Array[String] = []
  let mut current = StringBuilder()
  for ch in text {
    if ch == '\n' {
      lines.push(current.to_string())
      current = StringBuilder()
    } else {
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
/// Find the first 1-based character column containing a marker.
fn marker_column(line : String, marker : String) -> Int? {
  let line_chars = line_characters(line)
  let marker_chars = line_characters(marker)
  if marker_chars.length() == 0 || line_chars.length() < marker_chars.length() {
    return None
  }
  let last_start = line_chars.length() - marker_chars.length()
  for start in 0..<=last_start {
    let mut matches = true
    for offset in 0..<marker_chars.length() {
      if line_chars[start + offset] != marker_chars[offset] {
        matches = false
      }
    }
    if matches {
      return Some(start + 1)
    }
  }
  None
}

///|
/// Check for markers that must never reach a model request.
fn check_forbidden_markers(
  line : String,
  line_number : Int,
  forbidden_markers : Array[String],
  issues : Array[Issue],
) -> Unit {
  for marker in forbidden_markers {
    if marker == "" {
      add_issue(
        issues,
        Error,
        "A0003",
        "forbidden marker must not be empty",
        line_number,
        1,
      )
    } else {
      match marker_column(line, marker) {
        Some(column) =>
          add_issue(
            issues,
            Error,
            "A1005",
            "forbidden marker found: `\{marker}`",
            line_number,
            column,
          )
        None => ()
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
  for line_number, line in lines {
    check_placeholders(line, line_number + 1, issues)
    check_forbidden_markers(
      line,
      line_number + 1,
      policy.forbidden_markers,
      issues,
    )
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
  { character_count: count, heading_count, issues, }
}
