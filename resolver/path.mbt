///|
fn path_chars(path : String) -> Array[Char] {
  [
    for ch in path => if ch == '\\' { '/' } else { ch }
  ]
}

///|
fn is_forbidden_path_char(ch : Char) -> Bool {
  ch < ' ' ||
  ch == '*' ||
  ch == '?' ||
  ch == '"' ||
  ch == '<' ||
  ch == '>' ||
  ch == '|' ||
  ch == '[' ||
  ch == ']' ||
  ch == '{' ||
  ch == '}' ||
  ch == '$' ||
  ch == '%' ||
  ch == '`'
}

///|
fn is_absolute_or_special(path : String) -> Bool {
  let chars = path_chars(path)
  chars.get(0) == Some('/') ||
  chars.get(0) == Some('~') ||
  chars.any(ch => ch == ':' || is_forbidden_path_char(ch))
}

///|
fn device_letter(ch : Char) -> Char {
  match ch {
    'a' | 'A' => 'A'
    'c' | 'C' => 'C'
    'l' | 'L' => 'L'
    'm' | 'M' => 'M'
    'n' | 'N' => 'N'
    'o' | 'O' => 'O'
    'p' | 'P' => 'P'
    'r' | 'R' => 'R'
    't' | 'T' => 'T'
    'u' | 'U' => 'U'
    'x' | 'X' => 'X'
    value => value
  }
}

///|
fn is_device_segment(segment : String) -> Bool {
  let base = StringBuilder()
  for ch in segment {
    if ch == '.' {
      break
    }
    base.write_char(device_letter(ch))
  }
  let name = base.to_string()
  if name == "CON" || name == "PRN" || name == "AUX" || name == "NUL" {
    return true
  }
  let chars = [ for ch in name => ch ]
  chars.length() == 4 &&
  chars[3] >= '1' &&
  chars[3] <= '9' &&
  (
    (chars[0] == 'C' && chars[1] == 'O' && chars[2] == 'M') ||
    (chars[0] == 'L' && chars[1] == 'P' && chars[2] == 'T')
  )
}

///|
fn push_segment(segments : Array[String], segment : String) -> Bool {
  let chars = [ for ch in segment => ch ]
  match segment {
    "" | "." => true
    ".." =>
      if segments.length() == 0 {
        false
      } else {
        ignore(segments.pop())
        true
      }
    value if is_device_segment(value) ||
      chars.get(chars.length() - 1) == Some('.') ||
      chars.get(chars.length() - 1) == Some(' ') => false
    value => {
      segments.push(value)
      true
    }
  }
}

///|
fn normalize_relative_path(base : String, path : String) -> String? {
  if path == "" || is_absolute_or_special(path) {
    return None
  }
  let combined = if base == "" { path } else { base + "/" + path }
  let segments : Array[String] = []
  let mut segment = StringBuilder()
  for ch in path_chars(combined) {
    if ch == '/' {
      if !push_segment(segments, segment.to_string()) {
        return None
      }
      segment = StringBuilder()
    } else {
      segment.write_char(ch)
    }
  }
  if !push_segment(segments, segment.to_string()) || segments.length() == 0 {
    None
  } else {
    Some(segments.join("/"))
  }
}

///|
fn parent_path(path : String) -> String {
  let chars = path_chars(path)
  let mut separator = -1
  for index, ch in chars {
    if ch == '/' {
      separator = index
    }
  }
  if separator < 0 {
    ""
  } else {
    let parent = StringBuilder()
    for index in 0..<separator {
      parent.write_char(chars[index])
    }
    parent.to_string()
  }
}

///|
fn path_is_within(root : String, path : String) -> Bool {
  if root == "" {
    return true
  }
  let root_chars = path_chars(root)
  let candidate = path_chars(path)
  if candidate.length() <= root_chars.length() {
    return false
  }
  for index in 0..<root_chars.length() {
    if candidate[index] != root_chars[index] {
      return false
    }
  }
  candidate[root_chars.length()] == '/'
}
